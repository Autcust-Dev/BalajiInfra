begin;
select plan(17);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

-- room_unit b4444444 has two active tenants (Fake Tenant Approved, move_in 2026-01-01;
-- Fake Tenant Login Test, move_in 2026-09-01) plus one moved-out tenant who must be
-- excluded entirely. An even total splits evenly.
select lives_ok(
  $$ insert into public.electricity_bills (id, room_unit_id, billing_period, total_amount_paise, created_by)
     values ('eb111111-1111-1111-1111-111111111111', 'b4444444-4444-4444-4444-444444444444', '2026-09-01', 100000, 'a1111111-1111-1111-1111-111111111111') $$,
  'admin creates an electricity bill'
);
select is(
  (select amount_paise from public.dues d join public.electricity_bill_splits s on s.due_id = d.id
     where s.bill_id = 'eb111111-1111-1111-1111-111111111111' and s.tenant_id = '66666666-6666-6666-6666-666666666666'),
  50000::bigint,
  'an even total splits equally: first active tenant gets half'
);
select is(
  (select amount_paise from public.dues d join public.electricity_bill_splits s on s.due_id = d.id
     where s.bill_id = 'eb111111-1111-1111-1111-111111111111' and s.tenant_id = 'f2222222-2222-2222-2222-222222222222'),
  50000::bigint,
  'an even total splits equally: second active tenant gets the other half'
);
select is_empty(
  $$ select * from public.electricity_bill_splits where bill_id = 'eb111111-1111-1111-1111-111111111111'
     and tenant_id = '88888888-8888-8888-8888-888888888888' $$,
  'the moved-out tenant in this room is excluded from the split entirely'
);

-- A room with only one currently-active tenant gets the whole bill, no division.
select lives_ok(
  $$ insert into public.electricity_bills (id, room_unit_id, billing_period, total_amount_paise, created_by)
     values ('eb222222-2222-2222-2222-222222222222', 'b5555555-5555-5555-5555-555555555555', '2026-09-01', 75000, 'a1111111-1111-1111-1111-111111111111') $$,
  'admin creates a bill for a room with one active tenant'
);
select is(
  (select amount_paise from public.dues d join public.electricity_bill_splits s on s.due_id = d.id
     where s.bill_id = 'eb222222-2222-2222-2222-222222222222'),
  75000::bigint,
  'a room with a single active tenant gets the whole bill, not a fraction'
);

-- Remainder handling: an amount that doesn't divide evenly hands the leftover paise to
-- the tenant with the earliest move_in_date.
update public.electricity_bills set total_amount_paise = 100001 where id = 'eb111111-1111-1111-1111-111111111111';
select is(
  (select amount_paise from public.dues d join public.electricity_bill_splits s on s.due_id = d.id
     where s.bill_id = 'eb111111-1111-1111-1111-111111111111' and s.tenant_id = '66666666-6666-6666-6666-666666666666'),
  50001::bigint,
  'the earliest-move-in tenant absorbs the extra paise on an uneven split'
);
select is(
  (select amount_paise from public.dues d join public.electricity_bill_splits s on s.due_id = d.id
     where s.bill_id = 'eb111111-1111-1111-1111-111111111111' and s.tenant_id = 'f2222222-2222-2222-2222-222222222222'),
  50000::bigint,
  'the later-move-in tenant is unaffected by the remainder'
);

-- Freeze on paid: marking a split's due as paid protects it from every later recalc.
update public.dues set status = 'paid'
where id = (select due_id from public.electricity_bill_splits
  where bill_id = 'eb111111-1111-1111-1111-111111111111' and tenant_id = '66666666-6666-6666-6666-666666666666');
update public.electricity_bills set total_amount_paise = 100003 where id = 'eb111111-1111-1111-1111-111111111111';
select is(
  (select amount_paise from public.dues d join public.electricity_bill_splits s on s.due_id = d.id
     where s.bill_id = 'eb111111-1111-1111-1111-111111111111' and s.tenant_id = '66666666-6666-6666-6666-666666666666'),
  50001::bigint,
  'a paid split is frozen — untouched by a later total change'
);
select is(
  (select amount_paise from public.dues d join public.electricity_bill_splits s on s.due_id = d.id
     where s.bill_id = 'eb111111-1111-1111-1111-111111111111' and s.tenant_id = 'f2222222-2222-2222-2222-222222222222'),
  50002::bigint, -- 100003 - 50001 frozen, all of the remaining pool to the one unpaid active tenant
  'the unpaid active tenant absorbs the entire remaining pool once the other is frozen'
);

-- Freeze on move-out: moving the remaining active tenant out freezes their split too (the
-- due stays against them). With A and D now both frozen (100003 total, fully accounted
-- for) and nobody left active in the room, nothing further is assigned until someone new
-- moves in.
update public.tenants set status = 'moved_out', move_out_date = current_date
where id = 'f2222222-2222-2222-2222-222222222222';
select is(
  (select amount_paise from public.dues d join public.electricity_bill_splits s on s.due_id = d.id
     where s.bill_id = 'eb111111-1111-1111-1111-111111111111' and s.tenant_id = 'f2222222-2222-2222-2222-222222222222'),
  50002::bigint,
  'a moved-out tenant''s split freezes at its last amount rather than being cleared'
);

-- Admin corrects the bill total upward while the room is fully vacant (of anyone
-- unfrozen) — nothing changes yet since there's nobody to assign the new pool to.
update public.electricity_bills set total_amount_paise = 100150 where id = 'eb111111-1111-1111-1111-111111111111';

-- Re-split on a new tenant joining: with the room now vacant, a newly-moved-in active
-- tenant picks up whatever pool remains unfrozen (100150 - 100003 frozen = 147).
insert into public.tenants (id, property_id, room_unit_id, full_name, phone, status, kyc_status, move_in_date, monthly_rent_paise)
values ('ee111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'b4444444-4444-4444-4444-444444444444',
  'New Roommate', '+919876522222', 'active', 'not_started', current_date, 1000000);
select is(
  (select amount_paise from public.dues d join public.electricity_bill_splits s on s.due_id = d.id
     where s.bill_id = 'eb111111-1111-1111-1111-111111111111' and s.tenant_id = 'ee111111-1111-1111-1111-111111111111'),
  147::bigint,
  'a newly-joined tenant automatically picks up the room''s remaining unfrozen pool'
);

-- RLS: an approved tenant reads only their own room's bills/splits.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
-- Tenant A (Fake Tenant Approved) was moved out in setup above? No — only tenant D and
-- Fake Tenant Moved Out are moved_out; tenant A is still active with an approved KYC.
select isnt_empty(
  $$ select * from public.electricity_bills where id = 'eb111111-1111-1111-1111-111111111111' $$,
  'a tenant can read their own room''s electricity bill'
);
select isnt_empty(
  $$ select * from public.electricity_bill_splits
     where bill_id = 'eb111111-1111-1111-1111-111111111111' and tenant_id = '66666666-6666-6666-6666-666666666666' $$,
  'a tenant can read their own electricity bill split'
);
select is_empty(
  $$ select * from public.electricity_bills where id = 'eb222222-2222-2222-2222-222222222222' $$,
  'a tenant cannot read a different room''s electricity bill'
);

set local role anon;
select throws_ok(
  $$ select * from public.electricity_bills $$, '42501', null, 'anon cannot read electricity_bills'
);
select throws_ok(
  $$ select * from public.electricity_bill_splits $$, '42501', null, 'anon cannot read electricity_bill_splits'
);

select * from finish();
rollback;
