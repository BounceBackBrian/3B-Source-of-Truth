BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS profiles;
CREATE SCHEMA IF NOT EXISTS vibe_space;
CREATE SCHEMA IF NOT EXISTS credit_builders;
CREATE SCHEMA IF NOT EXISTS data_core;

-- JWT helpers for consistent 3B identity enforcement.
CREATE OR REPLACE FUNCTION profiles.jwt_3b_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT auth.uid()::uuid
$$;

CREATE OR REPLACE FUNCTION profiles.jwt_3b_business_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT nullif((auth.jwt() ->> 'business_id'), '')::uuid
$$;

-- 3B businesses are tenant anchors for all products.
CREATE TABLE IF NOT EXISTS profiles.businesses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  owner_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 3B users are core identities used across subdomains.
CREATE TABLE IF NOT EXISTS profiles.users (
  id uuid PRIMARY KEY,
  email text UNIQUE,
  business_id uuid REFERENCES profiles.businesses(id),
  display_name text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE profiles.businesses
  DROP CONSTRAINT IF EXISTS businesses_owner_id_fkey,
  ADD CONSTRAINT businesses_owner_id_fkey
  FOREIGN KEY (owner_id)
  REFERENCES profiles.users(id)
  ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS public.boosts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles.users(id),
  business_id uuid NOT NULL REFERENCES profiles.businesses(id),
  type text NOT NULL CHECK (type IN ('credit_builders', 'vibe_space', 'studios')),
  status text NOT NULL CHECK (status IN ('trial', 'active', 'paused', 'cancelled')),
  starts_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vibe_space.rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES profiles.businesses(id),
  owner_id uuid NOT NULL REFERENCES profiles.users(id),
  slug text UNIQUE,
  title text NOT NULL,
  room_type text NOT NULL CHECK (room_type IN ('community', 'credit_builders', 'announcements')),
  is_private boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vibe_space.room_members (
  room_id uuid NOT NULL REFERENCES vibe_space.rooms(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'moderator', 'member')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS credit_builders.reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles.users(id),
  business_id uuid NOT NULL REFERENCES profiles.businesses(id),
  storage_path text NOT NULL,
  report_sha256 text,
  analyzed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS credit_builders.disputes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES credit_builders.reports(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES profiles.users(id),
  business_id uuid NOT NULL REFERENCES profiles.businesses(id),
  ai_analysis jsonb NOT NULL DEFAULT '{}'::jsonb,
  ai_letter text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'ready', 'sent', 'resolved')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Observability sink for all product actions.
CREATE TABLE IF NOT EXISTS data_core.event_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_name text NOT NULL,
  actor_id uuid REFERENCES profiles.users(id),
  business_id uuid REFERENCES profiles.businesses(id),
  product text NOT NULL CHECK (product IN ('vibe_space', 'credit_builders', 'vault', 'identity', 'api')),
  correlation_id uuid DEFAULT gen_random_uuid(),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Storage buckets used by Vault and generated dispute letters.
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('vault-private', 'vault-private', false),
  ('credit-disputes', 'credit-disputes', false)
ON CONFLICT (id) DO NOTHING;

REVOKE ALL ON SCHEMA profiles FROM anon;
REVOKE ALL ON SCHEMA vibe_space FROM anon;
REVOKE ALL ON SCHEMA credit_builders FROM anon;
REVOKE ALL ON SCHEMA data_core FROM anon;

GRANT USAGE ON SCHEMA profiles TO authenticated;
GRANT USAGE ON SCHEMA vibe_space TO authenticated;
GRANT USAGE ON SCHEMA credit_builders TO authenticated;
GRANT USAGE ON SCHEMA data_core TO authenticated;

ALTER TABLE profiles.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boosts ENABLE ROW LEVEL SECURITY;
ALTER TABLE vibe_space.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE vibe_space.room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_builders.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_builders.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_core.event_logs ENABLE ROW LEVEL SECURITY;

ALTER TABLE profiles.users FORCE ROW LEVEL SECURITY;
ALTER TABLE profiles.businesses FORCE ROW LEVEL SECURITY;
ALTER TABLE public.boosts FORCE ROW LEVEL SECURITY;
ALTER TABLE vibe_space.rooms FORCE ROW LEVEL SECURITY;
ALTER TABLE vibe_space.room_members FORCE ROW LEVEL SECURITY;
ALTER TABLE credit_builders.reports FORCE ROW LEVEL SECURITY;
ALTER TABLE credit_builders.disputes FORCE ROW LEVEL SECURITY;
ALTER TABLE data_core.event_logs FORCE ROW LEVEL SECURITY;

REVOKE ALL ON profiles.users FROM anon;
REVOKE ALL ON profiles.businesses FROM anon;
REVOKE ALL ON public.boosts FROM anon;
REVOKE ALL ON vibe_space.rooms FROM anon;
REVOKE ALL ON vibe_space.room_members FROM anon;
REVOKE ALL ON credit_builders.reports FROM anon;
REVOKE ALL ON credit_builders.disputes FROM anon;
REVOKE ALL ON data_core.event_logs FROM anon;

GRANT SELECT, INSERT, UPDATE ON profiles.users TO authenticated;
GRANT SELECT, INSERT, UPDATE ON profiles.businesses TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.boosts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON vibe_space.rooms TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON vibe_space.room_members TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON credit_builders.reports TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON credit_builders.disputes TO authenticated;
GRANT SELECT ON data_core.event_logs TO authenticated;

REVOKE INSERT, UPDATE, DELETE ON data_core.event_logs FROM authenticated;
GRANT INSERT ON data_core.event_logs TO service_role;

DROP POLICY IF EXISTS users_select_self ON profiles.users;
CREATE POLICY users_select_self
ON profiles.users
FOR SELECT
USING (id = profiles.jwt_3b_id());

DROP POLICY IF EXISTS users_upsert_self ON profiles.users;
CREATE POLICY users_upsert_self
ON profiles.users
FOR INSERT
WITH CHECK (id = profiles.jwt_3b_id());

DROP POLICY IF EXISTS users_update_self ON profiles.users;
CREATE POLICY users_update_self
ON profiles.users
FOR UPDATE
USING (id = profiles.jwt_3b_id())
WITH CHECK (id = profiles.jwt_3b_id());

DROP POLICY IF EXISTS businesses_select_members ON profiles.businesses;
CREATE POLICY businesses_select_members
ON profiles.businesses
FOR SELECT
USING (
  id = profiles.jwt_3b_business_id()
  OR owner_id = profiles.jwt_3b_id()
);

DROP POLICY IF EXISTS businesses_insert_owner ON profiles.businesses;
CREATE POLICY businesses_insert_owner
ON profiles.businesses
FOR INSERT
WITH CHECK (owner_id = profiles.jwt_3b_id());

DROP POLICY IF EXISTS businesses_update_owner ON profiles.businesses;
CREATE POLICY businesses_update_owner
ON profiles.businesses
FOR UPDATE
USING (owner_id = profiles.jwt_3b_id())
WITH CHECK (owner_id = profiles.jwt_3b_id());

DROP POLICY IF EXISTS boosts_rw_owner ON public.boosts;
CREATE POLICY boosts_rw_owner
ON public.boosts
FOR ALL
USING (
  user_id = profiles.jwt_3b_id()
  AND business_id = profiles.jwt_3b_business_id()
)
WITH CHECK (
  user_id = profiles.jwt_3b_id()
  AND business_id = profiles.jwt_3b_business_id()
);

DROP POLICY IF EXISTS rooms_select_member ON vibe_space.rooms;
CREATE POLICY rooms_select_member
ON vibe_space.rooms
FOR SELECT
USING (
  business_id = profiles.jwt_3b_business_id()
  AND (
    owner_id = profiles.jwt_3b_id()
    OR EXISTS (
      SELECT 1
      FROM vibe_space.room_members rm
      WHERE rm.room_id = id
      AND rm.user_id = profiles.jwt_3b_id()
    )
  )
);

DROP POLICY IF EXISTS rooms_insert_owner ON vibe_space.rooms;
CREATE POLICY rooms_insert_owner
ON vibe_space.rooms
FOR INSERT
WITH CHECK (
  owner_id = profiles.jwt_3b_id()
  AND business_id = profiles.jwt_3b_business_id()
);

DROP POLICY IF EXISTS room_members_rw_self ON vibe_space.room_members;
CREATE POLICY room_members_rw_self
ON vibe_space.room_members
FOR ALL
USING (user_id = profiles.jwt_3b_id())
WITH CHECK (user_id = profiles.jwt_3b_id());

DROP POLICY IF EXISTS room_members_insert_by_room_owner ON vibe_space.room_members;
CREATE POLICY room_members_insert_by_room_owner
ON vibe_space.room_members
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM vibe_space.rooms r
    WHERE r.id = room_id
      AND r.owner_id = profiles.jwt_3b_id()
      AND r.business_id = profiles.jwt_3b_business_id()
  )
);

