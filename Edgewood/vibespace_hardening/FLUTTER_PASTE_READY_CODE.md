# 3B Rental Pro V1 — Flutter Paste Ready (Property Ops Faceplates)

## Goal

A **pure module** drop-in: no coupling to app-level providers.  
Home injects `{ tenantId, businessId }`. The module handles tabs + realtime + providers + pages.

---

## Structure (Drop-In)

```text
lib/modules/property_ops/
├── property_ops_faceplate.dart
├── repository/
│   └── property_ops_repository.dart
├── providers/
│   ├── property_ops_repo_provider.dart
│   ├── payments_provider.dart
│   ├── envelopes_provider.dart
│   └── kpi_provider.dart
└── pages/
    ├── dashboard_page.dart
    ├── ledger_page.dart
    ├── record_cash_page.dart
    └── envelopes_page.dart
```

**Rule:** Pages never call Supabase directly. Only repository does.

---

## Pure Module Pattern (Zero TODOs)

### Why this pattern

- The module stays reusable and stable.
- App-specific tenancy/business context stays at the edge (Home tile).

### Realtime channel namespace

**MUST match exactly** across Edge + Flutter:
`property-ops:<tenantId>:<businessId>`

No global channels. No mixed tenants.

---

## property_ops_faceplate.dart (Final, Uncut)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/dashboard_page.dart';
import 'pages/ledger_page.dart';
import 'pages/record_cash_page.dart';
import 'pages/envelopes_page.dart';
import 'providers/payments_provider.dart';

/// 3B Rental Pro V1 - Property Ops Faceplate (Pure Module)
/// - tenantId + businessId injected via constructor (no provider coupling)
/// - Realtime: property-ops:<tenantId>:<businessId>
/// - Day 1: Ledger refresh on mount
class PropertyOpsFaceplate extends ConsumerStatefulWidget {
  final String tenantId;
  final String businessId;

  const PropertyOpsFaceplate({
    super.key,
    required this.tenantId,
    required this.businessId,
  });

  @override
  ConsumerState<PropertyOpsFaceplate> createState() => _PropertyOpsFaceplateState();
}

class _PropertyOpsFaceplateState extends ConsumerState<PropertyOpsFaceplate> {
  RealtimeChannel? _channel;
  int _tab = 0;

  @override
  void initState() {
    super.initState();

    // Day 1: boot load ledger on mount
    Future.microtask(() async {
      await ref.read(paymentsProvider.notifier).refresh(limit: 50);
      _subscribeRealtime();
    });
  }

  void _subscribeRealtime() {
    final supabase = Supabase.instance.client;
    final channelName = 'property-ops:${widget.tenantId}:${widget.businessId}';

    _channel?.unsubscribe();
    _channel = supabase.channel(channelName);

    _channel!
        .on(
          RealtimeListenTypes.broadcast,
          ChannelFilter(event: 'cash_payment'),
          (payload, [refFromCb]) {
            final data = payload['payload'] as Map?;
            final payment = data?['payment'];
            if (payment is Map) {
              ref.read(paymentsProvider.notifier).prepend(payment.cast<String, dynamic>());
            } else {
              // Fallback safety: refresh if payload shape changes
              ref.read(paymentsProvider.notifier).refresh(limit: 50);
            }
          },
        )
        .on(
          RealtimeListenTypes.broadcast,
          ChannelFilter(event: 'stripe_payment'),
          (payload, [refFromCb]) {
            // Safest V1: refetch (ledger source of truth)
            ref.read(paymentsProvider.notifier).refresh(limit: 50);
          },
        );

    _channel!.subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      DashboardPage(),
      LedgerPage(),
      RecordCashPage(),
      EnvelopesPage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Property Ops')),
      body: pages[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Ledger'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Record'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Envelopes'),
        ],
      ),
    );
  }
}
```

---

## Home Tile Adapters (Choose One)

### Adapter A — Navigator.push

```dart
final tenantId = ref.read(tenantProvider).current!.id;
final businessId = ref.read(businessProvider).id;

Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => PropertyOpsFaceplate(
      tenantId: tenantId,
      businessId: businessId,
    ),
  ),
);
```

### Adapter B — go_router

**Route:**

```dart
GoRoute(
  path: '/property-ops',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>;
    return PropertyOpsFaceplate(
      tenantId: extra['tenantId'] as String,
      businessId: extra['businessId'] as String,
    );
  },
),
```

**Tile tap:**

```dart
final tenantId = ref.read(tenantProvider).current!.id;
final businessId = ref.read(businessProvider).id;

