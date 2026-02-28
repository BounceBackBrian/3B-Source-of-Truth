-- Phase 1 binary verification script
-- Replace placeholders before running.

-- ------------------------------------------------------------------
-- 0) Seed base identities
-- ------------------------------------------------------------------
insert into public.profiles (id, role, boost_status) values
  ('<CLIENT_A_UUID>', 'client', 'inactive'),
  ('<CLIENT_B_UUID>', 'client', 'inactive'),
  ('<ADMIN_UUID>', 'admin', 'active')
on conflict (id) do update
set role = excluded.role,
    boost_status = excluded.boost_status;

insert into public.businesses (id, owner_id, name)
values ('<BIZ_A_UUID>', '<CLIENT_A_UUID>', 'Client A Biz')
on conflict (id) do nothing;

insert into public.businesses (id, owner_id, name)
values ('<BIZ_B_UUID>', '<CLIENT_B_UUID>', 'Client B Biz')
on conflict (id) do nothing;

insert into public.memberships (user_id, business_id, role)
values
  ('<CLIENT_A_UUID>', '<BIZ_A_UUID>', 'owner'),
  ('<CLIENT_B_UUID>', '<BIZ_B_UUID>', 'owner')
on conflict (user_id, business_id) do nothing;

-- ------------------------------------------------------------------
-- 1) Create one project for each tenant (admin/service context)
-- ------------------------------------------------------------------
insert into public.projects (id, client_user_id, business_id, title, description)
values
  ('<PROJECT_A_UUID>', '<CLIENT_A_UUID>', '<BIZ_A_UUID>', 'A Project', 'Tenant A row'),
  ('<PROJECT_B_UUID>', '<CLIENT_B_UUID>', '<BIZ_B_UUID>', 'B Project', 'Tenant B row')
on conflict (id) do nothing;

-- ------------------------------------------------------------------
-- 2) Validation snapshots (attach screenshots)
-- ------------------------------------------------------------------
-- Index proof
select indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and tablename = 'boost_events'
  and indexname = 'boost_events_stripe_event_id_uq';

-- Constraint proof
select conname, pg_get_constraintdef(oid)
from pg_constraint
where conname = 'admin_override_expiry_rules';

-- Policy proof
select schemaname, tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('projects','businesses','memberships','admin_override_log','boost_events');

-- ------------------------------------------------------------------
-- 3) Role simulation checks (run in SQL editor with JWT claims)
-- ------------------------------------------------------------------
-- As Client A (boost inactive): expect 0 rows
-- set local request.jwt.claim.sub = '<CLIENT_A_UUID>';
-- set local role authenticated;
-- select id, client_user_id, business_id, title from public.projects;

-- As admin: expect both rows
-- set local request.jwt.claim.sub = '<ADMIN_UUID>';
-- set local role authenticated;
-- select id, client_user_id, business_id, title from public.projects;

-- Activate Client A and retry: expect only PROJECT_A row
-- update public.profiles set boost_status = 'active' where id = '<CLIENT_A_UUID>';
-- set local request.jwt.claim.sub = '<CLIENT_A_UUID>';
-- set local role authenticated;
-- select id, client_user_id, business_id, title from public.projects;
