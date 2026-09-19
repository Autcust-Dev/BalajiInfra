-- Shared status enums, used identically across admin/ and app/ (CLAUDE.md §4 rule 4).

create type public.admin_role as enum ('owner', 'staff');

create type public.tenant_status as enum ('active', 'moved_out');

create type public.kyc_status as enum ('not_started', 'submitted', 'approved', 'rejected');

create type public.due_type as enum ('rent', 'deposit', 'electricity', 'other');

create type public.due_status as enum ('unpaid', 'paid', 'cancelled');

create type public.payment_source as enum ('razorpay', 'manual');

create type public.payment_status as enum ('created', 'paid', 'failed', 'refunded');
