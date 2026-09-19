-- Tenant-facing read-only access to their own room/property (CLAUDE.md Phase 1 addition:
-- "tenants with approved KYC: read-only access to their own room and property only").
-- Split into its own migration, after tenants exists, because a CREATE POLICY's USING
-- clause is validated against the catalog immediately — unlike a plpgsql function body,
-- it can't forward-reference a table that doesn't exist yet.

create policy "approved tenant reads own property" on public.properties
  for select
  to authenticated
  using (
    public.is_tenant()
    and public.tenant_can_access_main_app()
    and id = (select t.property_id from public.tenants t where t.id = public.current_tenant_id())
  );

create policy "approved tenant reads own room" on public.rooms
  for select
  to authenticated
  using (
    public.is_tenant()
    and public.tenant_can_access_main_app()
    and id = (select t.room_id from public.tenants t where t.id = public.current_tenant_id())
  );
