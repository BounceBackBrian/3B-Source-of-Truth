# 3B Rental Pro V1 Flutter Implementation Guide

**Status:** DRAFT  
**Owner:** @BounceBackBrian  
**Date:** 2026-02-20

---

**Purpose:** 3B Rental Pro V1 faceplates build: `lib/modules/property_ops/` (shell/repo/providers/pages) → Home grid tile → 2-day (Day1: shell/ledger/realtime, Day2: cash/envelopes/Stripe)—needs nav/Home/providers paths for paste-code.

---

## Folder Deliverables

```text
lib/modules/property_ops/
├── property_ops_faceplate.dart (tabs + sub property-ops:${t}:${b})
├── repository/property_ops_repository.dart (fetchPayments/createEnvelope/recordCash/startStripe)
├── providers/
│   ├── payments_provider.dart (list/refresh/prepend)
│   ├── envelopes_provider.dart (list/create/close)
│   └── kpi_provider.dart (sum30d/open count client-calc)
└── pages/
    ├── dashboard_page.dart (KPIs + recent 10)
    ├── ledger_page.dart (list 50 + drawer)
    ├── record_cash_page.dart (form + Stripe URL)
    └── envelopes_page.dart (list + create/close)
```

**Repo central—no widget Supabase.**

---

## 2-Day Sequence

**Day 1:** Shell/tabs/repo/paymentsProvider/ledger + realtime prepend.

**Day 2:** Cash form/Edge/Envelopes CRUD/Stripe checkout URL webview + loaders/toasts/errors.

---

## Prereqs/Edges

### Needs

- tenantProvider/businessProvider/Supabase singleton
- Home grid tile slot (home_grid.dart?)
- Nav: go_router/AutoRoute/Navigator?

### Edges Need +1

`vibespace-stripe-checkout` → Session metadata(tenant/business/unit) → URL

---

## Paste-Ready Code Needs

Drop these 3 details (no guessing):

1. **Nav type:** go_router / AutoRoute / plain Navigator.push?
2. **home_grid.dart path:** Where is the Home grid tile defined?
3. **providers files:** Where are tenantProvider and businessProvider defined?

Paste your `home_grid.dart` and the provider definitions—adapt exact.

---

**Status:** DRAFT. @BounceBackBrian – READY FOR REVIEW.
