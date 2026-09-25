-- DPDP-adjacent privacy rule (CLAUDE.md §4, KYC/privacy section — see the CLAUDE.md diff
-- in this same PR): a booking that never became a tenant carries a name and phone number
-- for no ongoing purpose once it's clearly abandoned. Swept automatically after a
-- configurable number of days.
--
-- Deliberately narrow: only bookings with created_tenant_id still null AND a status other
-- than paid/refunded are eligible. A paid or refunded booking is a financial record (it has
-- payments/dues tied to it, or a tenant that came from it) and must never be touched by
-- this job, by construction of the WHERE clause below, not by convention alone.
insert into public.app_config (key, value) values ('booking_pii_retention_days', '90'::jsonb);

create or replace function public.delete_abandoned_bookings()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_retention_days integer;
begin
  select coalesce((value #>> '{}')::integer, 90) into v_retention_days
  from public.app_config
  where key = 'booking_pii_retention_days';

  delete from public.bookings
  where created_tenant_id is null
    and status not in ('paid', 'refunded')
    and created_at < now() - make_interval(days => v_retention_days);
end;
$$;

create extension if not exists pg_cron with schema extensions;

select cron.schedule(
  'delete-abandoned-bookings',
  '17 3 * * *', -- daily at 03:17 — off the hour, avoids piling onto other scheduled jobs
  $$select public.delete_abandoned_bookings();$$
);
