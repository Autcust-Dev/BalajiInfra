-- Auth helper functions used by every RLS policy from here on. All are `security definer`
-- so they can read `admins`/`tenants` regardless of the calling role's own grants on those
-- tables, `stable` since they don't modify data, and pin `search_path` to avoid search-path
-- hijacking (CLAUDE.md §4 rule 13).
--
-- Written in plpgsql rather than sql: a `language sql` function's body is validated against
-- the catalog at CREATE FUNCTION time, but `admins`/`tenants` don't exist until later
-- migrations. plpgsql defers that check to execution time, so these can be defined once,
-- up front, and used by every table's RLS policies from here on.

-- Safely reads the JWT `sub` claim as a uuid, or null if it isn't one (e.g. a Firebase
-- tenant session, whose `sub` is a Firebase UID — CLAUDE.md §4 rule 13). Deliberately does
-- NOT use auth.uid(): that function casts `sub` straight to uuid with no guard, which
-- raises an error rather than returning null for a non-uuid `sub`. Since is_admin() runs as
-- part of the combined RLS check on every table, including ones tenants query, calling
-- auth.uid() there would throw on every tenant request, not just local tests.
create or replace function public._jwt_sub_as_uuid()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
begin
  return (auth.jwt() ->> 'sub')::uuid;
exception
  when invalid_text_representation then
    return null;
end;
$$;

-- True for a Supabase Auth session (admin) belonging to an active admin row, with MFA
-- (aal2) satisfied. Admins are the only Supabase Auth users in this project (CLAUDE.md §4
-- rule 15) — Firebase-authenticated tenants never reach this function's true branch since
-- their JWT `role` claim is `authenticated` too, but they have no `admins` row.
create or replace function public.is_admin()
returns boolean
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  return exists (
    select 1
    from public.admins a
    where a.user_id = public._jwt_sub_as_uuid()
      and a.active
  )
  and coalesce((auth.jwt() ->> 'aal'), '') = 'aal2';
end;
$$;

-- True for an owner-role admin (see is_admin() for the base admin/MFA check).
create or replace function public.is_owner()
returns boolean
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  return public.is_admin()
    and exists (
      select 1
      from public.admins a
      where a.user_id = public._jwt_sub_as_uuid()
        and a.active
        and a.role = 'owner'
    );
end;
$$;

-- True for a Firebase-authenticated tenant session. Matches the JWT's `sub` (Firebase UID)
-- and `phone_number` claims against a `tenants` row, per CLAUDE.md §4 rule 13: Firebase UIDs
-- are not UUIDs, so tenants are never identified via auth.uid().
--
-- TODO(Phase 3): once Supabase third-party auth (Firebase provider) is wired up, tighten
-- this to also check the token issuer (`iss`/`aud`) matches our Firebase project, per rule
-- 13 and rule 14 — deferred until that config exists and the exact claim shape is verified
-- against current Supabase docs.
create or replace function public.is_tenant()
returns boolean
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  return coalesce((auth.jwt() ->> 'role'), '') = 'authenticated'
    and exists (
      select 1
      from public.tenants t
      where t.firebase_uid = (auth.jwt() ->> 'sub')
        and t.phone = (auth.jwt() ->> 'phone_number')
    );
end;
$$;

-- The current tenant's id, or null if the session isn't a matched tenant.
create or replace function public.current_tenant_id()
returns uuid
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_tenant_id uuid;
begin
  select t.id into v_tenant_id
  from public.tenants t
  where t.firebase_uid = (auth.jwt() ->> 'sub')
    and t.phone = (auth.jwt() ->> 'phone_number')
  limit 1;

  return v_tenant_id;
end;
$$;

-- The current tenant is not moved out. Gates the "pre-approval" tables (own tenant row,
-- consents, kyc_submissions) per the Phase 1 access rules.
create or replace function public.tenant_is_active()
returns boolean
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  return exists (
    select 1
    from public.tenants t
    where t.id = public.current_tenant_id()
      and t.status <> 'moved_out'
  );
end;
$$;

-- The current tenant is active AND KYC-approved. Gates dues/payments and the rest of the
-- main app.
create or replace function public.tenant_can_access_main_app()
returns boolean
language plpgsql
security definer
stable
set search_path = ''
as $$
begin
  return exists (
    select 1
    from public.tenants t
    where t.id = public.current_tenant_id()
      and t.status <> 'moved_out'
      and t.kyc_status = 'approved'
  );
end;
$$;

-- Generic updated_at trigger (CLAUDE.md §4 rule 8: every table's updated_at is
-- trigger-maintained).
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
