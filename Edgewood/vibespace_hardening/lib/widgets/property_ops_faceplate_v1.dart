import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PropertyOpsFaceplate extends ConsumerStatefulWidget {
  const PropertyOpsFaceplate({super.key});

  @override
  ConsumerState<PropertyOpsFaceplate> createState() => _PropertyOpsFaceplateState();
}

class _PropertyOpsFaceplateState extends ConsumerState<PropertyOpsFaceplate> {
  RealtimeChannel? _channel;
  RealtimeChannel? _maintenanceChannel;

  @override
  void initState() {
    super.initState();

    final tenantId = ref.read(tenantProvider).current!.id;
    final businessId = ref.read(businessProvider).id;
    final paymentsChannel = 'property-ops:payments:$tenantId:$businessId';
    final maintenanceChannel = 'property-ops:maintenance:$tenantId:$businessId';

    final supabase = Supabase.instance.client;
    _channel = supabase.channel(paymentsChannel)
      ..on('broadcast', ChannelFilter(event: 'ledger_append'), (payload, ref) {
        ref.read(paymentsProvider.notifier).refreshLedger();
      })
      ..subscribe();

    _maintenanceChannel = supabase.channel(maintenanceChannel)
      ..on('broadcast', ChannelFilter(event: 'maintenance_new'), (payload, ref) {
        ref.read(maintenanceProvider.notifier).refreshList();
      })
      ..subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    if (_maintenanceChannel != null) {
      Supabase.instance.client.removeChannel(_maintenanceChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(paymentsProvider).take(100).toList(growable: false);
    final balance = payments.fold<double>(
      0,
      (sum, p) => sum + ((p.amount as num?)?.toDouble() ?? 0),
    );

    return Card(
      child: Column(
        children: [
          Text('Balance (last 100): \$${balance.toStringAsFixed(2)}'),
          Expanded(
            child: ListView.builder(
              itemCount: payments.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text('\$${payments[i].amount}'),
                subtitle: Text('Method: ${payments[i].method}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Replace these with your app’s real providers/models.
final tenantProvider = Provider<dynamic>((ref) => throw UnimplementedError());
final businessProvider = Provider<dynamic>((ref) => throw UnimplementedError());
final paymentsProvider = StateNotifierProvider<dynamic, List<dynamic>>((ref) => throw UnimplementedError());
final maintenanceProvider = StateNotifierProvider<dynamic, List<dynamic>>((ref) => throw UnimplementedError());
