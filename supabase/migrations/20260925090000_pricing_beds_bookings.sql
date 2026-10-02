-- Tenant self-onboarding, phase 1 (schema only — no Edge Functions or app/admin code yet).
-- Adds a second tenant-creation path alongside admin-created tenants: a signed-up-but-
-- unpaid visitor never gets a `tenants` row at all (CLAUDE.md rule 1 amendment — see the
-- CLAUDE.md diff in this same PR). Nothing here is reachable by `anon` or a plain
-- `authenticated` client session except through `is_admin()`; the self-signup flow itself
-- (list-availability, start-booking, verify-booking-otp, create-booking-order, the
-- Razorpay webhook) is entirely `service_role`-mediated, built in a later PR. This PR is
-- inert until that PR wires it up.

-- ---------------------------------------------------------------------------------------
-- Pricing: per property, per sharing type. Admin-editable (owner + staff, same tier as
-- everything else). A booking snapshots these amounts onto itself at hold time (below) so
-- a later price edit never changes an in-flight or already-completed booking — the same
-- "freeze once it matters" pattern already used for electricity bill splits and fines.
create table public.pricing_plans (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id) on delete cascade,
  capacity integer not null check (capacity > 0), -- sharing type, same meaning as room_units.capacity
  security_deposit_paise bigint not null check (security_deposit_paise >= 0),
  rent_monthly_paise bigint not null check (rent_monthly_paise > 0),
  rent_yearly_paise bigint not null check (rent_yearly_paise > 0),
  onboarding_charges_paise bigint not null check (onboarding_charges_paise >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, capacity)
);

alter table public.pricing_plans enable row level security;

grant select, insert, update, delete on public.pricing_plans to authenticated;
grant select, insert, update, delete on public.pricing_plans to service_role;

create policy "admin full access" on public.pricing_plans
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create trigger set_updated_at
  before update on public.pricing_plans
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.pricing_plans
  for each row
  execute function public.audit_log_row();

