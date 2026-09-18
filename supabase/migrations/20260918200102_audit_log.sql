-- Append-only audit trail (CLAUDE.md §4 rule 16 and §5). Uses `at` as its single event
-- timestamp instead of created_at/updated_at — the table is insert-only (no one is ever
-- granted UPDATE on it), so a trigger-maintained updated_at wouldn't apply.
create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_type text not null check (actor_type in ('admin', 'tenant', 'service_role', 'system')),
  actor_id uuid,
  action text not null,
  table_name text not null,
  row_id uuid,
  before jsonb,
  after jsonb,
  at timestamptz not null default now()
);

alter table public.audit_log enable row level security;

-- No grants to anon/authenticated at all (CLAUDE.md §4 rule 9 addendum): only
-- service_role (Edge Functions) and this table's own security definer trigger function
-- ever touch it. RLS is enabled with zero policies as a second layer of defense.

-- Generic row-audit trigger, attached to every table that needs it. `security definer` so
-- it can insert into audit_log even though the invoking role (authenticated, as an admin)
-- has no grants on audit_log itself.
create or replace function public.audit_log_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_type text;
  v_actor_id uuid;
begin
  if public.is_admin() then
    v_actor_type := 'admin';
    v_actor_id := public._jwt_sub_as_uuid();
  elsif public.is_tenant() then
    v_actor_type := 'tenant';
    v_actor_id := public.current_tenant_id();
  else
    v_actor_type := 'service_role';
    v_actor_id := null;
  end if;

  insert into public.audit_log (actor_type, actor_id, action, table_name, row_id, before, after)
  values (
    v_actor_type,
    v_actor_id,
    TG_OP,
    TG_TABLE_NAME,
    coalesce((case when TG_OP = 'DELETE' then old.id else new.id end), null),
    case when TG_OP in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when TG_OP in ('INSERT', 'UPDATE') then to_jsonb(new) else null end
  );

  return coalesce(new, old);
end;
$$;
