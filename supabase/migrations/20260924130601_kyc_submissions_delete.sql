-- Admin can delete a kyc_submissions row (any status — submitted, approved, or rejected)
-- to force a resubmission, e.g. an approved KYC that turns out to need redoing. Always an
-- individual action (no bulk delete) per the client. The original migration
-- (20260918200118_kyc_submissions.sql) granted no DELETE to anyone at all — this adds it,
-- admin-only.
grant delete on public.kyc_submissions to authenticated;
grant delete on public.kyc_submissions to service_role;

create policy "admin deletes submission" on public.kyc_submissions
  for delete
  to authenticated
  using (public.is_admin());

-- The original sync trigger only fired on insert/update, so deleting a submission never
-- reset tenants.kyc_status back to 'not_started' — the tenant would stay stuck showing
-- whatever status the (now-deleted) row last had. Re-declare it to also handle delete: with
-- no `new` row on delete, use `old.tenant_id` and set the status explicitly rather than
-- mirroring a status value that no longer exists.
create or replace function public.sync_tenant_kyc_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if TG_OP = 'DELETE' then
    update public.tenants
    set kyc_status = 'not_started'
    where id = old.tenant_id;
    return old;
  end if;

  update public.tenants
  set kyc_status = new.status
  where id = new.tenant_id;

  return new;
end;
$$;

drop trigger sync_tenant_kyc_status on public.kyc_submissions;

create trigger sync_tenant_kyc_status
  after insert or update or delete on public.kyc_submissions
  for each row
  execute function public.sync_tenant_kyc_status();
