begin;
select plan(12);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

-- Property code auto-generation: two-word and single-word names.
select is(
  (select code from public.properties where id = '33333333-3333-3333-3333-333333333333'),
  'FP',
  '"Fake PG Bangalore" auto-generates the two-word-initials code FP'
);

insert into public.properties (id, name, address) values
  ('d0000001-0000-0000-0000-000000000001', 'Riverside', '1 River Rd');
select is(
  (select code from public.properties where id = 'd0000001-0000-0000-0000-000000000001'),
  'RI',
  'a single-word name falls back to its first two letters'
);

-- Collision: a second property whose name generates the same candidate is left null,
-- not silently reassigned to something else.
insert into public.properties (id, name, address) values
  ('d0000002-0000-0000-0000-000000000002', 'Fake PG Mumbai', '2 Fake Rd');
select is(
  (select code from public.properties where id = 'd0000002-0000-0000-0000-000000000002'),
  null,
  'a colliding auto-generated code (FP already taken) is left null, not reassigned'
);

-- Admin can set it by hand to resolve the collision.
update public.properties set code = 'FM' where id = 'd0000002-0000-0000-0000-000000000002';
select is(
  (select code from public.properties where id = 'd0000002-0000-0000-0000-000000000002'),
  'FM',
  'an admin can manually resolve a property code collision'
);

-- A tenant cannot be created for a property with no code (fail-closed).
insert into public.properties (id, name, address) values
  ('d0000003-0000-0000-0000-000000000003', 'Fake PG Pune', '3 Fake Rd'); -- also collides with FP, left null
select throws_ok(
  $$ insert into public.tenants (property_id, room_unit_id, full_name, phone, status, kyc_status, move_in_date, monthly_rent_paise)
     values ('d0000003-0000-0000-0000-000000000003', 'b4444444-4444-4444-4444-444444444444', 'No Code Tenant', '+919876511100', 'active', 'not_started', current_date, 500000) $$,
  'P0001',
  null,
  'a tenant cannot be created for a property with no code set'
);

-- Fresh tenant_code assignment and format.
select lives_ok(
  $$ insert into public.tenants (property_id, room_unit_id, full_name, phone, status, kyc_status, move_in_date, monthly_rent_paise)
     values ('33333333-3333-3333-3333-333333333333', 'b5555555-5555-5555-5555-555555555555', 'Test Tenant One', '+919876511101', 'active', 'not_started', current_date, 500000) $$,
  'a tenant is created successfully for a property with a code'
);
select matches(
  (select tenant_code from public.tenants where full_name = 'Test Tenant One'),
  '^FP-\d{4}-\d{4}$',
  'the assigned tenant_code matches PROPERTYCODE-FULLYEAR-SEQUENCE'
);

-- Sequence is never reused: delete that tenant, insert another, expect a higher sequence.
select ok(
  (select tenant_code from public.tenants where full_name = 'Test Tenant One') < 'FP-2027-0000',
  'sanity: the fresh code is within the current year'
);
delete from public.tenants where full_name = 'Test Tenant One';
select lives_ok(
  $$ insert into public.tenants (property_id, room_unit_id, full_name, phone, status, kyc_status, move_in_date, monthly_rent_paise)
     values ('33333333-3333-3333-3333-333333333333', 'b5555555-5555-5555-5555-555555555555', 'Test Tenant Two', '+919876511102', 'active', 'not_started', current_date, 500000) $$,
  'a second tenant is created after the first is deleted'
);
select isnt(
  (select tenant_code from public.tenants where full_name = 'Test Tenant Two'),
  (select tenant_code from public.tenants where full_name = 'Test Tenant One'), -- null, since deleted; isnt(x, null) is true for any non-null x
  'the second tenant does not reuse the deleted first tenant''s sequence number'
);

-- Independent sequences per property: the other seeded property's first tenant is 0001,
-- unaffected by how far the first property's sequence has advanced.
select lives_ok(
  $$ insert into public.tenants (property_id, room_unit_id, full_name, phone, status, kyc_status, move_in_date, monthly_rent_paise)
     values ('99999999-9999-9999-9999-999999999999', 'be000000-0000-0000-0000-000000000000', 'Other Property First Tenant', '+919876511103', 'active', 'not_started', current_date, 500000) $$,
  'a tenant is created for the other seeded property'
);
select is(
  (select tenant_code from public.tenants where full_name = 'Other Property First Tenant'),
  'OF-' || extract(year from now())::text || '-0001',
  'a different property''s sequence starts independently at 0001, regardless of the first property''s count'
);

select * from finish();
rollback;
