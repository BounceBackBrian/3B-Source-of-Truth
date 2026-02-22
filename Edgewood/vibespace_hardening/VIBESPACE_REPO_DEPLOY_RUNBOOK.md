# VibeSpace Repo Deploy Runbook

**Status:** DRAFT  
**Owner:** @BounceBackBrian  
**Date:** 2026-02-20

---

**Purpose:** Deployable right now from the VibeSpace repo. Exact "do it, don't think" runbook plus the gotchas that will waste hours if you miss them.

---

## Deploy Runbook (VibeSpace repo)

### 0) Preflight: Supabase project linked

From repo root:

```bash
supabase status
supabase projects list
supabase link --project-ref <YOUR_PROJECT_REF>
```

If you're already linked, `supabase link` will show it.

---

### 1) Put files in place

```bash
mkdir -p supabase/migrations
mkdir -p supabase/functions/vibespace-cash-payment
mkdir -p supabase/functions/vibespace-stripe-webhook
```

#### Create migration file

Create this file manually (your preferred exact name):

```text
supabase/migrations/001_hardened_v1.sql ✅
```

Paste your full corrected SQL bundle (with tenant-scoped receipts, triggers, policies, indexes).

---

### 2) Push DB migration

```bash
supabase db push
```

#### If it errors, it's almost always one of these

- `units` table doesn't exist yet (your envelope FK references it)
- `payments` table missing columns you assumed exist
- You created policies before enabling RLS (order matters)

**Fix and re-run.**

---

### 3) Set secrets (do this BEFORE deploying functions)

#### Option A: env-file (recommended)

Create `supabase/.env.local`:

```env
SUPABASE_URL=https://<PROJECT>.supabase.co
SUPABASE_ANON_KEY=<anon>
SUPABASE_SERVICE_ROLE_KEY=<service_role>
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
SYSTEM_USER_ID=00000000-0000-0000-0000-000000000000
```

Then:

```bash
supabase secrets set --env-file supabase/.env.local
```

#### Option B: individual (if you prefer)

```bash
supabase secrets set SUPABASE_URL=...
supabase secrets set SUPABASE_ANON_KEY=...
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...
supabase secrets set STRIPE_SECRET_KEY=...
supabase secrets set STRIPE_WEBHOOK_SECRET=...
supabase secrets set SYSTEM_USER_ID=00000000-0000-0000-0000-000000000000
```

---

### 4) Deploy functions

#### Cash payment function (anon + JWT forward)

Put your final code in:

```text
supabase/functions/vibespace-cash-payment/index.ts
```

Then:

```bash
supabase functions deploy vibespace-cash-payment
```

#### Stripe webhook (service role)

Put your final code in:

```text
supabase/functions/vibespace-stripe-webhook/index.ts
```

Then:

```bash
supabase functions deploy vibespace-stripe-webhook
```

---

## Stripe Setup (required for metadata mapping)

When you create the Checkout Session or PaymentIntent, you **must** include:

```json
{
  "metadata": {
    "tenant_id": "<uuid>",
    "business_id": "<uuid>",
    "unit_id": "<uuid optional>"
  }
}
```

**If that's missing, your webhook should correctly 400/reject.**

---

## Post-Deploy Tests (fast + decisive)

### 1) RLS sanity: user only sees tenant rows

Run as authenticated user in app (or SQL editor with RLS auth context, depending on your setup):

```sql
select count(*) from payments;
select count(*) from cash_envelopes;
select count(*) from payment_receipts;
```

**Expected:** counts are only your tenant/business

---

### 2) Cash function idempotency

Call `vibespace-cash-payment` twice with the same `request_id`.

**Expected:** first creates, second returns existing (no duplicate row)

Payload example:

```json
{
  "unit_id": "<uuid>",
  "amount": 1000,
  "envelope_code": "FEB-RENT-1001",
  "notes": "Cash drop",
  "request_id": "7b52c97f-9f7d-4c9f-96f7-2b7b4c3f2b8a"
}
```

---

### 3) Stripe webhook rejects missing metadata

Send a test event with empty metadata.

**Expected:** HTTP 400 "Missing metadata"

---

## One production gotcha (don't skip)

**Realtime broadcast + namespaced channels** requires clients to subscribe to the exact same channel string.

You already aligned:

```text
property-ops:${tenant_id}:${business_id}
```

**Make sure both:**

- cash function broadcasts to it
- webhook broadcasts to it
- Flutter subscribes to it

**No "property-ops" global anywhere.**

If you want the tightest production behavior: on `stripe_payment` broadcast, have the client **refetch ledger rows by receipt_id** (which you already wrote) instead of trusting payloads. That keeps the broadcast small and removes cross-version schema fragility.

---

**Status:** DRAFT. @BounceBackBrian – READY FOR REVIEW.
