-- Owner + staff manage dues (CLAUDE.md Phase 1 addition). Tenants read their own dues only
-- once active AND KYC-approved (CLAUDE.md Phase 1 addition: non-approved tenants get no
-- dues/payments access). No DELETE grant to anyone — use status = 'cancelled' instead of
-- removing a row.
create table public.dues (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  type public.due_type not null,
  description text,
  amount_paise bigint not null check (amount_paise > 0),
  due_date date not null,
  status public.due_status not null default 'unpaid',
  created_by uuid not null references public.admins (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.dues enable row level security;

grant select, insert, update on public.dues to authenticated;

create policy "admin full access" on public.dues
  for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "tenant reads own dues" on public.dues
  for select
  to authenticated
  using (public.is_tenant() and tenant_id = public.current_tenant_id() and public.tenant_can_access_main_app());

create trigger set_updated_at
  before update on public.dues
  for each row
  execute function public.set_updated_at();

create trigger audit_log_row
  after insert or update or delete on public.dues
  for each row
  execute function public.audit_log_row();
