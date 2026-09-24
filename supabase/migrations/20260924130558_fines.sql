-- Deliberately simple, per the client: a flat admin-entered amount attached to a due, not a
-- calculated rate (no percentage/per-day engine). "Rent (fixed) + fine (flexible) = total"
-- — the due's own amount_paise stays untouched; a due's true total owed is
-- `dues.amount_paise + sum(its fines.amount_paise)`. Flagging for Phase 5: the future
-- Razorpay create-order Edge Function must sum fines in too, not just read dues.amount_paise
-- (rule 23).
create table public.fines (
  id uuid primary key default gen_random_uuid(),
  due_id uuid not null references public.dues (id),
  amount_paise bigint not null check (amount_paise > 0),
  starts_on date not null,
  ends_on date not null check (ends_on >= starts_on),
  created_by uuid not null references public.admins (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.fines enable row level security;

grant select, insert, update on public.fines to authenticated;
grant select, insert, update on public.fines to service_role;
-- No DELETE grant — same reasoning as dues/electricity_bills: a fine is a financial record
-- once created. (There's no "checkbox to remove a fine" requirement, only a checkbox to
-- add one in the first place.)

create policy "admin full access" on public.fines
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "tenant reads own fines" on public.fines
  for select
  to authenticated
  using (
    public.is_tenant()
    and public.tenant_can_access_main_app()
    and exists (
      select 1 from public.dues d
      where d.id = fines.due_id and d.tenant_id = public.current_tenant_id()
    )
  );

create trigger set_updated_at
  before update on public.fines
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.fines
  for each row
  execute function public.audit_log_row();
