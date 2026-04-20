import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/features/auth/data/auth_provider.dart';
import 'package:taxi_app/features/drivers/data/driver_service.dart';
import 'package:taxi_app/features/rides/data/ride_service.dart';
import 'package:taxi_app/shared/models/app_user.dart';
import 'package:taxi_app/shared/models/ride.dart';

// Provider que obtiene el viaje específico para saber su zona de origen
final _rideProvider = StreamProvider.family<Ride?, String>((ref, rideId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('rides')
      .doc(rideId)
      .snapshots()
      .map((doc) => doc.exists ? Ride.fromFirestore(doc) : null);
});

class AssignDriverScreen extends ConsumerWidget {
  final String rideId;
  const AssignDriverScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(availableDriversProvider);
    final rideAsync = ref.watch(_rideProvider(rideId));
    final originZone = rideAsync.valueOrNull?.originZone;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignar conductor'),
        bottom: originZone != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: Container(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location,
                          size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text('Zona de recogida: $originZone',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
                      const Spacer(),
                      const Text('↑ Cercanos primero',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: driversAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (drivers) {
          if (drivers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No hay conductores disponibles en este momento'),
                ],
              ),
            );
          }

          // Ordenar: primero los de la misma zona, luego el resto
          final sorted = [...drivers]..sort((a, b) {
              final aMatch = a.currentZone == originZone && originZone != null;
              final bMatch = b.currentZone == originZone && originZone != null;
              if (aMatch && !bMatch) return -1;
              if (!aMatch && bMatch) return 1;
              return 0;
            });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: 8),
            itemBuilder: (context, i) => _DriverTile(
              driver: sorted[i],
              rideId: rideId,
              originZone: originZone,
            ),
          );
        },
      ),
    );
  }
}

class _DriverTile extends ConsumerStatefulWidget {
  final AppUser driver;
  final String rideId;
  final String? originZone;
  const _DriverTile(
      {required this.driver,
      required this.rideId,
      required this.originZone});

  @override
  ConsumerState<_DriverTile> createState() => _DriverTileState();
}

class _DriverTileState extends ConsumerState<_DriverTile> {
  bool _loading = false;

  Future<void> _assign() async {
    setState(() => _loading = true);
    try {
      await ref.read(rideServiceProvider).assignDriver(
          widget.rideId, widget.driver.uid, widget.driver.name,
          driverPlate: widget.driver.vehiclePlate);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    final sameZone = widget.originZone != null &&
        driver.currentZone == widget.originZone;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: sameZone
            ? const BorderSide(color: AppTheme.success, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Foto o avatar
            driver.vehiclePhotoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(driver.vehiclePhotoUrl!,
                        width: 48, height: 48, fit: BoxFit.cover),
                  )
                : CircleAvatar(
                    backgroundColor:
                        AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      driver.name.isNotEmpty
                          ? driver.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
            const SizedBox(width: 12),
            // Nombre y zona
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 13,
                          color: sameZone
                              ? AppTheme.success
                              : Colors.grey),
                      const SizedBox(width: 3),
                      Text(
                        driver.currentZone ?? 'Zona no disponible',
                        style: TextStyle(
                            fontSize: 12,
                            color: sameZone
                                ? AppTheme.success
                                : Colors.grey,
                            fontWeight: sameZone
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                      if (sameZone) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Zona cercana',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Botón asignar
            _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : SizedBox(
                    width: 90,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _assign,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        backgroundColor: sameZone
                            ? AppTheme.success
                            : AppTheme.primary,
                      ),
                      child: const Text('Asignar'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