DROP POLICY IF EXISTS room_members_delete_by_room_owner ON vibe_space.room_members;
CREATE POLICY room_members_delete_by_room_owner
ON vibe_space.room_members
FOR DELETE
USING (
  EXISTS (
    SELECT 1
    FROM vibe_space.rooms r
    WHERE r.id = room_id
      AND r.owner_id = profiles.jwt_3b_id()
      AND r.business_id = profiles.jwt_3b_business_id()
  )
);

DROP POLICY IF EXISTS reports_rw_owner ON credit_builders.reports;
CREATE POLICY reports_rw_owner
ON credit_builders.reports
FOR ALL
USING (
  user_id = profiles.jwt_3b_id()
  AND business_id = profiles.jwt_3b_business_id()
)
WITH CHECK (
  user_id = profiles.jwt_3b_id()
  AND business_id = profiles.jwt_3b_business_id()
);

DROP POLICY IF EXISTS disputes_rw_owner ON credit_builders.disputes;
CREATE POLICY disputes_rw_owner
ON credit_builders.disputes
FOR ALL
USING (
  user_id = profiles.jwt_3b_id()
  AND business_id = profiles.jwt_3b_business_id()
)
WITH CHECK (
  user_id = profiles.jwt_3b_id()
  AND business_id = profiles.jwt_3b_business_id()
);

DROP POLICY IF EXISTS event_logs_insert_service ON data_core.event_logs;
CREATE POLICY event_logs_insert_service
ON data_core.event_logs
FOR INSERT
WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS event_logs_select_business ON data_core.event_logs;
CREATE POLICY event_logs_select_business
ON data_core.event_logs
FOR SELECT
USING (business_id = profiles.jwt_3b_business_id());

DROP POLICY IF EXISTS storage_vault_readwrite_owner ON storage.objects;
CREATE POLICY storage_vault_readwrite_owner
ON storage.objects
FOR ALL
USING (
  bucket_id = 'vault-private'
  AND owner = profiles.jwt_3b_id()
)
WITH CHECK (
  bucket_id = 'vault-private'
  AND owner = profiles.jwt_3b_id()
);

DROP POLICY IF EXISTS storage_disputes_readwrite_owner ON storage.objects;
CREATE POLICY storage_disputes_readwrite_owner
ON storage.objects
FOR ALL
USING (
  bucket_id = 'credit-disputes'
  AND owner = profiles.jwt_3b_id()
)
WITH CHECK (
  bucket_id = 'credit-disputes'
  AND owner = profiles.jwt_3b_id()
);

COMMIT;
