-- A moved-out tenant could never be deleted before this migration, even once every due was
-- paid off — dues/payments/fines/electricity_bill_splits referenced them with no cascade,
-- deliberately, so a real debt couldn't be silently erased by deleting the tenant. That
-- protection is still exactly right for anyone with an UNPAID balance. But it had a real
-- edge case: the same protection also permanently locked their phone number (unique across
-- all tenants, active or not), so someone who moved out, settled up, and later wants to
-- move back in could never become a tenant again under the same number.
--
-- The fix: once a moved-out tenant has zero unpaid dues, deleting them is allowed, and it
-- cascades through their now-fully-settled financial history (dues, payments, fines, their
-- electricity-bill splits). The guard trigger below is what keeps this safe — it, not the
-- foreign keys, is what actually enforces "only once paid off": the FKs below only control
-- HOW a delete cascades once it's already permitted, not WHETHER one is.
create or replace function public.tenants_block_delete_with_unpaid_dues()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status <> 'moved_out' then
    raise exception 'tenants: only a moved-out tenant can be deleted';
  end if;

  if exists (select 1 from public.dues where tenant_id = old.id and status = 'unpaid') then
    raise exception 'tenants: cannot delete a tenant with unpaid dues — settle or cancel every due first';
  end if;

  return old;
end;
$$;

create trigger block_delete_with_unpaid_dues
  before delete on public.tenants
  for each row
  execute function public.tenants_block_delete_with_unpaid_dues();

-- dues/payments/fines/electricity_bill_splits: cascade once the guard above has already
-- allowed the delete. A `dues` row's own fines and electricity-bill split cascade from the
-- due being deleted, not directly from the tenant, so they go in the same breath.
alter table public.dues drop constraint dues_tenant_id_fkey;
alter table public.dues add constraint dues_tenant_id_fkey
  foreign key (tenant_id) references public.tenants (id) on delete cascade;

alter table public.payments drop constraint payments_tenant_id_fkey;
alter table public.payments add constraint payments_tenant_id_fkey
  foreign key (tenant_id) references public.tenants (id) on delete cascade;

alter table public.payments drop constraint payments_due_id_fkey;
alter table public.payments add constraint payments_due_id_fkey
  foreign key (due_id) references public.dues (id) on delete cascade;

alter table public.fines drop constraint fines_due_id_fkey;
alter table public.fines add constraint fines_due_id_fkey
  foreign key (due_id) references public.dues (id) on delete cascade;

alter table public.electricity_bill_splits drop constraint electricity_bill_splits_tenant_id_fkey;
alter table public.electricity_bill_splits add constraint electricity_bill_splits_tenant_id_fkey
  foreign key (tenant_id) references public.tenants (id) on delete cascade;

alter table public.electricity_bill_splits drop constraint electricity_bill_splits_due_id_fkey;
alter table public.electricity_bill_splits add constraint electricity_bill_splits_due_id_fkey
  foreign key (due_id) references public.dues (id) on delete cascade;

-- bookings is a record of the signup/payment process itself (with its own Razorpay
-- order/payment ids as proof), not a tenant's debt — it shouldn't be destroyed just because
-- the tenant it eventually created was later deleted. Unlink rather than cascade.
alter table public.bookings drop constraint bookings_created_tenant_id_fkey;
alter table public.bookings add constraint bookings_created_tenant_id_fkey
  foreign key (created_tenant_id) references public.tenants (id) on delete set null;

-- consents and kyc_submissions already cascade (set when each was first created) — nothing
-- to change there.
