-- Private KYC storage bucket. Path convention: {tenant_id}/{submission_id}/{aadhaar|selfie}.jpg
-- (CLAUDE.md §4 rule 20). Tenants may only write into their own folder, and only while
-- their submission is not_started (no row yet) or rejected. Admins never access this
-- bucket directly — only via signed URLs from an Edge Function using service_role, which
-- bypasses RLS and writes its own audit_log entry (rule 16), so there are no admin
-- policies here.
insert into storage.buckets (id, name, public)
values ('kyc', 'kyc', false);

create policy "tenant uploads into own folder" on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'kyc'
    and public.is_tenant()
    and public.tenant_is_active()
    and (storage.foldername(name))[1] = public.current_tenant_id()::text
    and not exists (
      select 1
      from public.kyc_submissions k
      where k.tenant_id = public.current_tenant_id()
        and k.status not in ('not_started', 'rejected')
    )
  );

create policy "tenant reads own folder" on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'kyc'
    and public.is_tenant()
    and public.tenant_is_active()
    and (storage.foldername(name))[1] = public.current_tenant_id()::text
  );
