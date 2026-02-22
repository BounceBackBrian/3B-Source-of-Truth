# 3B Rental Pro V1 — VibeSpace Home Faceplate Module

Status: **APPROVED | V1 LIVE | 2026-02-20T20:54-08:00**  
Owner: **@BounceBackBrian**  
Date: **2026-02-20**

## Positioning Locks

- **Classification:** 3Boost module under VibeSpace V1 (Home grid faceplate).
- **Identity:** `tenant_id` (workspace), `business_id` (3B business), `user_id` (actor) from JWT claims.
- **Infra:** extends existing VibeSpace/Supabase only (no new database/service).
- **Money model:** Stripe provides payment signals; module stores immutable ledger rows only (no custody/escrow).

## Core Guardrails

- Multi-tenant scope on every module table with both `tenant_id` + `business_id`.
- RLS enabled on all module tables.
- Payments immutable by policy design (insert/select allowed, update/delete denied).
- Cash idempotency via `request_id` unique key per tenant/business.
- Stripe idempotency via unique `stripe_event_id` in receipts and `request_id=stripe-{event.id}` in payments.

## Channel Contract (Namespaced)

- Payments channel: `property-ops:payments:{tenant_id}:{business_id}`
  - Event: `ledger_append`
- Maintenance channel: `property-ops:maintenance:{tenant_id}:{business_id}`
  - Event: `maintenance_new`

Payload baseline:

- `tenant_id`, `business_id`, `event_type`, `entity_id`, `created_at`

## Data Model V1

- `units` (existing)
- `envelopes`
- `payments`
- `maintenance`
- `stripe_events` (replay gate)
- `oversight_logs` (append-only)

Every operational row includes tenant scope and actor attribution where applicable.

## Edge Function Contracts

### `rentalpro-cash-payment`

Input:

- `unit_id`, `amount`, `envelope_code`, `request_id`, `notes?`

Flow:

1. Verify JWT via `auth.getUser()`.
2. Validate open envelope under RLS scope.
3. Insert immutable payment with `request_id` (idempotent).
4. Close envelope.
5. Append `oversight_logs` event.
6. Broadcast `ledger_append` on namespaced payments channel.

### `rentalpro-stripe-webhook`

Requirements:

- Stripe metadata **must** include `tenant_id` and `business_id` (`unit_id` optional).

Flow:

1. Verify signature.
2. Insert into `stripe_events` gate (`received`) and short-circuit duplicate events with `200`.
3. Insert immutable card payment by scoped `request_id`.
4. Append `oversight_logs` (`stripe_webhook_received`, `stripe_payment_recorded`).
5. Broadcast `ledger_append` on namespaced payments channel.

## Scaling Phases

| Phase | Scope | Features |
| --- | --- | --- |
| 1 | 1 business, 5-50 units | Ledger, cash/Stripe, base RLS |
| 2 | Multi-business | Tenant/business switcher in VibeSpace header |
| 3 | Multi-tenant | Subdomain routing `rentalpro.vibespace.app/[tenant]` |

## Execution Order

1. Lock spec (`2026-02-20_3B-Rental-Pro-V1.md`).
2. Ship SQL migration (tables, indexes, triggers, policies).
3. Deploy cash function.
4. Deploy Stripe webhook.
5. Wire realtime subscribers in faceplate.
6. Execute RLS and idempotency tests.

## Deploy Runbook (CLI)

1. Link project

- `supabase status`
- `supabase projects list`
- `supabase link --project-ref <YOUR_PROJECT_REF>`

1. Push DB

- Ensure migration exists at `supabase/migrations/001_hardened_v1.sql`
- `supabase db push`

1. Set secrets

- `supabase secrets set --env-file supabase/.env.local`

1. Deploy functions

- `supabase functions deploy vibespace-cash-payment`
- `supabase functions deploy vibespace-stripe-webhook`

Replace with:

- `supabase functions deploy rentalpro-cash-payment`
- `supabase functions deploy rentalpro-stripe-webhook`

## Function Lifecycle

- `rentalpro-cash-payment` and `rentalpro-stripe-webhook` are active for V1.
- `vibespace-cash-payment` and `vibespace-stripe-webhook` are deprecated and should be retired after cutover.

## Fast Validation

- RLS: cross-tenant reads return zero rows.
- Cash idempotency: same `request_id` does not create duplicates.
- Stripe metadata required: webhook returns `400` when missing tenant/business metadata.
- Realtime: client receives only namespaced channel events.
