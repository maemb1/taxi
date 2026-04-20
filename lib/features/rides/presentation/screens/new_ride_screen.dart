import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/features/rides/data/ride_service.dart';
import 'package:taxi_app/shared/screens/map_picker_screen.dart';

class NewRideScreen extends ConsumerStatefulWidget {
  const NewRideScreen({super.key});

  @override
  ConsumerState<NewRideScreen> createState() => _NewRideScreenState();
}

class _NewRideScreenState extends ConsumerState<NewRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  MapPickResult? _origin;
  MapPickResult? _destination;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocation(bool isOrigin) async {
    final prev = isOrigin ? _origin : _destination;
    final result = await Navigator.push<MapPickResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: isOrigin ? 'Punto de recogida' : 'Destino',
          initialLat: prev?.lat,
          initialLng: prev?.lng,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        if (isOrigin) { _origin = result; } else { _destination = result; }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_origin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el punto de recogida')));
      return;
    }
    if (_destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el destino')));
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(rideServiceProvider).createRide(
        clientName: _nameCtrl.text.trim(),
        clientPhone: _phoneCtrl.text.trim(),
        origin: _origin!.address,
        originZone: _origin!.zone,
        originLat: _origin!.lat,
        originLng: _origin!.lng,
        destination: _destination!.address,
        destZone: _destination!.zone,
        destLat: _destination!.lat,
        destLng: _destination!.lng,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear solicitud: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionLabel('Datos del cliente'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del cliente',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Trayecto'),
            const SizedBox(height: 12),
            _LocationPickButton(
              icon: Icons.my_location,
              label: 'Punto de recogida',
              result: _origin,
              onTap: () => _pickLocation(true),
            ),
            const SizedBox(height: 12),
            _LocationPickButton(
              icon: Icons.location_on,
              iconColor: Colors.redAccent,
              label: 'Destino',
              result: _destination,
              onTap: () => _pickLocation(false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check),
                    label: const Text('Crear solicitud'),
                  ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LocationPickButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final MapPickResult? result;
  final VoidCallback onTap;

  const _LocationPickButton({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final picked = result != null;
    final color = iconColor ?? AppTheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: picked
              ? color.withValues(alpha: 0.05)
              : Colors.grey.shade50,
          border: Border.all(
            color: picked ? color : Colors.grey.shade300,
            width: picked ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: picked ? color : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: picked ? color : Colors.grey,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    picked
                        ? result!.address
                        : 'Toca para seleccionar en el mapa',
                    style: TextStyle(
                      fontSize: 14,
                      color: picked ? Colors.black87 : Colors.grey.shade500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result?.zone != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '🗺️ ${result!.zone}',
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              picked ? Icons.edit_location_alt : Icons.map_outlined,
              color: picked ? color : Colors.grey.shade400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.grey.shade500,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
