# DEPLOY_CUTOVER_CHECKLIST — 3B Rental Pro V1 (VibeSpace Home Faceplate)

## STATUS: APPROVED | V1 LIVE | 2026-02-20T20:54-08:00 | OWNER: Brian

**Status:** DRAFT  
**Owner:** @BounceBackBrian  
**Date:** 2026-02-20

Scope: Cutover Rental Pro V1 3Boost module in VibeSpace Home using deployed artifacts:

- `001_hardened_v1.sql`
- `rentalpro-cash-payment` Edge Function
- `rentalpro-stripe-webhook` Edge Function (Stripe signature verify + replay gate)
- Realtime channel: `property-ops:payments:{tenant_id}:{business_id}`
- Deprecated: `vibespace-*` cash/payment functions (retire after cutover)

## Pre-Cutover Gates (must be green)

### A) Repo + migration sanity

- [ ] `001_hardened_v1.sql` is canonical source of truth for Rental Pro schema hardening
- [ ] `supabase/migrations/001_hardened_v1.sql` matches canonical SQL
- [ ] `2026-02-20_3B-Rental-Pro-V1.md` references only `rentalpro-*` and marks `vibespace-*` deprecated

### B) DB deploy (staging first)

- [ ] `supabase db push` succeeds in staging
- [ ] Tables present: `units`, `envelopes`, `payments`, `maintenance`, `stripe_events`, `oversight_logs`
- [ ] Indexes present:
  - [ ] `payments_request_uq` on `(tenant_id, business_id, request_id)`
  - [ ] `stripe_events_scoped_uq` on `(tenant_id, business_id, stripe_event_id)`
- [ ] RLS enabled on all module tables
- [ ] `oversight_logs` INSERT restricted to `service_role`

### C) Edge Functions deploy

- [ ] `supabase functions deploy rentalpro-cash-payment`
- [ ] `supabase functions deploy rentalpro-stripe-webhook`
- [ ] `rentalpro-cash-payment` uses verified JWT claims path (`auth.getUser()` / equivalent verified context)
- [ ] `rentalpro-stripe-webhook` uses `stripe.webhooks.constructEvent(...)`
- [ ] `rentalpro-stripe-webhook` inserts into `stripe_events` replay gate before ledger writes
- [ ] Both functions write oversight rows via `service_role`

### D) Secrets (staging & prod)

- [ ] `SUPABASE_URL`
- [ ] `SUPABASE_SERVICE_ROLE_KEY`
- [ ] `STRIPE_SECRET_KEY`
- [ ] `STRIPE_WEBHOOK_SECRET`

### E) Realtime channel wiring (faceplate)

- [ ] Faceplate subscribes to `property-ops:payments:{tenant_id}:{business_id}`
- [ ] Event name: `ledger_append`
- [ ] Payload includes `tenant_id`, `business_id`, `event_type`, `entity_id`, `created_at`

### F) Post-deploy validation (staging)

Run RLS Test Pack as User A and User B:

- [ ] Claims present (`tenant/business/actor`)
- [ ] Cross-tenant/business reads return 0 rows
- [ ] UPDATE/DELETE on `payments` hard-fails (`Immutable table...`)
- [ ] Duplicate `request_id` caught
- [ ] Closed envelope rejected with `409`

### G) PASS stamp (Edge-only)

- [ ] `oversight_logs` contains `event_type = rentalpro_v1_rls_pass`
- [ ] Row written by `service_role`
- [ ] Payload includes tests/pass/timestamp/environment

## Prod Cutover (5 steps)

1. **UI routing**
   - Disable old payment actions
   - Enable Property Ops faceplate tile/path

2. **Deploy DB + Edge**
   - `supabase db push`
   - `supabase functions deploy rentalpro-cash-payment`
   - `supabase functions deploy rentalpro-stripe-webhook`

3. **Stripe webhook endpoint**
   - Point Stripe webhook to `rentalpro-stripe-webhook`
   - Send Stripe test event
   - Verify 2xx response
   - Verify `stripe_events` row transitions `received -> processed`
   - Verify one ledger row only (no duplicate)

4. **Faceplate live test**
   - Cash POST on open envelope -> payment + `ledger_append`
   - Second attempt with closed envelope -> `409`
   - Ledger shows last 50 + computed SUM
   - Reports export scoped by tenant/business

5. **Deprecation enforcement**
   - Mark `vibespace-*` as retired in spec/UI
   - Remove references from docs and routing
   - Keep deprecated functions only during monitoring window

## Monitoring Window (first 24–72h)

- [ ] Duplicate Stripe events return `200` and do not create new ledger rows
- [ ] Oversight noise remains low:
  - `stripe_webhook_failed`
  - `stripe_payment_idempotent_return`
  - `cash_payment_rejected`
- [ ] No cross-tenant leakage incidents

## Rollback Plan (traffic only)

### Trigger conditions

- Signature verification failures spike
- Realtime not reaching faceplate
- Cash flow blocked unexpectedly
- Any RLS anomaly (SEV-1)

### Rollback steps

1. Disable Property Ops payment actions in UI
2. Repoint/disable Stripe webhook temporarily
3. Keep DB migration in place (additive + RLS-safe; no schema undo under pressure)
4. If required, route traffic temporarily to deprecated `vibespace-*` flow
5. Write oversight event: `cutover_rollback`

## Cutover Complete Definition

Cutover is complete when:

- [ ] Prod webhook returns 2xx for valid events
- [ ] Duplicate Stripe events are ignored via replay gate
- [ ] `oversight_logs` contains prod PASS stamp row
- [ ] Faceplate receives `ledger_append` and reflects new rows
- [ ] Deprecated `vibespace-*` references are removed from spec/UI

---

**SharePoint target:**  
`3B-Source-of-Truth/20_Products/VibeSpace/DEPLOY_CUTOVER_CHECKLIST_2026-02-20.md`
