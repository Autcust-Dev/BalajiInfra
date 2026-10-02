-- Read-only checks to run against the HOSTED database (Supabase Studio SQL editor, or
-- `psql` with a read-only role) BEFORE merging phase4-rooms-kyc-ebills-rents to main.
-- Nothing here writes anything. Run every query, read the notes under each, and only
-- proceed with the merge once every one matches its expected result.
--
-- Context for why these specific checks: the room_units migration
-- (20260924140000_room_units.sql) drops rooms.capacity, tenants.room_id, and
-- electricity_bills.room_id, repointing tenants/electricity_bills at a new room_units
-- table via a same-migration backfill. That backfill assumes today's tenants.room_id
-- always resolves to a room, and today's rooms all have a sane capacity — normally
-- guaranteed by existing FK/CHECK constraints, but worth confirming directly against
-- hosted's actual data rather than trusting the constraints alone.

-- 1. Has any part of this branch already been applied to hosted? If any of these tables
--    already exist, some migrations from this branch were already pushed during manual
--    testing — tell me which ones came back non-empty before merging, since it changes
--    what "before merge" even means for those specific tables.
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('floors', 'blocks', 'room_units', 'fines', 'electricity_bills', 'electricity_bill_splits')
order by table_name;
-- Expected (if nothing from this branch has touched hosted yet): zero rows.

-- 2. Does rooms.capacity still exist, and does every room have one? (Confirms the
--    column the migration is about to drop is in the state it assumes.)
select count(*) as rooms_with_capacity, count(*) filter (where capacity is null) as null_capacity
from public.rooms;
-- Expected: rooms_with_capacity = your real room count, null_capacity = 0.
-- If this query errors with "column capacity does not exist", the room_units migration
-- (or an equivalent manual change) already ran — stop and tell me before merging.

-- 3. Every tenant's room_id must resolve to a real room (guaranteed by the FK, but
--    confirming directly costs nothing and rules out a constraint someone disabled).
select count(*) as orphaned_tenants
from public.tenants t
left join public.rooms r on r.id = t.room_id
where r.id is null;
-- Expected: 0.

-- 4. Preview of what the room_units backfill will produce: one room_unit per room, and
--    how many tenants land in each. Multiple tenants per room is fine and expected
--    (that's the whole point of room_units); this is just visibility into current shape.
select r.id as room_id, r.room_number, r.capacity,
  count(t.id) as active_tenant_count
from public.rooms r
left join public.tenants t on t.room_id = r.id and t.status = 'active'
group by r.id, r.room_number, r.capacity
order by r.room_number;
-- Expected: no row where active_tenant_count > capacity is a hard blocker (the migration
-- handles it — it's the same "admin overrode the full-room warning" case already handled
-- in the admin UI), but worth knowing about ahead of time rather than being surprised.

-- 5. Any existing electricity_bills rows (only relevant if #1 showed electricity_bills
--    already exists on hosted) whose room_id wouldn't resolve to a room.
select count(*) as orphaned_bills
from public.electricity_bills eb
left join public.rooms r on r.id = eb.room_id
where r.id is null;
-- Expected: 0, or this query fails with "relation electricity_bills does not exist" —
-- either is fine; only a non-zero count here is a problem.

-- 6. Sanity check on properties/rooms counts overall, just so you have a before/after
-- number to compare against once the migration runs.
select
  (select count(*) from public.properties) as property_count,
  (select count(*) from public.rooms) as room_count,
  (select count(*) from public.tenants) as tenant_count,
  (select count(*) from public.tenants where status = 'active') as active_tenant_count;
