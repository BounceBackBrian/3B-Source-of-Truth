-- 001_hardened_v1.sql
-- 3B Rental Pro V1 Hardening Bundle (VibeSpace-safe)

BEGIN;

-- ===============
-- 0) Extensions (if needed)
-- ===============
-- create extension if not exists pgcrypto;

-- ===============
-- 1) Tables
-- ===============

-- Receipts table MUST be tenant-scoped
CREATE TABLE IF NOT EXISTS public.payment_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  business_id UUID NOT NULL,
  stripe_event_id TEXT UNIQUE NOT NULL,
  stripe_payment_intent_id TEXT,
  data JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cash envelopes (assumes units table exists)
CREATE TABLE IF NOT EXISTS public.cash_envelopes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  business_id UUID NOT NULL,
  unit_id UUID REFERENCES public.units(id),
  envelope_code TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed','reconciled')),
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Maintenance (optional V1 section)
CREATE TABLE IF NOT EXISTS public.maintenance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  business_id UUID NOT NULL,
  unit_id UUID REFERENCES public.units(id),
  status TEXT NOT NULL DEFAULT 'open',
  priority TEXT NOT NULL DEFAULT 'normal',
  description TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  dissolve_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ
);

CREATE OR REPLACE VIEW public.active_maintenance AS
SELECT *
FROM public.maintenance
WHERE deleted_at IS NULL;

-- Oversight append-only logs
CREATE TABLE IF NOT EXISTS public.oversight_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  business_id UUID NOT NULL,
  actor_id UUID,
  event_type TEXT NOT NULL,
  entity_id UUID,
  request_id TEXT,
  success BOOLEAN NOT NULL DEFAULT true,
  reason TEXT,
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Scoped unique index (no global collisions)
DROP INDEX IF EXISTS public.cash_envelopes_tenant_business_code_uq;
CREATE UNIQUE INDEX cash_envelopes_tenant_business_code_uq
  ON public.cash_envelopes (tenant_id, business_id, envelope_code);

-- Payments hardening (assumes payments already exists)
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS tenant_id UUID,
  ADD COLUMN IF NOT EXISTS business_id UUID,
  ADD COLUMN IF NOT EXISTS created_by UUID,
  ADD COLUMN IF NOT EXISTS immutable BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS envelope_id UUID REFERENCES public.cash_envelopes(id),
  ADD COLUMN IF NOT EXISTS request_id TEXT,
  ADD COLUMN IF NOT EXISTS receipt_id UUID REFERENCES public.payment_receipts(id),
  ADD COLUMN IF NOT EXISTS stripe_id TEXT;

-- Idempotency (tenant+business scoped)
CREATE UNIQUE INDEX IF NOT EXISTS payments_tenant_request_uq
  ON public.payments (tenant_id, business_id, request_id)
  WHERE request_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS payments_tenant_business_created_idx
  ON public.payments (tenant_id, business_id, created_at DESC);

CREATE INDEX IF NOT EXISTS cash_envelopes_tenant_business_created_idx
  ON public.cash_envelopes (tenant_id, business_id, created_at DESC);

CREATE INDEX IF NOT EXISTS payment_receipts_tenant_business_created_idx
  ON public.payment_receipts (tenant_id, business_id, created_at DESC);

CREATE INDEX IF NOT EXISTS maintenance_tenant_business_created_idx
  ON public.maintenance (tenant_id, business_id, created_at DESC);

CREATE INDEX IF NOT EXISTS oversight_logs_tenant_business_created_idx
  ON public.oversight_logs (tenant_id, business_id, created_at DESC);

-- Stripe receipts unique (constraint-level)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'payment_receipts_stripe_event_uq'
      AND conrelid = 'public.payment_receipts'::regclass
  ) THEN
    ALTER TABLE public.payment_receipts
      ADD CONSTRAINT payment_receipts_stripe_event_uq UNIQUE (stripe_event_id);
  END IF;
END $$;

-- ===============
-- 2) RLS Enable
-- ===============
ALTER TABLE public.cash_envelopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oversight_logs ENABLE ROW LEVEL SECURITY;

-- ===============
-- 3) Trigger: auto-set tenant/business/created_by from JWT (user-scoped paths)
-- NOTE: For service role inserts, set tenant/business explicitly in code.
-- ===============
CREATE OR REPLACE FUNCTION public.set_vibe_tenant_fields()
RETURNS TRIGGER AS $$
BEGIN
  IF (auth.jwt() ->> 'tenant_id') IS NOT NULL THEN
    NEW.tenant_id := COALESCE(NEW.tenant_id, (auth.jwt() ->> 'tenant_id')::uuid);
  END IF;

  IF (auth.jwt() ->> 'business_id') IS NOT NULL THEN
    NEW.business_id := COALESCE(NEW.business_id, (auth.jwt() ->> 'business_id')::uuid);
  END IF;

  IF auth.uid() IS NOT NULL THEN
    NEW.created_by := COALESCE(NEW.created_by, auth.uid());
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_envelopes_set_tenant ON public.cash_envelopes;
CREATE TRIGGER trg_envelopes_set_tenant
BEFORE INSERT ON public.cash_envelopes
FOR EACH ROW EXECUTE FUNCTION public.set_vibe_tenant_fields();

