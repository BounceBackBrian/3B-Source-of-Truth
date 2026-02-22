# 3B Rental Pro V1 — PROD SHIP RUNBOOK

## STATUS: APPROVED | V1 LIVE | 2026-02-20T20:54-08:00 | OWNER: Brian

3B Rental Pro V1 PROD RUNBOOK—Execute in order: SharePoint lock → UI freeze → DB/functions → secrets → Stripe test → live realtime/RLS/PASS → monitor → APPROVED.

## 0-5 Steps (Terminal/UI)

```text
0) SharePoint: STATUS: EXECUTING | 2026-02-20 | Brian ✓

1) UI: Legacy payments OFF, faceplate ON ✓

2) supabase db push
   functions deploy rentalpro-cash-payment rentalpro-stripe-webhook ✓

3) supabase secrets list | grep STRIPE  # 4 present ✓

4) Stripe: Endpoint rentalpro-stripe-webhook → test evt 2xx, 1 payment, dup 0 ✓

5A) Console sub property-ops:payments:{t}:{b} → cash → DB/UI once ✓
5B) RLS pack: 6/6 cross-tenant 0, immutable fail, dup caught ✓
5C) SELECT oversight_logs 'rentalpro_v1_rls_pass' → exists ✓
```

## Monitoring Query (24h)

Run this **twice daily for the next 48 hours** (morning + night):

```sql
SELECT event_type, COUNT(*) FROM oversight_logs
WHERE created_at > NOW() - INTERVAL '24 hours' GROUP BY event_type ORDER BY COUNT(*) DESC;
```

failed ~0 SEV1

idempotent OK

rejected triage

## 48-Hour Stabilization Protocol (No Feature Creep)

### Twice Daily Checks (Morning / Evening)

#### 1) Oversight event rates

```sql
SELECT event_type, COUNT(*)
FROM oversight_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY event_type
ORDER BY COUNT(*) DESC;
```

Healthy pattern:

- `stripe_payment_recorded` = normal volume
- `*_idempotent_return` = low but present (replay working)
- `stripe_webhook_failed` ≈ 0
- `cash_payment_rejected` stable and explainable

Upgrade rule: if `stripe_webhook_failed > 0` for **two checks in a row**, investigate immediately.

#### 2) Stripe replay gate health

```sql
SELECT status, COUNT(*)
FROM stripe_events
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY status;
```

Healthy:

- `processed` dominant
- `received` low and transient
- `failed` = 0

If `received` grows without matching `processed`, alert for processing stall.

#### 3) Ledger integrity quick check

```sql
SELECT COUNT(*)
FROM payments
WHERE created_at > NOW() - INTERVAL '24 hours';
```

Manual confirmation:

- Ledger UI count matches DB count
- No duplicate amounts tied to same Stripe event identity
- No negative adjustment anomalies unless intentional/approved

SEV1: DB/UI ledger divergence.

### Behavioral Rule (48h)

- No schema edits
- No refactors
- No UI polish
- No “quick improvements”

If it isn’t broken, do not touch it.

### Mode

**Operator mode only** for 48h. If all signals stay clean, move to Phase 2 planning afterward.

Post-48h clean status line:

`STATUS: STABLE | PHASE 2 AUTHORIZED`

## Rollback 2min

```text
UI faceplate OFF
Stripe webhook disable/old
oversight cutover_rollback
DB safe—no revert
```

## Post-Ship SharePoint

STATUS: APPROVED | V1 LIVE | 2026-02-20T20:54 + signals.

---

Status: APPROVED. V1 LIVE.

