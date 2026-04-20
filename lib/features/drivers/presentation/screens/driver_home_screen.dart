import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/features/auth/data/auth_provider.dart';
import 'package:taxi_app/features/auth/data/auth_service.dart';
import 'package:taxi_app/features/drivers/data/driver_service.dart';
import 'package:taxi_app/features/rides/data/ride_service.dart';
import 'package:taxi_app/shared/models/app_user.dart';
import 'package:taxi_app/shared/widgets/ride_card.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return userAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        return _DriverHome(user: user);
      },
    );
  }
}

class _DriverHome extends ConsumerWidget {
  final AppUser user;
  const _DriverHome({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRideAsync = ref.watch(driverActiveRideProvider(user.uid));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Hola, ${user.name.split(' ').first}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/driver/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(user: user),
          const SizedBox(height: 20),
          activeRideAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
            data: (ride) => ride != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Viaje asignado',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ActiveRideCard(ride: ride, driverId: user.uid),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends ConsumerStatefulWidget {
  final AppUser user;
  const _StatusCard({required this.user});

  @override
  ConsumerState<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends ConsumerState<_StatusCard> {
  bool _loading = false;

  Future<void> _toggleStatus() async {
    setState(() => _loading = true);
    final service = ref.read(driverServiceProvider);
    final newStatus = widget.user.status == DriverStatus.available
        ? DriverStatus.offline
        : DriverStatus.available;

    if (newStatus == DriverStatus.available) {
      final granted = await service.requestLocationPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Permiso de ubicación necesario para mostrar tu zona')),
        );
      }
    }

    await service.updateStatus(widget.user.uid, newStatus);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = widget.user.status == DriverStatus.available;
    final isBusy = widget.user.status == DriverStatus.busy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAvailable
                        ? AppTheme.success
                        : isBusy
                            ? AppTheme.accent
                            : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isAvailable
                      ? 'Disponible'
                      : isBusy
                          ? 'En viaje'
                          : 'Fuera de servicio',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Zona actual — siempre visible cuando está disponible
            if (isAvailable) ...[
              _ZoneSelector(user: widget.user),
              const SizedBox(height: 12),
            ],
            if (!isBusy)
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isAvailable ? AppTheme.danger : AppTheme.success,
                        ),
                        onPressed: _toggleStatus,
                        child: Text(isAvailable
                            ? 'Ponerme fuera de servicio'
                            : 'Ponerme disponible'),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}

class _ZoneSelector extends StatelessWidget {
  final AppUser user;
  const _ZoneSelector({required this.user});

  @override
  Widget build(BuildContext context) {
    final zone = user.currentZone;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tu zona actual',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text(
                zone ?? 'Detectando...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: zone != null ? AppTheme.primary : Colors.grey,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (zone == null)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}
