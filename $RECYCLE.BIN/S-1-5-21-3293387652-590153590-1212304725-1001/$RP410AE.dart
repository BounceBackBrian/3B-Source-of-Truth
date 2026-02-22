import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// NOTE:
// - This is a skeleton snippet.
// - Keep list capped in V1 (avoid unbounded in-memory balance scans).
// - Prefer server-side aggregate endpoint for true balance in V2.

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

    _channel = supabase
        .channel('property-ops')
        .onBroadcast(
          event: 'cash_payment',
          callback: (payload) {
            final payment = payload['payment'] as Map<String, dynamic>?;
            if (payment == null) return;
            ref.read(paymentsProvider.notifier).addPayment(payment);
            ref.read(paymentsProvider.notifier).trimToLast(_maxItems);
          },
        )
        .onBroadcast(
          event: 'card_payment',
          callback: (payload) {
            final payment = payload['payment'] as Map<String, dynamic>?;
            if (payment == null) return;
            ref.read(paymentsProvider.notifier).addPayment(payment);
            ref.read(paymentsProvider.notifier).trimToLast(_maxItems);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    final supabase = Supabase.instance.client;
    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(paymentsProvider);

    // V1 approximation (last N only). Replace with server aggregate for exact balance.
    final capped = payments.take(_maxItems).toList(growable: false);
    final balance = capped.fold<double>(
      0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balance (last $_maxItems): \$${balance.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: capped.length,
                itemBuilder: (context, i) {
                  final p = capped[i];
                  return ListTile(
                    dense: true,
                    title: Text('${p['method'] ?? 'cash'}: \$${p['amount']}'),
                    subtitle: Text('Env: ${p['envelope_id'] ?? '-'} · Rcpt: ${p['receipt_id'] ?? '-'}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _recordCash,
              child: const Text('Record Cash'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordCash() async {
    // TODO: form -> invoke vibespace-cash-payment
  }
}

// Placeholder provider symbol references (replace with your app providers)
final paymentsProvider = StateNotifierProvider<_PaymentsNotifier, List<Map<String, dynamic>>>(
  (ref) => _PaymentsNotifier(),
);

class _PaymentsNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  _PaymentsNotifier() : super(const []);

  void addPayment(Map<String, dynamic> payment) {
    state = [payment, ...state];
  }

  void trimToLast(int n) {
    if (state.length <= n) return;
    state = state.take(n).toList(growable: false);
  }
}
