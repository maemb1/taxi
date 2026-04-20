import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/features/auth/data/auth_service.dart';
import 'package:taxi_app/features/drivers/data/driver_service.dart';
import 'package:taxi_app/features/rides/data/ride_service.dart';
import 'package:taxi_app/shared/models/app_user.dart';
import 'package:taxi_app/shared/models/ride.dart';
import 'package:taxi_app/shared/widgets/driver_status_chip.dart';


class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(allDriversProvider);
    final ridesAsync = ref.watch(activeRidesProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Despacho'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            onPressed: () => context.push('/admin/drivers'),
            tooltip: 'Conductores',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/admin/history'),
            tooltip: 'Historial',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/new-ride'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva solicitud'),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black87,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allDriversProvider);
          ref.invalidate(activeRidesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle(
              title: 'Conductores',
              trailing: driversAsync.maybeWhen(
                data: (d) {
                  final available =
                      d.where((x) => x.status == DriverStatus.available).length;
                  return Text('$available disponibles',
                      style: const TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.bold));
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 8),
            driversAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Text('Error cargando conductores: $e'),
              data: (drivers) => drivers.isEmpty
                  ? const _EmptyState(message: 'No hay conductores registrados')
                  : _DriversGrid(drivers: drivers),
            ),
            const SizedBox(height: 24),
            const _SectionTitle(title: 'Viajes activos'),
            const SizedBox(height: 8),
            ridesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (rides) => rides.isEmpty
                  ? const _EmptyState(
                      message: 'Sin viajes activos',
                      icon: Icons.check_circle_outline)
                  : Column(
                      children: rides
                          .map((r) => _AdminRideCard(ride: r))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        ?trailing,
      ],
    );
  }
}

class _DriversGrid extends StatelessWidget {
  final List<AppUser> drivers;
  const _DriversGrid({required this.drivers});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: drivers.map((d) => DriverStatusChip(driver: d)).toList(),
    );
  }
}

class _AdminRideCard extends ConsumerStatefulWidget {
  final Ride ride;
  const _AdminRideCard({required this.ride});

  @override
  ConsumerState<_AdminRideCard> createState() => _AdminRideCardState();
}

class _AdminRideCardState extends ConsumerState<_AdminRideCard> {
  bool _editingPrice = false;
  final _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _openRoute() async {
    final ride = widget.ride;
    final Uri uri;

    if (ride.originLat != null && ride.destLat != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${ride.originLat},${ride.originLng}'
        '&destination=${ride.destLat},${ride.destLng}'
        '&travelmode=driving',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${Uri.encodeComponent(ride.origin)}'
        '&destination=${Uri.encodeComponent(ride.destination)}'
        '&travelmode=driving',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _savePrice() async {
    final val = double.tryParse(_priceCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) return;
    await ref.read(rideServiceProvider).setPrice(widget.ride.id, val);
    setState(() => _editingPrice = false);
  }

  Future<void> _shareWhatsApp(Ride ride) async {
    // Formatear número: 0991234567 → 593991234567
    final rawPhone = ride.clientPhone.replaceAll(RegExp(r'\D'), '');
    final intlPhone = rawPhone.startsWith('0')
        ? '593${rawPhone.substring(1)}'
        : '593$rawPhone';

    final price = ride.price != null
        ? '\$${ride.price!.toStringAsFixed(2)}'
        : 'por confirmar';
    final plate = ride.driverPlate ?? 'sin placa registrada';
    final zones = (ride.originZone != null || ride.destZone != null)
        ? '\n🗺️ Ruta: ${ride.originZone ?? '?'} → ${ride.destZone ?? '?'}'
        : '';

    final msg = Uri.encodeComponent(
      'Hola ${ride.clientName} 👋, tu taxi está en camino.\n\n'
      '🚕 Conductor: ${ride.driverName ?? '-'}\n'
      '🔖 Placa: $plate$zones\n'
      '💵 Valor: $price\n\n'
      'Por favor mantente disponible. ¡Gracias por usar CoopTaxi!',
    );

    final uri = Uri.parse('https://wa.me/$intlPhone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar viaje'),
        content: const Text('¿Estás seguro de cancelar este viaje?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar viaje'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(rideServiceProvider)
          .cancelRide(widget.ride.id, widget.ride.driverId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              children: [
                _StatusBadge(status: ride.status),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(ride.clientName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(ride.clientPhone,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Zonas origen → destino
            _ZoneArrow(
              originZone: ride.originZone,
              destZone: ride.destZone,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openRoute,
                icon: const Icon(Icons.route, size: 16),
                label: const Text('Ver ruta completa'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (ride.driverName != null) ...[
              const SizedBox(height: 6),
              _InfoRow(
                  icon: Icons.person,
                  text: ride.driverName!,
                  color: AppTheme.primary),
            ],
            if (ride.notes != null && ride.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              _InfoRow(
                  icon: Icons.notes, text: ride.notes!, color: Colors.grey),
            ],

            const Divider(height: 20),

            // Precio
            Row(
              children: [
                const Icon(Icons.attach_money,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                if (!_editingPrice) ...[
                  Text(
                    ride.price != null
                        ? '\$${ride.price!.toStringAsFixed(2)}'
                        : 'Sin precio asignado',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: ride.price != null
                          ? AppTheme.primary
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      _priceCtrl.text =
                          ride.price?.toStringAsFixed(2) ?? '';
                      setState(() => _editingPrice = true);
                    },
                    child: const Icon(Icons.edit, size: 16, color: Colors.grey),
                  ),
                ] else ...[
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (_) => _savePrice(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _savePrice,
                    child: const Icon(Icons.check_circle,
                        color: AppTheme.success, size: 24),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _editingPrice = false),
                    child: const Icon(Icons.cancel,
                        color: Colors.grey, size: 24),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Acciones
            if (ride.isPending) ...[
              if (ride.price == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text('Asigna un precio antes de continuar',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade700)),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: ride.price != null
                      ? () => context.push('/admin/assign/${ride.id}')
                      : null,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Asignar conductor'),
                ),
              ),
            ],
            if (ride.isActive) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _shareWhatsApp(ride),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Compartir info al cliente'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _confirmCancel,
                icon: const Icon(Icons.cancel_outlined,
                    color: AppTheme.danger, size: 18),
                label: const Text('Cancelar viaje',
                    style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ZoneArrow extends StatelessWidget {
  final String? originZone;
  final String? destZone;
  const _ZoneArrow({this.originZone, this.destZone});

  @override
  Widget build(BuildContext context) {
    final origin = originZone ?? '—';
    final dest = destZone ?? '—';
    return Row(
      children: [
        const Icon(Icons.my_location, size: 14, color: AppTheme.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(origin,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
        ),
        const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
        const SizedBox(width: 4),
        Flexible(
          child: Text(dest,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent)),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final RideStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      RideStatus.pending => ('Pendiente', Colors.orange),
      RideStatus.assigned => ('Asignado', AppTheme.primary),
      RideStatus.inProgress => ('En camino', AppTheme.success),
      _ => ('', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color ?? Colors.black87, fontSize: 13))),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyState(
      {required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(message,
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