DROP TRIGGER IF EXISTS trg_payments_set_tenant ON public.payments;
CREATE TRIGGER trg_payments_set_tenant
BEFORE INSERT ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.set_vibe_tenant_fields();

DROP TRIGGER IF EXISTS trg_maintenance_set_tenant ON public.maintenance;
CREATE TRIGGER trg_maintenance_set_tenant
BEFORE INSERT ON public.maintenance
FOR EACH ROW EXECUTE FUNCTION public.set_vibe_tenant_fields();

-- Restrictive tenant/business guardrail (AND-ed with command policies)
DROP POLICY IF EXISTS "VibeSpace tenant payments full" ON public.payments;
CREATE POLICY "VibeSpace tenant payments full"
ON public.payments
AS RESTRICTIVE
FOR ALL
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
)
WITH CHECK (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
);

-- ===============
-- 4) Policies (JWT-claim scoped)
-- ===============

-- PAYMENTS
DROP POLICY IF EXISTS payments_select ON public.payments;
CREATE POLICY payments_select ON public.payments
FOR SELECT
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
);

DROP POLICY IF EXISTS payments_insert ON public.payments;
CREATE POLICY payments_insert ON public.payments
FOR INSERT
WITH CHECK (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
  AND created_by = auth.uid()
);

DROP POLICY IF EXISTS payments_update_mutable_only ON public.payments;
CREATE POLICY payments_update_mutable_only ON public.payments
FOR UPDATE
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
  AND immutable = false
)
WITH CHECK (immutable = false);

DROP POLICY IF EXISTS payments_delete_deny ON public.payments;
CREATE POLICY payments_delete_deny ON public.payments
FOR DELETE USING (false);

-- ENVELOPES
DROP POLICY IF EXISTS envelopes_select ON public.cash_envelopes;
CREATE POLICY envelopes_select ON public.cash_envelopes
FOR SELECT
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
);

DROP POLICY IF EXISTS envelopes_insert ON public.cash_envelopes;
CREATE POLICY envelopes_insert ON public.cash_envelopes
FOR INSERT
WITH CHECK (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
  AND created_by = auth.uid()
);

DROP POLICY IF EXISTS envelopes_update ON public.cash_envelopes;
CREATE POLICY envelopes_update ON public.cash_envelopes
FOR UPDATE
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
)
WITH CHECK (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
);

DROP POLICY IF EXISTS envelopes_delete_deny ON public.cash_envelopes;
CREATE POLICY envelopes_delete_deny ON public.cash_envelopes
FOR DELETE USING (false);

-- RECEIPTS (read-only to tenant/business; inserts are service role)
DROP POLICY IF EXISTS receipts_select ON public.payment_receipts;
CREATE POLICY receipts_select ON public.payment_receipts
FOR SELECT
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
);

DROP POLICY IF EXISTS receipts_insert_deny ON public.payment_receipts;
CREATE POLICY receipts_insert_deny ON public.payment_receipts
FOR INSERT WITH CHECK (false);

DROP POLICY IF EXISTS receipts_update_deny ON public.payment_receipts;
CREATE POLICY receipts_update_deny ON public.payment_receipts
FOR UPDATE USING (false);

DROP POLICY IF EXISTS receipts_delete_deny ON public.payment_receipts;
CREATE POLICY receipts_delete_deny ON public.payment_receipts
FOR DELETE USING (false);

-- MAINTENANCE
DROP POLICY IF EXISTS maintenance_select ON public.maintenance;
CREATE POLICY maintenance_select ON public.maintenance
FOR SELECT
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
);

DROP POLICY IF EXISTS maintenance_insert ON public.maintenance;
CREATE POLICY maintenance_insert ON public.maintenance
FOR INSERT
WITH CHECK (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
  AND created_by = auth.uid()
);

DROP POLICY IF EXISTS maintenance_update ON public.maintenance;
CREATE POLICY maintenance_update ON public.maintenance
FOR UPDATE
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
)
WITH CHECK (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
);

DROP POLICY IF EXISTS maintenance_delete_deny ON public.maintenance;
CREATE POLICY maintenance_delete_deny ON public.maintenance
FOR DELETE USING (false);

-- OVERSIGHT LOGS (append-only)
DROP POLICY IF EXISTS oversight_logs_select ON public.oversight_logs;
CREATE POLICY oversight_logs_select ON public.oversight_logs
FOR SELECT
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
);

DROP POLICY IF EXISTS oversight_logs_insert ON public.oversight_logs;
CREATE POLICY oversight_logs_insert ON public.oversight_logs
FOR INSERT
WITH CHECK (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND business_id = (auth.jwt() ->> 'business_id')::uuid
);

DROP POLICY IF EXISTS oversight_logs_update_deny ON public.oversight_logs;
CREATE POLICY oversight_logs_update_deny ON public.oversight_logs
FOR UPDATE USING (false);

DROP POLICY IF EXISTS oversight_logs_delete_deny ON public.oversight_logs;
CREATE POLICY oversight_logs_delete_deny ON public.oversight_logs
FOR DELETE USING (false);

COMMIT;
