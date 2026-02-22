# Property Ops Faceplate (V1 skeleton)

> Drop this into your app package `lib/` and wire providers to your real state types.

```dart
class PropertyOpsFaceplate extends ConsumerStatefulWidget {
  const PropertyOpsFaceplate({super.key});

  @override
  ConsumerState<PropertyOpsFaceplate> createState() => _PropertyOpsFaceplateState();
}

class _PropertyOpsFaceplateState extends ConsumerState<PropertyOpsFaceplate> {
  static const int _maxItems = 100;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
    final tenantId = ref.read(tenantProvider).current!.id;
    final businessId = ref.read(businessProvider).current!.id;
    final channelName = 'property-ops:$tenantId:$businessId';

    _channel = supabase
      .channel(channelName)
        .onBroadcast(event: 'cash_payment', callback: (payload) {
          final payment = payload['payment'] as Map<String, dynamic>?;
          if (payment == null) return;
          ref.read(paymentsProvider.notifier).addPayment(payment);
          ref.read(paymentsProvider.notifier).trimToLast(_maxItems);
        })
        .onBroadcast(event: 'card_payment', callback: (payload) {
          final payment = payload['payment'] as Map<String, dynamic>?;
          if (payment == null) return;
          ref.read(paymentsProvider.notifier).addPayment(payment);
          ref.read(paymentsProvider.notifier).trimToLast(_maxItems);
        })
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(paymentsProvider).take(_maxItems).toList(growable: false);
    final balance = payments.fold<double>(
      0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
    );

    return Card(
      child: Column(
        children: [
          Text('Balance (last $_maxItems): \$${balance.toStringAsFixed(2)}'),
          Expanded(
            child: ListView.builder(
              itemCount: payments.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text('Cash: \$${payments[i]['amount']}'),
                subtitle: Text('Env: ${payments[i]['envelope_id'] ?? '-'}'),
              ),
            ),
          ),
          ElevatedButton(onPressed: _recordCash, child: const Text('Record Cash')),
        ],
      ),
    );
  }

  Future<void> _recordCash() async {
    // Form -> invoke vibespace-cash-payment
  }
}
```
