begin;
select plan(6);

-- audit_log and webhook_events get no grants to anon/authenticated at all (CLAUDE.md §4
-- rule 9 addendum) — not even an owner admin can read them via the Data API, only
-- service_role (Edge Functions) and the security-definer trigger that populates audit_log.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);

select throws_ok(
  $$ select * from public.audit_log $$,
  '42501',
  null,
  'owner admin cannot read audit_log (no grant at all)'
);
select throws_ok(
  $$ select * from public.webhook_events $$,
  '42501',
  null,
  'owner admin cannot read webhook_events (no grant at all)'
);
select throws_ok(
  $$ insert into public.webhook_events (provider, event_id, payload) values ('razorpay', 'evt_1', '{}') $$,
  '42501',
  null,
  'owner admin cannot write webhook_events'
);

set local role anon;
select throws_ok(
  $$ select * from public.audit_log $$,
  '42501',
  null,
  'anon cannot read audit_log'
);
select throws_ok(
  $$ select * from public.webhook_events $$,
  '42501',
  null,
  'anon cannot read webhook_events'
);

-- Owner admin renames the property (a real admin write) — the security-definer trigger
-- should log it despite the owner having zero direct grants on audit_log.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object(
  'sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated', 'aal', 'aal2'
)::text, true);
update public.properties set name = 'Audited Rename' where id = '33333333-3333-3333-3333-333333333333';

reset role;
select ok(
  exists (
    select 1 from public.audit_log
    where table_name = 'properties'
      and action = 'UPDATE'
      and row_id = '33333333-3333-3333-3333-333333333333'
      and actor_type = 'admin'
      and actor_id = '11111111-1111-1111-1111-111111111111'
  ),
  'the property rename was captured in audit_log with the correct actor'
);

select * from finish();
rollback;
