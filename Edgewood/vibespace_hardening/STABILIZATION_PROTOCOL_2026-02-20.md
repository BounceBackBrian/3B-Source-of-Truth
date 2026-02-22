# STABILIZATION_PROTOCOL_2026-02-20

## STATUS: STABILIZING | NO CHANGES | 48H SIGNAL MONITOR

**Status:** STABILIZING (Live)  
**Owner:** @BounceBackBrian  
**Window:** 48 hours operator mode

3B Rental Pro V1 stabilizing: 48h operator mode — no touches, twice-daily signals clean -> Phase 2 tenant switcher.

## 2x Daily Checks

```sql
-- 1) oversight_rates
SELECT event_type, COUNT(*)
FROM oversight_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY event_type
ORDER BY COUNT(*) DESC;
```

Healthy:

- `stripe_payment_recorded` normal
- `*_idempotent_return` low/expected
- `stripe_webhook_failed = 0`
- `cash_payment_rejected` explainable

Upgrade rule:

- If `stripe_webhook_failed > 0` for **two checks in a row** -> investigate immediately.
- One spike may be transient noise; two indicates drift.

```sql
-- 2) stripe_gate
SELECT status, COUNT(*)
FROM stripe_events
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY status;
```

Healthy:

- `processed >> received`
- `failed = 0`

```sql
-- 3) ledger
SELECT COUNT(*)
FROM payments
WHERE created_at > NOW() - INTERVAL '24 hours';
```

Manual verification:

- UI ledger count matches DB count
- no duplicate rows tied to same Stripe event identity
- no negative adjustment anomalies unless intentional/approved

**Anomalies: immediate triage.**

SEV1 condition:

- If ledger truth diverges between DB and UI, treat as SEV1 immediately.

## Rules (48h Strict)

- ❌ No schema changes
- ❌ No UI changes
- ❌ No refactors
- ❌ No “quick fixes”
- ✅ Signals only — hold the line

## Accomplished State

- Multi-tenant immutable ledger
- Replay-safe Stripe flow
- RLS + service_role audit controls
- Controlled rollback path

## Exit Criterion

If 48h signals stay clean: proceed to **Phase 2 — multi-business tenant switcher**.

After clean 48h, update top line to:

`STATUS: STABLE | PHASE 2 AUTHORIZED`

---

Status: STABILIZING. @BounceBackBrian – OPERATOR MODE ACTIVE.
