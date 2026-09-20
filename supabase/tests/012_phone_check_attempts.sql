begin;
select plan(3);

-- phone_check_attempts gets no grants to anon/authenticated at all (CLAUDE.md §4 rule 9
-- addendum) — only service_role (the check-phone Edge Function) touches it. Same pattern
-- as audit_log/webhook_events (006_internal_tables.sql).
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

select throws_ok(
  $$ select * from public.phone_check_attempts $$,
  '42501',
  null,
  'owner admin cannot read phone_check_attempts (no grant at all)'
);
select throws_ok(
  $$ insert into public.phone_check_attempts (phone, ip) values ('+919876500001', '127.0.0.1') $$,
  '42501',
  null,
  'owner admin cannot write phone_check_attempts'
);

set local role anon;
select throws_ok(
  $$ select * from public.phone_check_attempts $$,
  '42501',
  null,
  'anon cannot read phone_check_attempts'
);

select * from finish();
rollback;
