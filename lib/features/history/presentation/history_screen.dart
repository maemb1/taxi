import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/features/drivers/data/driver_service.dart';
import 'package:taxi_app/features/rides/data/ride_service.dart';
import 'package:taxi_app/shared/models/app_user.dart';
import 'package:taxi_app/shared/models/ride.dart';

enum _DateFilter { today, week, month, all }

enum _StatusFilter { all, completed, cancelled }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _DateFilter _dateFilter = _DateFilter.all;
  _StatusFilter _statusFilter = _StatusFilter.all;
  String? _selectedDriverId;

  List<Ride> _applyFilters(List<Ride> rides, List<AppUser> drivers) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    return rides.where((r) {
      if (_dateFilter == _DateFilter.today &&
          r.createdAt.isBefore(todayStart)) return false;
      if (_dateFilter == _DateFilter.week &&
          r.createdAt.isBefore(weekStart)) return false;
      if (_dateFilter == _DateFilter.month &&
          r.createdAt.isBefore(monthStart)) return false;

      if (_statusFilter == _StatusFilter.completed &&
          r.status != RideStatus.completed) return false;
      if (_statusFilter == _StatusFilter.cancelled &&
          r.status != RideStatus.cancelled) return false;

      if (_selectedDriverId != null && r.driverId != _selectedDriverId) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(rideHistoryProvider);
    final driversAsync = ref.watch(allDriversProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: Column(
        children: [
          _FilterBar(
            dateFilter: _dateFilter,
            statusFilter: _statusFilter,
            selectedDriverId: _selectedDriverId,
            drivers: driversAsync.valueOrNull ?? [],
            onDateChanged: (f) => setState(() => _dateFilter = f),
            onStatusChanged: (f) => setState(() => _statusFilter = f),
            onDriverChanged: (id) => setState(() => _selectedDriverId = id),
          ),
          Expanded(
            child: historyAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (all) {
                final rides = _applyFilters(
                    all, driversAsync.valueOrNull ?? []);

                if (rides.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('Sin resultados',
                            style:
                                TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rides.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) => _HistoryCard(ride: rides[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _DateFilter dateFilter;
  final _StatusFilter statusFilter;
  final String? selectedDriverId;
  final List<AppUser> drivers;
  final ValueChanged<_DateFilter> onDateChanged;
  final ValueChanged<_StatusFilter> onStatusChanged;
  final ValueChanged<String?> onDriverChanged;

  const _FilterBar({
    required this.dateFilter,
    required this.statusFilter,
    required this.selectedDriverId,
    required this.drivers,
    required this.onDateChanged,
    required this.onStatusChanged,
    required this.onDriverChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Hoy', dateFilter == _DateFilter.today,
                    () => onDateChanged(_DateFilter.today)),
                _chip('Semana', dateFilter == _DateFilter.week,
                    () => onDateChanged(_DateFilter.week)),
                _chip('Mes', dateFilter == _DateFilter.month,
                    () => onDateChanged(_DateFilter.month)),
                _chip('Todo', dateFilter == _DateFilter.all,
                    () => onDateChanged(_DateFilter.all)),
                const SizedBox(width: 12),
                const VerticalDivider(width: 1, thickness: 1),
                const SizedBox(width: 12),
                _chip('Completadas', statusFilter == _StatusFilter.completed,
                    () => onStatusChanged(_StatusFilter.completed),
                    color: AppTheme.success),
                _chip('Canceladas', statusFilter == _StatusFilter.cancelled,
                    () => onStatusChanged(_StatusFilter.cancelled),
                    color: AppTheme.danger),
                _chip('Todos', statusFilter == _StatusFilter.all,
                    () => onStatusChanged(_StatusFilter.all)),
              ],
            ),
          ),
          if (drivers.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: DropdownButtonFormField<String?>(
                initialValue: selectedDriverId,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  prefixIcon:
                      const Icon(Icons.person_outline, size: 18),
                ),
                hint: const Text('Todos los conductores',
                    style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todos los conductores',
                        style: TextStyle(fontSize: 13)),
                  ),
                  ...drivers.map((d) => DropdownMenuItem<String?>(
                        value: d.uid,
                        child: Text(d.name,
                            style: const TextStyle(fontSize: 13)),
                      )),
                ],
                onChanged: onDriverChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap,
      {Color? color}) {
    final activeColor = color ?? AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.15)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? activeColor
                  : Colors.grey.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? activeColor : Colors.grey.shade600,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
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
                  isCancelled
                      ? Icons.cancel_outlined
                      : Icons.check_circle,
                  color: isCancelled ? AppTheme.danger : AppTheme.success,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(ride.clientName,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(fmt.format(ride.createdAt),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${ride.originZone ?? ride.origin} → ${ride.destZone ?? ride.destination}',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            if (ride.driverName != null)
              Text('Conductor: ${ride.driverName}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.primary)),
            if (ride.price != null)
              Row(
                children: [
                  const Icon(Icons.attach_money,
                      size: 14, color: AppTheme.primary),
                  Text('\$${ride.price!.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600)),
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
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
