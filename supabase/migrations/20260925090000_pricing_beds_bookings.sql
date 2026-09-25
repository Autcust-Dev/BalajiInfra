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
-- Deliberately no status column: a bed's "is it free right now" answer is entirely a
-- function of live `bookings` rows (an active hold, or a paid booking whose tenant hasn't
-- moved out), never a separately-stored flag that could drift from that truth — the same
-- "pure junction, single source of truth" reasoning already applied to
-- electricity_bill_splits. That live-availability query is Edge Function logic (PR2), not
-- schema.
--
-- Auto-provisioned: one bed per unit of capacity, the moment a room_unit is created.
-- Capacity is immutable in the current admin UI (a room_unit is only ever inserted, never
-- resized), so provisioning only needs to run on INSERT.
create table public.beds (
  id uuid primary key default gen_random_uuid(),
  room_unit_id uuid not null references public.room_units (id) on delete cascade,
  bed_label text not null,
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
