import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/features/rides/data/ride_service.dart';
import 'package:taxi_app/shared/models/ride.dart';

class DriverHistoryScreen extends ConsumerWidget {
  final String driverId;
  final String driverName;

  const DriverHistoryScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(driverHistoryProvider(driverId));

    return Scaffold(
      appBar: AppBar(title: Text('Historial · $driverName')),
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
                  Text('Sin carreras registradas'),
                ],
              ),
            );
          }

          final completed =
              rides.where((r) => r.status == RideStatus.completed).length;
          final cancelled =
              rides.where((r) => r.status == RideStatus.cancelled).length;

          return Column(
            children: [
              _StatsBar(
                total: rides.length,
                completed: completed,
                cancelled: cancelled,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _RideCard(ride: rides[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final int total;
  final int completed;
  final int cancelled;

  const _StatsBar({
    required this.total,
    required this.completed,
    required this.cancelled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
              label: 'Total', value: '$total', color: AppTheme.primary),
          _StatItem(
              label: 'Completadas',
              value: '$completed',
              color: AppTheme.success),
          _StatItem(
              label: 'Canceladas',
              value: '$cancelled',
              color: AppTheme.danger),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _RideCard extends StatelessWidget {
  final Ride ride;
  const _RideCard({required this.ride});

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
                  isCancelled
                      ? Icons.cancel_outlined
                      : Icons.check_circle_outline,
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
            Text(
              '${ride.originZone ?? ride.origin} → ${ride.destZone ?? ride.destination}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            if (ride.price != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.attach_money,
                      size: 14, color: AppTheme.primary),
                  Text(
                    '\$${ride.price!.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  if (ride.paymentType != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      ride.paymentType == PaymentType.cash
                          ? Icons.payments_outlined
                          : Icons.account_balance_outlined,
                      size: 13,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      ride.paymentType == PaymentType.cash
                          ? 'Efectivo'
                          : 'Transferencia',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
