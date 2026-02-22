-- ============================================================
-- 3B Rental Pro V1 (3Boost) — VibeSpace Extension
-- File: 001_hardened_v1.sql
-- Goals:
--  - Multi-tenant + multi-business enforcement (tenant_id + business_id)
--  - Immutable ledger (no updates/deletes)
--  - Idempotent inserts via request_id
--  - Cash envelopes (open/close)
--  - Maintenance (90-day dissolve)
--  - Oversight logs (append-only)
-- ============================================================

BEGIN;

-- -----------------------------
-- Helpers: JWT claim getters
-- -----------------------------
CREATE SCHEMA IF NOT EXISTS rentalpro;

CREATE OR REPLACE FUNCTION rentalpro.jwt_tenant_uuid()
RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT ((nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'tenant_id'))::uuid
$$;

CREATE OR REPLACE FUNCTION rentalpro.jwt_business_uuid()
RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT ((nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'business_id'))::uuid
$$;

CREATE OR REPLACE FUNCTION rentalpro.jwt_actor_uuid()
RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT ((nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid
$$;

-- -----------------------------
-- Core tables
-- -----------------------------

-- Units
CREATE TABLE IF NOT EXISTS public.units (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  business_id uuid NOT NULL,
  label text,
  status text NOT NULL DEFAULT 'active',
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Envelopes (cash)
CREATE TABLE IF NOT EXISTS public.envelopes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  business_id uuid NOT NULL,
  envelope_code text NOT NULL,
  status text NOT NULL DEFAULT 'open', -- open|closed
  opened_by uuid,
  closed_by uuid,
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS envelopes_code_uq
ON public.envelopes(tenant_id, business_id, envelope_code);

-- Payments (immutable ledger rows)
CREATE TABLE IF NOT EXISTS public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  business_id uuid NOT NULL,
  unit_id uuid REFERENCES public.units(id),
  amount numeric(12,2) NOT NULL CHECK (amount <> 0),
  method text NOT NULL CHECK (method IN ('cash','card','adjustment')),
  source text NOT NULL DEFAULT 'manual', -- manual|stripe|adjustment
  envelope_code text,
  request_id text NOT NULL, -- idempotency key (client-generated)
  stripe_event_id text,     -- webhook idempotency
  notes text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Idempotency across tenant/business
CREATE UNIQUE INDEX IF NOT EXISTS payments_request_uq
ON public.payments(tenant_id, business_id, request_id);

-- Stripe idempotency (optional)
CREATE UNIQUE INDEX IF NOT EXISTS payments_stripe_event_uq
ON public.payments(tenant_id, business_id, stripe_event_id)
WHERE stripe_event_id IS NOT NULL;

-- Fast ledger reads
CREATE INDEX IF NOT EXISTS payments_ledger_idx
ON public.payments(tenant_id, business_id, created_at DESC);

-- Maintenance
CREATE TABLE IF NOT EXISTS public.maintenance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  business_id uuid NOT NULL,
  unit_id uuid REFERENCES public.units(id),
  status text NOT NULL DEFAULT 'open', -- open|in_progress|done|dissolved
  priority text NOT NULL DEFAULT 'normal', -- low|normal|high|urgent
  description text,
  dissolve_at timestamptz,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE INDEX IF NOT EXISTS maintenance_idx
ON public.maintenance(tenant_id, business_id, status, created_at DESC);

CREATE OR REPLACE VIEW public.active_maintenance AS
SELECT *
FROM public.maintenance
WHERE deleted_at IS NULL;

-- Oversight logs (append-only)
CREATE TABLE IF NOT EXISTS public.oversight_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  business_id uuid NOT NULL,
  actor_id uuid,
  event_type text NOT NULL,
  entity_table text,
  entity_id uuid,
  request_id text,
  success boolean NOT NULL DEFAULT true,
  reason text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS oversight_logs_idx
ON public.oversight_logs(tenant_id, business_id, created_at DESC);

-- Stripe event gate (replay/duplicate storm protection)
CREATE TABLE IF NOT EXISTS public.stripe_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  business_id uuid NOT NULL,
  stripe_event_id text NOT NULL,
  status text NOT NULL DEFAULT 'received' CHECK (status IN ('received','processed','failed')),
  processed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

DROP INDEX IF EXISTS public.stripe_events_event_uq;
CREATE UNIQUE INDEX IF NOT EXISTS stripe_events_scoped_uq
ON public.stripe_events(tenant_id, business_id, stripe_event_id);

CREATE INDEX IF NOT EXISTS stripe_events_lookup_idx
ON public.stripe_events(tenant_id, business_id, created_at DESC);

-- -----------------------------
-- Immutable enforcement
-- -----------------------------

-- Block UPDATE/DELETE on ledger + logs
CREATE OR REPLACE FUNCTION rentalpro.block_updates_deletes()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Immutable table: updates/deletes are not allowed';
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'payments_no_update'
  ) THEN
    CREATE TRIGGER payments_no_update
    BEFORE UPDATE OR DELETE ON public.payments
    FOR EACH ROW EXECUTE FUNCTION rentalpro.block_updates_deletes();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'oversight_no_update'
  ) THEN
    CREATE TRIGGER oversight_no_update
    BEFORE UPDATE OR DELETE ON public.oversight_logs
    FOR EACH ROW EXECUTE FUNCTION rentalpro.block_updates_deletes();
  END IF;
END $$;

-- -----------------------------
-- Maintenance dissolve job helper
-- -----------------------------
CREATE OR REPLACE FUNCTION rentalpro.dissolve_maintenance()
RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
  updated_count int;
BEGIN
  UPDATE public.maintenance
  SET status = 'dissolved'
  WHERE deleted_at IS NULL
    AND status IN ('open','in_progress')
    AND dissolve_at IS NOT NULL
    AND dissolve_at <= now();

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN updated_count;
END;
$$;

-- -----------------------------
-- RLS: tenant_id + business_id enforced everywhere
-- -----------------------------
ALTER TABLE public.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.envelopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oversight_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stripe_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.units FROM anon, authenticated;
REVOKE ALL ON public.envelopes FROM anon, authenticated;
REVOKE ALL ON public.payments FROM anon, authenticated;
REVOKE ALL ON public.maintenance FROM anon, authenticated;
REVOKE ALL ON public.oversight_logs FROM anon, authenticated;
REVOKE ALL ON public.stripe_events FROM anon, authenticated;

-- ---------- units ----------
DROP POLICY IF EXISTS units_select ON public.units;
CREATE POLICY units_select
ON public.units
FOR SELECT
USING (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
);

DROP POLICY IF EXISTS units_insert ON public.units;
CREATE POLICY units_insert
ON public.units
FOR INSERT
WITH CHECK (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
);

-- ---------- envelopes ----------
DROP POLICY IF EXISTS envelopes_select ON public.envelopes;
CREATE POLICY envelopes_select
ON public.envelopes
FOR SELECT
USING (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
);

DROP POLICY IF EXISTS envelopes_insert ON public.envelopes;
CREATE POLICY envelopes_insert
ON public.envelopes
FOR INSERT
WITH CHECK (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
);

DROP POLICY IF EXISTS envelopes_close_update ON public.envelopes;
CREATE POLICY envelopes_close_update
ON public.envelopes
FOR UPDATE
USING (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
  AND status = 'open'
)
WITH CHECK (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
  AND status IN ('open','closed')
);

-- ---------- payments ----------
DROP POLICY IF EXISTS payments_select ON public.payments;
CREATE POLICY payments_select
ON public.payments
FOR SELECT
USING (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
);

DROP POLICY IF EXISTS payments_insert ON public.payments;
CREATE POLICY payments_insert
ON public.payments
FOR INSERT
WITH CHECK (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
);

-- ---------- maintenance ----------
DROP POLICY IF EXISTS maintenance_select ON public.maintenance;
CREATE POLICY maintenance_select
ON public.maintenance
FOR SELECT
USING (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
);

DROP POLICY IF EXISTS maintenance_insert ON public.maintenance;
CREATE POLICY maintenance_insert
ON public.maintenance
FOR INSERT
WITH CHECK (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
);

DROP POLICY IF EXISTS maintenance_update ON public.maintenance;
CREATE POLICY maintenance_update
ON public.maintenance
FOR UPDATE
USING (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
)
WITH CHECK (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
);

-- ---------- oversight_logs ----------
DROP POLICY IF EXISTS oversight_select ON public.oversight_logs;
CREATE POLICY oversight_select
ON public.oversight_logs
FOR SELECT
USING (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
);

DROP POLICY IF EXISTS oversight_insert ON public.oversight_logs;
CREATE POLICY oversight_insert
ON public.oversight_logs
FOR INSERT
WITH CHECK (
  auth.role() = 'service_role'
);

REVOKE INSERT ON public.oversight_logs FROM authenticated, anon;
REVOKE UPDATE, DELETE ON public.oversight_logs FROM authenticated, anon;

-- ---------- stripe_events ----------
DROP POLICY IF EXISTS stripe_events_select ON public.stripe_events;
CREATE POLICY stripe_events_select
ON public.stripe_events
FOR SELECT
USING (
  tenant_id = rentalpro.jwt_tenant_uuid()
  AND business_id = rentalpro.jwt_business_uuid()
);

DROP POLICY IF EXISTS stripe_events_insert ON public.stripe_events;
CREATE POLICY stripe_events_insert
ON public.stripe_events
FOR INSERT
WITH CHECK (
  auth.role() = 'service_role'
);

REVOKE INSERT ON public.stripe_events FROM anon, authenticated;
GRANT SELECT ON public.stripe_events TO authenticated;

COMMIT;
