-- Razorpay-sourced rows are written by the create-order/webhook Edge Functions via
-- service_role, which bypasses RLS entirely (CLAUDE.md §4 rules 24-26) — this table's
-- authenticated-role grants exist only so an admin can record a manual payment (rule 27).
-- No DELETE grant to anyone; corrections are status updates (e.g. to 'refunded'), not
-- deletes.
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  due_id uuid not null references public.dues (id),
  tenant_id uuid not null references public.tenants (id),
  amount_paise bigint not null check (amount_paise > 0),
  source public.payment_source not null,
  status public.payment_status not null default 'created',
  razorpay_order_id text unique,
  razorpay_payment_id text unique,
  method text,
  paid_at timestamptz,
  recorded_by uuid references public.admins (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.payments enable row level security;

grant select, insert, update on public.payments to authenticated;

create policy "admin full access" on public.payments
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "tenant reads own payments" on public.payments
  for select
  to authenticated
  using (public.is_tenant() and tenant_id = public.current_tenant_id() and public.tenant_can_access_main_app());

create trigger set_updated_at
  before update on public.payments
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.payments
  for each row
  execute function public.audit_log_row();
