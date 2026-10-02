-- Lets an admin resolve an unpaid due (CLAUDE.md rule 27: manual payments, source='manual',
-- recorded_by set, audited) and, downstream, actually delete a moved-out tenant once their
-- money is settled — right now there is no screen anywhere that marks a due paid, so an
-- unpaid moved-out tenant can never be removed (dues.tenant_id has no ON DELETE CASCADE,
-- deliberately, so a real debt can't be silently erased by deleting the tenant).
--
-- A payments row reaching status = 'paid' marks its due paid via trigger, the same
-- sync-by-trigger pattern already used for kyc_status — not app-layer logic, so this also
-- correctly covers the future Razorpay webhook path (CLAUDE.md rule 24): it only ever needs
-- to write the payments row, never dues directly, and this trigger does the rest.
create or replace function public.sync_due_status_from_payment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'paid' then
    update public.dues set status = 'paid' where id = new.due_id and status <> 'paid';
  end if;
  return new;
end;
$$;

create trigger sync_due_status
  after insert or update of status on public.payments
  for each row
  execute function public.sync_due_status_from_payment();
