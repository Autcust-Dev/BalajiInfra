begin;
select plan(9);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

-- Admin can create a fine against an existing due.
select lives_ok(
  $$ insert into public.fines (id, due_id, amount_paise, starts_on, ends_on, created_by)
     values ('f1111111-1111-1111-1111-111111111111', 'd6666666-6666-6666-6666-666666666666', 5000, current_date, current_date + 5, 'a1111111-1111-1111-1111-111111111111') $$,
  'admin can create a fine on an existing due'
);

-- The due's true total owed is amount_paise + sum(fines) — a plain aggregate, not a
-- stored/computed column (CLAUDE.md-adjacent comment in the fines migration).
select lives_ok(
  $$ insert into public.fines (due_id, amount_paise, starts_on, ends_on, created_by)
     values ('d6666666-6666-6666-6666-666666666666', 2000, current_date, current_date + 2, 'a1111111-1111-1111-1111-111111111111') $$,
  'admin can create a second fine against the same due'
);
select is(
  (select (d.amount_paise + coalesce(sum(f.amount_paise), 0))::bigint
   from public.dues d left join public.fines f on f.due_id = d.id
   where d.id = 'd6666666-6666-6666-6666-666666666666'
   group by d.amount_paise),
  (select amount_paise from public.dues where id = 'd6666666-6666-6666-6666-666666666666') + 7000::bigint,
  'a due''s true total owed is its own amount plus the sum of its fines'
);

-- amount_paise must be positive (no zero/negative "fine").
select throws_ok(
  $$ insert into public.fines (due_id, amount_paise, starts_on, ends_on, created_by)
     values ('d6666666-6666-6666-6666-666666666666', 0, current_date, current_date, 'a1111111-1111-1111-1111-111111111111') $$,
  '23514',
  null,
  'a fine amount must be greater than zero'
);

-- ends_on must not precede starts_on.
select throws_ok(
  $$ insert into public.fines (due_id, amount_paise, starts_on, ends_on, created_by)
     values ('d6666666-6666-6666-6666-666666666666', 1000, current_date, current_date - 1, 'a1111111-1111-1111-1111-111111111111') $$,
  '23514',
  null,
  'ends_on cannot be before starts_on'
);

-- Admin can edit a fine (e.g. correct the amount), but there is no delete/waive path —
-- deliberately, per the fines migration's own comment: no "remove a fine" requirement,
-- only "add one."
select lives_ok(
  $$ update public.fines set amount_paise = 4000 where id = 'f1111111-1111-1111-1111-111111111111' $$,
  'admin can edit a fine (e.g. correct the amount)'
);
select throws_ok(
  $$ delete from public.fines where id = 'f1111111-1111-1111-1111-111111111111' $$,
  '42501',
  null,
  'nobody — not even an admin — can delete a fine (no DELETE grant at all)'
);

-- Tenant read-only: the tenant whose due this fine is against can read it; a different
-- tenant cannot.
select set_config('request.jwt.claims', json_build_object(
  'sub', 'firebase-tenant-approved', 'role', 'authenticated', 'phone_number', '+919876500001',
  'aud', 'balajiinfra-local-dev', 'iss', 'https://securetoken.google.com/balajiinfra-local-dev'
)::text, true);
select isnt_empty(
  $$ select * from public.fines where due_id = 'd6666666-6666-6666-6666-666666666666' $$,
  'the tenant whose due a fine is against can read it'
);
select throws_ok(
  $$ insert into public.fines (due_id, amount_paise, starts_on, ends_on, created_by)
     values ('d6666666-6666-6666-6666-666666666666', 1000, current_date, current_date, 'a1111111-1111-1111-1111-111111111111') $$,
  '42501',
  null,
  'a tenant cannot create a fine, even against their own due'
);

select * from finish();
rollback;