-- ---------------------------------------------------------------------------------------
-- Beds: real rows so a hold can be pinned to a specific one (see the unique index on
-- bookings below — that's the actual double-booking guard, not this table by itself).
--
-- No "held"/"occupied"/"available" status stored: those three are entirely a function of
-- live `bookings`/`tenants` rows (an active hold, or an active tenant whose bed_id points
-- here — see tenants.bed_id further down), never a separately-stored flag that could drift
-- from that truth — the same "pure junction, single source of truth" reasoning already
-- applied to electricity_bill_splits. `bed_is_available()` below is the one canonical,
-- tested place that computation lives; PR2's Edge Functions call it rather than
-- re-implementing it.
--
-- `under_maintenance` IS stored, because it's the one state that genuinely isn't
-- derivable from anything else — an admin taking a bed out of service is an independent
-- fact, not a consequence of a booking or tenant existing.
--
-- Auto-provisioned: one bed per unit of capacity. A trigger handles this for every
-- room_unit created from now on; the backfill immediately below handles every room_unit
-- that already existed before this migration (the trigger, being AFTER INSERT, never
-- fires for rows that were already there). Capacity is immutable in the current admin UI
-- (a room_unit is only ever inserted, never resized), so provisioning only needs to run
-- on INSERT going forward.
create table public.beds (
  id uuid primary key default gen_random_uuid(),
  room_unit_id uuid not null references public.room_units (id) on delete cascade,
  bed_label text not null,
  under_maintenance boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (room_unit_id, bed_label)
);

alter table public.beds enable row level security;

grant select, insert, update, delete on public.beds to authenticated;
grant select, insert, update, delete on public.beds to service_role;

create policy "admin full access" on public.beds
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create trigger set_updated_at
  before update on public.beds
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.beds
  for each row
  execute function public.audit_log_row();

create or replace function public.provision_beds_for_room_unit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_i integer;
begin
  for v_i in 1..new.capacity loop
    insert into public.beds (room_unit_id, bed_label)
    values (new.id, 'Bed ' || v_i);
  end loop;
  return new;
end;
$$;

create trigger provision_beds
  after insert on public.room_units
  for each row
  execute function public.provision_beds_for_room_unit();

-- Backfill for room_units that already existed before this migration.
insert into public.beds (room_unit_id, bed_label)
select ru.id, 'Bed ' || gs.n
from public.room_units ru
cross join lateral generate_series(1, ru.capacity) as gs (n)
where not exists (select 1 from public.beds b where b.room_unit_id = ru.id);

-- ---------------------------------------------------------------------------------------
-- Bookings: the entire pre-tenant lifecycle. hold -> otp_verified -> payment_pending ->
-- paid, or hold/otp_verified/payment_pending -> expired/cancelled/payment_failed, or
-- paid -> refunded. `source = 'manual'` is an admin completing a booking with a cash/UPI
-- payment (recorded_by set) through the exact same tenant-creation path the Razorpay
-- webhook uses (PR2) — not a separate code path, so "identical to an admin-added tenant"
-- stays true regardless of which door the money came through.
create type public.booking_status as enum (
  'hold',
  'otp_verified',
  'payment_pending',
  'paid',
  'payment_failed',
  'expired',
  'cancelled',
  'refunded'
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id),
  room_unit_id uuid not null references public.room_units (id),
  bed_id uuid not null references public.beds (id),
  full_name text,
  phone text not null check (phone ~ '^\+91[0-9]{10}$'),
  status public.booking_status not null default 'hold',
  billing_cycle public.billing_cycle not null,
  -- Snapshotted from pricing_plans at hold time — see the comment on that table.
  security_deposit_paise bigint not null check (security_deposit_paise >= 0),
  rent_paise bigint not null check (rent_paise > 0),
  onboarding_charges_paise bigint not null check (onboarding_charges_paise >= 0),
  total_amount_paise bigint not null check (total_amount_paise > 0),
  held_expires_at timestamptz not null,
  otp_verified_at timestamptz,
  razorpay_order_id text unique,
  razorpay_payment_id text unique,
  source text not null default 'self_signup' check (source in ('self_signup', 'manual')),
  created_tenant_id uuid references public.tenants (id),
  recorded_by uuid references public.admins (id), -- set only when source = 'manual'
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- The actual double-booking guard (CLAUDE.md-adjacent plan point 2): at most one
-- non-terminal booking per bed at a time. Postgres enforces this atomically at INSERT —
-- two concurrent attempts to hold the same bed race on this index, not on application
-- logic, so exactly one succeeds regardless of timing.
create unique index bookings_bed_id_active_key on public.bookings (bed_id)
  where status in ('hold', 'otp_verified', 'payment_pending');

-- At most one non-terminal booking per phone number, so a single phone can't hold
-- multiple beds at once (client answer: an existing tenant's phone can't sign up again at
-- all — that check is against the `tenants` table and belongs in the Edge Function, since
-- it needs to return a friendly "please log in" response rather than a constraint error).
create unique index bookings_phone_active_key on public.bookings (phone)
  where status in ('hold', 'otp_verified', 'payment_pending');

-- A bed under maintenance can never be held, even by an admin completing a manual booking.
create or replace function public.bookings_bed_not_under_maintenance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('hold', 'otp_verified', 'payment_pending')
    and exists (select 1 from public.beds where id = new.bed_id and under_maintenance)
  then
    raise exception 'bookings: cannot hold a bed that is under maintenance';
  end if;
  return new;
end;
$$;

create trigger bed_not_under_maintenance
  before insert or update of bed_id, status on public.bookings
  for each row
  execute function public.bookings_bed_not_under_maintenance();

alter table public.bookings enable row level security;

-- Internal table (CLAUDE.md §4 rule 9 addendum): no anon grants — the public signup flow
-- never reads or writes this table directly, only through service_role Edge Functions.
-- Admins DO get direct grants: the Bookings/Leads admin page (PR4) reads this table
-- straight via is_admin(), same as every other admin list page in this codebase; only the
-- side-effecting actions (completing a booking, refunding) go through an Edge Function.
grant select, insert, update on public.bookings to authenticated;
grant select, insert, update, delete on public.bookings to service_role;

create policy "admin full access" on public.bookings
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create trigger set_updated_at
  before update on public.bookings
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.bookings
  for each row
  execute function public.audit_log_row();

-- ---------------------------------------------------------------------------------------
-- WhatsApp invoice delivery log (fire-and-forget from the payment webhook in PR2; the
-- in-app invoice screen is the source of truth regardless of this succeeding). Lets admin
-- see delivery status and manually resend once Meta approval is in place.
create table public.whatsapp_invoice_log (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'sent', 'failed')),
  provider_message_id text,
  error_message text,
  attempted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.whatsapp_invoice_log enable row level security;

