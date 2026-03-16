BEGIN;

-- Roll back policies on storage objects introduced by the unification migration.
DROP POLICY IF EXISTS storage_disputes_readwrite_owner ON storage.objects;
DROP POLICY IF EXISTS storage_vault_readwrite_owner ON storage.objects;

-- Remove bucket rows seeded by the unification migration.
DELETE FROM storage.buckets WHERE id IN ('credit-disputes', 'vault-private');

-- Remove table policies in reverse dependency order.
DROP POLICY IF EXISTS event_logs_select_business ON data_core.event_logs;
DROP POLICY IF EXISTS event_logs_insert_service ON data_core.event_logs;

DROP POLICY IF EXISTS disputes_rw_owner ON credit_builders.disputes;
DROP POLICY IF EXISTS reports_rw_owner ON credit_builders.reports;

DROP POLICY IF EXISTS room_members_delete_by_room_owner ON vibe_space.room_members;
DROP POLICY IF EXISTS room_members_insert_by_room_owner ON vibe_space.room_members;
DROP POLICY IF EXISTS room_members_rw_self ON vibe_space.room_members;
DROP POLICY IF EXISTS rooms_insert_owner ON vibe_space.rooms;
DROP POLICY IF EXISTS rooms_select_member ON vibe_space.rooms;

DROP POLICY IF EXISTS boosts_rw_owner ON public.boosts;

DROP POLICY IF EXISTS businesses_update_owner ON profiles.businesses;
DROP POLICY IF EXISTS businesses_insert_owner ON profiles.businesses;
DROP POLICY IF EXISTS businesses_select_members ON profiles.businesses;

DROP POLICY IF EXISTS users_update_self ON profiles.users;
DROP POLICY IF EXISTS users_upsert_self ON profiles.users;
DROP POLICY IF EXISTS users_select_self ON profiles.users;

-- Remove core tables in reverse FK order.
DROP TABLE IF EXISTS data_core.event_logs;
DROP TABLE IF EXISTS credit_builders.disputes;
DROP TABLE IF EXISTS credit_builders.reports;
DROP TABLE IF EXISTS vibe_space.room_members;
DROP TABLE IF EXISTS vibe_space.rooms;
DROP TABLE IF EXISTS public.boosts;
DROP TABLE IF EXISTS profiles.users;
DROP TABLE IF EXISTS profiles.businesses;

-- Remove helper functions.
DROP FUNCTION IF EXISTS profiles.jwt_3b_business_id();
DROP FUNCTION IF EXISTS profiles.jwt_3b_id();

-- Remove schemas if now empty.
DROP SCHEMA IF EXISTS data_core;
DROP SCHEMA IF EXISTS credit_builders;
DROP SCHEMA IF EXISTS vibe_space;
DROP SCHEMA IF EXISTS profiles;

COMMIT;
