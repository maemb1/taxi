import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/features/auth/data/auth_provider.dart';
import 'package:taxi_app/features/drivers/data/driver_service.dart';
import 'package:taxi_app/shared/models/app_user.dart';

class AdminDriversScreen extends ConsumerWidget {
  const AdminDriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(allDriversProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de conductores')),
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
                  Text('No hay conductores registrados'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: drivers.length,
            separatorBuilder: (context, i) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _DriverCard(driver: drivers[i]),
          );
        },
      ),
    );
  }
}

class _DriverCard extends ConsumerStatefulWidget {
  final AppUser driver;
  const _DriverCard({required this.driver});

  @override
  ConsumerState<_DriverCard> createState() => _DriverCardState();
}

class _DriverCardState extends ConsumerState<_DriverCard> {
  bool _uploadingPhoto = false;

  Color get _statusColor => switch (widget.driver.status) {
        DriverStatus.available => AppTheme.success,
        DriverStatus.busy => Colors.orange,
        DriverStatus.offline => Colors.grey,
      };

  String get _statusLabel => switch (widget.driver.status) {
        DriverStatus.available => 'Disponible',
        DriverStatus.busy => 'Ocupado',
        DriverStatus.offline => 'Desconectado',
      };

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75, maxWidth: 900);
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final file = File(picked.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('vehicle_photos/${widget.driver.uid}.jpg');
      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(widget.driver.uid)
          .update({'vehiclePhotoUrl': url});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto actualizada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditDriverSheet(driver: widget.driver),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Foto con botón de cambio
            GestureDetector(
              onTap: _uploadingPhoto ? null : _pickPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    backgroundImage: driver.vehiclePhotoUrl != null
                        ? CachedNetworkImageProvider(driver.vehiclePhotoUrl!)
                        : null,
                    child: driver.vehiclePhotoUrl == null
                        ? const Icon(Icons.directions_car,
                            size: 32, color: AppTheme.primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: _uploadingPhoto
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.camera_alt,
                              size: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: _statusColor),
                      const SizedBox(width: 5),
                      Text(_statusLabel,
                          style: TextStyle(
                              fontSize: 12,
                              color: _statusColor,
                              fontWeight: FontWeight.w500)),
                      if (driver.currentZone != null) ...[
                        const Text('  ·  ',
                            style: TextStyle(color: Colors.grey)),
                        Text(driver.currentZone!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ],
                  ),
                  if (driver.vehiclePlate != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.credit_card,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(driver.vehiclePlate!,
                            style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Editar
            IconButton(
              onPressed: _openEditSheet,
              icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
              tooltip: 'Editar datos',
            ),
          ],
        ),
      ),
    );
  }
}

class _EditDriverSheet extends ConsumerStatefulWidget {
  final AppUser driver;
  const _EditDriverSheet({required this.driver});

  @override
  ConsumerState<_EditDriverSheet> createState() => _EditDriverSheetState();
}

class _EditDriverSheetState extends ConsumerState<_EditDriverSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _plateCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.driver.name);
    _plateCtrl = TextEditingController(text: widget.driver.vehiclePlate ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final plate = _plateCtrl.text.trim().toUpperCase();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(widget.driver.uid)
          .update({
        'name': name,
        'vehiclePlate': plate.isEmpty ? null : plate,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos actualizados')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Editar conductor',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nombre',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _plateCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Placa',
              prefixIcon: const Icon(Icons.credit_card),
              hintText: 'Ej: ABC-1234',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar cambios'),
            ),
          ),
        ],
      ),
    );
  }
}