context.go('/property-ops', extra: {
  'tenantId': tenantId,
  'businessId': businessId,
});
```

---

## Edge Functions Required (Exact)

### vibespace-cash-payment

- anon + forwarded JWT → RLS enforced → idempotent by request_id → broadcasts namespaced `cash_payment`

### vibespace-stripe-checkout

- anon + forwarded JWT → creates Stripe checkout session with metadata `{ tenant_id, business_id, unit_id }` → returns `checkout_url`

### vibespace-stripe-webhook

- service role only → verifies signature → requires metadata mapping → upserts receipt → inserts payment → broadcasts namespaced `stripe_payment`

---

## SDK Compatibility Note (Supabase Flutter)

Realtime types & `.on()` callback signatures can vary by `supabase_flutter` version:

- `RealtimeChannel`
- `RealtimeListenTypes`
- `ChannelFilter`

**If you get a compile error:**

1. Check your `supabase_flutter` version in `pubspec.yaml`
2. Search existing codebase for `supabase.channel(` usage and mirror that signature

---

## Critical Reminder (No Leaks)

**Channel string MUST match exactly** in:

- cash function broadcast
- stripe webhook broadcast
- flutter subscribe

```text
property-ops:<tenantId>:<businessId>
```

**No global** `property-ops`.

---

## 2-Day Execution Path (Locked)

### Day 1

1. Paste module folder
2. Add Home tile → inject tenantId/businessId
3. Ledger loads last 50
4. Realtime prepend on `cash_payment`

### Day 2

1. Record cash form → Edge invoke → toast success
2. Envelopes CRUD (create/close)
3. Stripe checkout URL flow (open webview/browser)
4. Loaders/toasts/errors

---

## Final Key Locks (V1)

### 1) Faceplate = Pure Module

- `PropertyOpsFaceplate` requires `tenantId` + `businessId` via constructor  
- No app-level providers referenced inside module  
- Realtime channel is strictly namespaced:

`property-ops:<tenantId>:<businessId>`

---

### 2) Home Adapter A — Navigator (Riverpod)

```dart
final tenantId = ref.read(tenantProvider).current!.id;
final businessId = ref.read(businessProvider).id;

Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => PropertyOpsFaceplate(
      tenantId: tenantId,
      businessId: businessId,
    ),
  ),
);
```

### 3) Home Adapter B — go_router

**Route definition:**

```dart
GoRoute(
  path: '/property-ops',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>;
    return PropertyOpsFaceplate(
      tenantId: extra['tenantId'] as String,
      businessId: extra['businessId'] as String,
    );
  },
),
```

**Tile tap:**

```dart
final tenantId = ref.read(tenantProvider).current!.id;
final businessId = ref.read(businessProvider).id;

context.go('/property-ops', extra: {
  'tenantId': tenantId,
  'businessId': businessId,
});
```

### 4) Realtime Contract (No Cross-Tenant Leaks)

**The channel string must match EXACTLY across:**

- `vibespace-cash-payment` broadcast
- `vibespace-stripe-webhook` broadcast
- Flutter subscription

```text
property-ops:<tenantId>:<businessId>
```

**No global** `property-ops` **channel anywhere.**

### 5) Execution Path (Locked)

**Day 1:**

- Paste module folder
- Add Home tile adapter
- Ledger loads last 50
- `cash_payment` broadcast prepends without refresh

**Day 2:**

- Record Cash form → `vibespace-cash-payment`
- Envelopes CRUD
- Stripe Checkout → `vibespace-stripe-checkout`
- Webhook → `vibespace-stripe-webhook`

---

That's now genuinely "paste + execute."

If you want one last production-level hardening pass, I can give you a quick checklist to confirm:

- No runtime channel mismatches  
- No RLS scope leaks  
- No duplicate request_id collisions  
- Stripe metadata mapping verified  

Otherwise, you're in ship mode.

**Status:** DRAFT. @BounceBackBrian – READY FOR REVIEW.
