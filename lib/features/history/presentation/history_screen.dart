import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/features/rides/data/ride_service.dart';
import 'package:taxi_app/shared/models/ride.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(rideHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rides) {
          if (rides.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No hay viajes completados aún'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _HistoryCard(ride: rides[i]),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Ride ride;
  const _HistoryCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'es');
    final isCancelled = ride.status == RideStatus.cancelled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCancelled ? Icons.cancel_outlined : Icons.check_circle,
                  color: isCancelled ? AppTheme.danger : AppTheme.success,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(ride.clientName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(fmt.format(ride.createdAt),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 6),
            Text('${ride.origin} → ${ride.destination}',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            if (ride.driverName != null)
              Text('Conductor: ${ride.driverName}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
            if (ride.paymentType != null)
              Row(
                children: [
                  Icon(
                    ride.paymentType == PaymentType.cash
                        ? Icons.payments_outlined
                        : Icons.account_balance_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ride.paymentType == PaymentType.cash
                        ? 'Efectivo'
                        : 'Transferencia',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