grant select on public.whatsapp_invoice_log to authenticated;
grant select, insert, update on public.whatsapp_invoice_log to service_role;

create policy "admin full access" on public.whatsapp_invoice_log
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create trigger set_updated_at
  before update on public.whatsapp_invoice_log
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.whatsapp_invoice_log
  for each row
  execute function public.audit_log_row();

-- ---------------------------------------------------------------------------------------
-- Per-property opt-in (client answer: pilot on one property first, not live everywhere).
alter table public.properties add column self_signup_enabled boolean not null default false;

-- ---------------------------------------------------------------------------------------
-- Bed-level tenant linkage, for the app's seat map (select room -> see which beds are
-- selectable). Nullable: some already-existing tenants can't be cleanly backfilled (see
-- below), and firebase_uid is already nullable for an analogous "not always known yet"
-- reason. Going forward, both the tenant form (PR4) and the booking webhook (PR2) are
-- expected to always set it — enforced at that layer, not here, same as how "an admin
-- must fill in KYC eventually" isn't a NOT NULL constraint either.
alter table public.tenants add column bed_id uuid references public.beds (id);

-- At most one active tenant per bed — the actual seat-map correctness guard, enforced the
-- same way as the bookings.bed_id guard above: a unique index, not application logic.
create unique index tenants_bed_id_active_key on public.tenants (bed_id)
  where status = 'active';

-- Keeps bed_id and room_unit_id from ever disagreeing (same pattern as
-- rooms_block_matches_property() in floors_and_blocks.sql), and blocks assigning a bed
-- that's under maintenance to an active tenant.
create or replace function public.tenants_bed_matches_room_unit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bed_room_unit_id uuid;
  v_under_maintenance boolean;
begin
  if new.bed_id is null then
    return new;
  end if;

  select room_unit_id, under_maintenance into v_bed_room_unit_id, v_under_maintenance
  from public.beds
  where id = new.bed_id;

  if v_bed_room_unit_id is distinct from new.room_unit_id then
    raise exception 'tenants: bed_id does not belong to the tenant''s room_unit_id';
  end if;

  if new.status = 'active' and v_under_maintenance then
    raise exception 'tenants: cannot assign a bed that is under maintenance';
  end if;

  return new;
end;
$$;

create trigger bed_matches_room_unit
  before insert or update of bed_id, room_unit_id, status on public.tenants
  for each row
  execute function public.tenants_bed_matches_room_unit();

-- Re-declare the tenant self-update guard (see the comment on this pattern in
-- add_tenant_move_out_date.sql) to also protect bed_id from a tenant-initiated update.
create or replace function public.tenants_tenant_update_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user <> 'authenticated' or public.is_admin() then
    return new;
  end if;

  if old.property_id is distinct from new.property_id
    or old.room_unit_id is distinct from new.room_unit_id
    or old.bed_id is distinct from new.bed_id
    or old.full_name is distinct from new.full_name
    or old.phone is distinct from new.phone
    or old.firebase_uid is distinct from new.firebase_uid
    or old.status is distinct from new.status
    or old.kyc_status is distinct from new.kyc_status
    or old.move_in_date is distinct from new.move_in_date
    or old.move_out_date is distinct from new.move_out_date
    or old.monthly_rent_paise is distinct from new.monthly_rent_paise
    or old.billing_cycle is distinct from new.billing_cycle
  then
    raise exception 'tenants: only fcm_token may be updated by a tenant';
  end if;

  return new;
