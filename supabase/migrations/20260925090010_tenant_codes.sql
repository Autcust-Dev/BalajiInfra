-- Human-readable tenant IDs, alongside (never replacing) the uuid primary key:
-- <PROPERTY_CODE>-<YEAR>-<SEQUENCE>, e.g. SE-2026-0001. The full 4-digit year is stored —
-- not a 2-digit shorthand — so nothing breaks or collides after 2099; a terser display
-- form, if ever wanted on an invoice template, is a rendering choice for that screen, not
-- a second stored representation that could drift from the canonical one used everywhere
-- else (admin search, the app, receipts).
--
-- Deliberately excludes floor/room/sharing type: a tenant's room can change, and an ID
-- that encodes it goes stale or forces reissuing. The current room is shown next to the ID
-- in the UI instead (PR4), not baked into the ID itself.

-- ---------------------------------------------------------------------------------------
-- Property code: 2 uppercase letters, auto-generated from the name on insert, unique,
-- admin-editable afterward if the generated one collides or is undesirable. Frozen onto
-- each tenant_code at the moment that tenant is created (below) — changing a property's
-- code later only affects tenants created after the change, never rewrites history.
alter table public.properties add column code text unique check (code ~ '^[A-Z]{2}$');

create or replace function public.generate_property_code()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_words text[];
  v_candidate text;
begin
  if new.code is not null then
    return new;
  end if;

  v_words := regexp_split_to_array(upper(trim(new.name)), '\s+');
  if array_length(v_words, 1) >= 2 then
    v_candidate := left(v_words[1], 1) || left(v_words[2], 1);
  else
    v_candidate := left(v_words[1], 2);
  end if;

  -- Only claim it if it's a clean two-letter code and nobody else has it yet. Otherwise
  -- leave code null — an admin must set it by hand (CLAUDE.md rule addition below), and
  -- assign_tenant_code() fails closed rather than creating a tenant with no code.
  if v_candidate ~ '^[A-Z]{2}$' and not exists (select 1 from public.properties where code = v_candidate) then
    new.code := v_candidate;
  end if;

  return new;
end;
$$;

create trigger generate_code
  before insert on public.properties
  for each row
  execute function public.generate_property_code();

-- Backfill for properties that already existed before this migration (the trigger above
-- only fires on INSERT). Same single-attempt logic as the trigger; a property whose name
-- can't produce a unique code is left null and needs an admin to set one by hand.
do $$
declare
  v_property record;
  v_words text[];
  v_candidate text;
begin
  for v_property in
    select id, name from public.properties where code is null order by created_at asc, id asc
  loop
    v_words := regexp_split_to_array(upper(trim(v_property.name)), '\s+');
    if array_length(v_words, 1) >= 2 then
      v_candidate := left(v_words[1], 1) || left(v_words[2], 1);
    else
      v_candidate := left(v_words[1], 2);
    end if;

    if v_candidate ~ '^[A-Z]{2}$' and not exists (select 1 from public.properties where code = v_candidate) then
      update public.properties set code = v_candidate where id = v_property.id;
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------------------
-- Per-(property, year) sequence counter. A dedicated table rather than a computed
-- MAX(sequence)+1, so concurrent tenant creations (an admin insert racing a self-signup
-- webhook) serialize correctly on the row lock from the UPSERT below instead of two
-- transactions computing the same "next" number — the actual "assigned by the database,
-- no race" guarantee, not application-level retry logic. No anon/authenticated grants:
-- internal, touched only by assign_tenant_code() (security definer), same treatment as
-- audit_log.
create table public.tenant_code_sequences (
  property_id uuid not null references public.properties (id),
  year integer not null,
  next_sequence integer not null default 1,
  primary key (property_id, year)
);

alter table public.tenant_code_sequences enable row level security;

grant select, insert, update on public.tenant_code_sequences to service_role;

alter table public.tenants add column tenant_code text unique;

create or replace function public.assign_tenant_code()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_property_code text;
  v_year integer := extract(year from now())::integer;
  v_sequence integer;
begin
  if new.tenant_code is not null then
    return new;
  end if;

  select code into v_property_code from public.properties where id = new.property_id;
  if v_property_code is null then
    raise exception
      'tenants: property % has no code set — an admin must set properties.code before a tenant can be created for it',
      new.property_id;
  end if;

  insert into public.tenant_code_sequences (property_id, year, next_sequence)
  values (new.property_id, v_year, 2)
  on conflict (property_id, year)
  do update set next_sequence = public.tenant_code_sequences.next_sequence + 1
  returning next_sequence - 1 into v_sequence;

  new.tenant_code := v_property_code || '-' || v_year || '-' || lpad(v_sequence::text, 4, '0');
  return new;
end;
$$;

create trigger assign_code
  before insert on public.tenants
  for each row
  execute function public.assign_tenant_code();

-- Backfill for tenants that already existed before this migration, oldest first so
-- sequences read as a plausible history. Year is taken from each tenant's own created_at
-- (when its row actually entered the database), matching the trigger's own "year = row
-- creation time" semantics above. A tenant whose property still has no code (see the
-- property backfill above) is left with tenant_code null — same graceful-degradation
-- treatment as tenants.bed_id in the previous migration, and for the same reason: there's
-- nothing to backfill against until an admin sets that property's code. tenant_code stays
-- nullable at the schema level for this reason; the trigger is what guarantees every NEW
-- tenant always gets one.
do $$
declare
  v_tenant record;
  v_property_code text;
  v_sequence integer;
begin
  for v_tenant in
    select t.id, t.property_id, extract(year from t.created_at)::integer as yr
    from public.tenants t
    where t.tenant_code is null
    order by t.created_at asc, t.id asc
  loop
    select code into v_property_code from public.properties where id = v_tenant.property_id;
    continue when v_property_code is null;

    insert into public.tenant_code_sequences (property_id, year, next_sequence)
    values (v_tenant.property_id, v_tenant.yr, 2)
    on conflict (property_id, year)
    do update set next_sequence = public.tenant_code_sequences.next_sequence + 1
    returning next_sequence - 1 into v_sequence;

    update public.tenants
    set tenant_code = v_property_code || '-' || v_tenant.yr || '-' || lpad(v_sequence::text, 4, '0')
    where id = v_tenant.id;
  end loop;
end;
$$;
