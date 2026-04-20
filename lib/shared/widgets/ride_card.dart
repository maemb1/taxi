import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/features/rides/data/ride_service.dart';
import 'package:taxi_app/shared/models/ride.dart';

class ActiveRideCard extends ConsumerWidget {
  final Ride ride;
  final String driverId;
  const ActiveRideCard({super.key, required this.ride, required this.driverId});

  Future<void> _openRoute(Ride ride) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cliente
            Row(
              children: [
                const Icon(Icons.person, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(ride.clientName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Text(ride.clientPhone,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const Divider(height: 20),

            // Zonas origen → destino
            Row(
              children: [
                const Icon(Icons.my_location, size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    ride.originZone ?? '—',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                ),
                const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    ride.destZone ?? '—',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Ver ruta
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openRoute(ride),
                icon: const Icon(Icons.route, size: 16),
                label: const Text('Abrir ruta en Maps'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

            if (ride.notes != null && ride.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.notes, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(ride.notes!,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey)),
                  ),
                ],
              ),
            ],

            // Precio
            if (ride.price != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.attach_money,
                      size: 16, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '\$${ride.price!.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            if (ride.status == RideStatus.assigned)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success),
                  onPressed: () =>
                      ref.read(rideServiceProvider).startRide(ride.id),
                  icon: const Icon(Icons.directions_car),
                  label: const Text('Iniciar viaje'),
                ),
              ),
            if (ride.status == RideStatus.inProgress)
              _CompleteRideButton(ride: ride, driverId: driverId),
          ],
        ),
      ),
    );
  }
}

class _CompleteRideButton extends ConsumerWidget {
  final Ride ride;
  final String driverId;
  const _CompleteRideButton({required this.ride, required this.driverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black87),
        onPressed: () => _showPaymentDialog(context, ref),
        icon: const Icon(Icons.check_circle),
        label: const Text('Completar viaje'),
      ),
    );
  }

  Future<void> _showPaymentDialog(BuildContext context, WidgetRef ref) async {
    final payment = await showDialog<PaymentType>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tipo de pago'),
        content: const Text('¿Cómo pagó el cliente?'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, PaymentType.cash),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Efectivo'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, PaymentType.transfer),
            icon: const Icon(Icons.account_balance_outlined),
            label: const Text('Transferencia'),
          ),
        ],
      ),
    );
    if (payment != null) {
      await ref
          .read(rideServiceProvider)
          .completeRide(ride.id, driverId, payment);
    }
  }
}

