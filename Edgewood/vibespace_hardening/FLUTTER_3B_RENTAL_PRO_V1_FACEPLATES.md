# 3B Rental Pro V1 Faceplates (Flutter)

**Status:** DRAFT  
**Owner:** @BounceBackBrian  
**Date:** 2026-02-20

---

**Purpose:** 4 tight screens (Dashboard/Ledger/Record/Envelopes) → `lib/modules/property_ops/` → Home grid tile → repo/providers → realtime sub — 2-day build path.

---

## V1 Faceplates

| Screen      | Data                                              | Actions                                      |
|-------------|---------------------------------------------------|----------------------------------------------|
| Dashboard   | KPIs (30d sum/open env/maint), recent 10 payments | -                                            |
| Ledger      | payments list (RLS/filter unit/50)                | Tap details drawer                           |
| Record      | Cash form (unit/amt/env/notes/request_id auto)    | POST cash Edge, Stripe checkout URL          |
| Envelopes   | envelopes list (status)                           | Create/open/close                            |

---

## Folder Structure (lib/)

```text
modules/property_ops/
├── property_ops_faceplate.dart (shell/tabs)
├── repository/property_ops_repository.dart
├── providers/
│   ├── payments_provider.dart
│   ├── envelopes_provider.dart
│   └── kpi_provider.dart
└── pages/
    ├── dashboard_page.dart
    ├── ledger_page.dart
    ├── record_cash_page.dart
    └── envelopes_page.dart
```

**Home grid:** Add tile → route `PropertyOpsFaceplate`.

---

## Data/Queries (Supabase)

```dart
repo.fetchPayments({limit=50, unitId?}) → payments ORDER created_at DESC
fetchEnvelopes({status?}) → envelopes RLS
recordCash(...) → Edge POST
startStripe(...) → Edge → checkout_url
```

**Realtime:** Shell sub `property-ops:${t}:${b}` → ledger_append prepend/refetch. Client KPIs or RPC sum.

---

## Stripe Flow

Edge `vibespace-stripe-checkout`: Session metadata(tenant/business/unit) → URL → in-app webview. No cards app-side.

---

## 2-Day Build

**Day 1:** Tile/shell/Ledger + realtime list update.

**Day 2:** Cash form/Envelopes + Stripe button.

**Polish:** Loaders/toasts/errors/request_id copy.

---

## Needs

- tenant/business providers
- Supabase singleton
- Home grid slot
- auth JWT
- nav (go_router?)

---

**Status:** DRAFT. @BounceBackBrian – READY FOR REVIEW.
