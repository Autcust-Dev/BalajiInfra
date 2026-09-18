begin;
select plan(1);
select ok(true, 'pgTAP is wired up and runnable');
select * from finish();
rollback;