end;
$$;

-- Backfill: assign existing active tenants to a distinct bed within their own room_unit,
-- earliest move_in_date first, in bed-label order. Any room_unit that already had more
-- active tenants than beds (only possible if an admin overrode the "room is full" warning
-- in the tenant form) leaves the excess tenants with bed_id still null — there aren't
-- enough physical beds to assign them one without guessing which is wrong. Those need a
-- manual admin fix: the tenant form (PR4) will surface "no bed assigned" for anyone in
-- this state so it's visible, not silently wrong.
with ranked_tenants as (
  select id, room_unit_id,
    row_number() over (partition by room_unit_id order by move_in_date asc, id asc) as rn
  from public.tenants
  where status = 'active'
),
ranked_beds as (
  select id as bed_id, room_unit_id,
    row_number() over (partition by room_unit_id order by bed_label asc) as rn
  from public.beds
)
update public.tenants t
set bed_id = rb.bed_id
from ranked_tenants rt
join ranked_beds rb on rb.room_unit_id = rt.room_unit_id and rb.rn = rt.rn
where t.id = rt.id;

-- ---------------------------------------------------------------------------------------
-- The one canonical availability computation — a bed is selectable in the app's seat map
-- iff none of: under maintenance, occupied by an active tenant, held by a live
-- (unexpired) booking, or its whole room_unit already at capacity once tenants with no
-- bed_id are counted (see below). PR2's list-availability Edge Function calls this rather
-- than re-implementing the same logic; its response only ever carries a bed label and
-- this boolean — never an occupant's name or any other tenant detail (there is none to
-- leak: this function returns a single boolean, nothing else).
--
-- The room_unit-level headcount check exists specifically because tenants.bed_id can be
-- null (see the comment on that column): a tenant with no bed_id is real and occupies a
-- real bed in their room_unit, but bed-level checks alone can't tell WHICH one — so
-- without this, every bed in that room_unit would look free even though one of them
-- genuinely isn't, and self-signup could sell a bed that's actually occupied. Counting
-- heads against capacity closes that gap: once a room_unit's active-tenant-plus-live-hold
-- count reaches its capacity, none of its beds are offered, even ones with no specific
-- occupant recorded against them. This is intentionally conservative (it may block a
-- technically-free bed in a room that also has an unassigned tenant) rather than risk
-- double-booking one that's actually taken.
create or replace function public.bed_is_available(p_bed_id uuid)
returns boolean
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_room_unit_id uuid;
  v_capacity integer;
  v_under_maintenance boolean;
  v_occupied_count integer;
begin
  select b.room_unit_id, b.under_maintenance, ru.capacity
  into v_room_unit_id, v_under_maintenance, v_capacity
  from public.beds b
  join public.room_units ru on ru.id = b.room_unit_id
  where b.id = p_bed_id;

  if v_room_unit_id is null or v_under_maintenance then
    return false;
  end if;

  if exists (select 1 from public.tenants where bed_id = p_bed_id and status = 'active') then
    return false;
  end if;

  if exists (
    select 1 from public.bookings
    where bed_id = p_bed_id
      and status in ('hold', 'otp_verified', 'payment_pending')
      and held_expires_at > now()
  ) then
    return false;
  end if;

  select
    (select count(*) from public.tenants where room_unit_id = v_room_unit_id and status = 'active')
    + (select count(*) from public.bookings bk
         join public.beds bd on bd.id = bk.bed_id
         where bd.room_unit_id = v_room_unit_id
           and bk.status in ('hold', 'otp_verified', 'payment_pending')
           and bk.held_expires_at > now())
  into v_occupied_count;

  return v_occupied_count < v_capacity;
end;
$$;
