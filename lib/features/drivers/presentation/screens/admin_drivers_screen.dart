import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/features/auth/data/auth_provider.dart';
import 'package:taxi_app/features/auth/data/auth_service.dart';
import 'package:taxi_app/features/drivers/data/driver_service.dart';
import 'package:taxi_app/shared/models/app_user.dart';

class AdminDriversScreen extends ConsumerWidget {
  const AdminDriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(allDriversProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Conductores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo conductor'),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black87,
      ),
      body: driversAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (drivers) {
          final active = drivers.where((d) => d.isActive).toList();
          final inactive = drivers.where((d) => !d.isActive).toList();

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

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              if (active.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Activos',
                  count: active.length,
                  color: AppTheme.success,
                ),
                const SizedBox(height: 8),
                ...active.map((d) => _DriverCard(driver: d)),
              ],
              if (inactive.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionHeader(
                  title: 'Desactivados',
                  count: inactive.length,
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                ...inactive.map((d) => _DriverCard(driver: d)),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateDriverSheet(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _SectionHeader(
      {required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ),
      ],
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

  Future<void> _toggleActive() async {
    final driver = widget.driver;
    final action = driver.isActive ? 'desactivar' : 'activar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${driver.isActive ? 'Desactivar' : 'Activar'} conductor'),
        content: Text(
            '¿Estás seguro de $action a ${driver.name}?${driver.isActive ? '\n\nNo podrá recibir carreras.' : ''}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  driver.isActive ? AppTheme.danger : AppTheme.success,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(driver.isActive ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref
            .read(driverServiceProvider)
            .setDriverActive(driver.uid, !driver.isActive);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    final isInactive = !driver.isActive;

    return Opacity(
      opacity: isInactive ? 0.55 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => context.push(
            '/admin/driver-history/${driver.uid}',
            extra: driver.name,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: isInactive || _uploadingPhoto ? null : _pickPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.1),
                        backgroundImage: driver.vehiclePhotoUrl != null
                            ? CachedNetworkImageProvider(
                                driver.vehiclePhotoUrl!)
                            : null,
                        child: driver.vehiclePhotoUrl == null
                            ? const Icon(Icons.directions_car,
                                size: 32, color: AppTheme.primary)
                            : null,
                      ),
                      if (!isInactive)
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
                                        strokeWidth: 2,
                                        color: Colors.black))
                                : const Icon(Icons.camera_alt,
                                    size: 12, color: Colors.black87),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 3),
                      if (isInactive)
                        const Text('Desactivado',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500))
                      else
                        Row(
                          children: [
                            Icon(Icons.circle,
                                size: 8, color: _statusColor),
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
                IconButton(
                  onPressed: _openEditSheet,
                  icon: const Icon(Icons.edit_outlined,
                      color: AppTheme.primary),
                  tooltip: 'Editar',
                ),
                IconButton(
                  onPressed: _toggleActive,
                  icon: Icon(
                    driver.isActive
                        ? Icons.person_off_outlined
                        : Icons.person_outlined,
                    color:
                        driver.isActive ? AppTheme.danger : AppTheme.success,
                  ),
                  tooltip: driver.isActive ? 'Desactivar' : 'Activar',
                ),
              ],
            ),
          ),
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
    _plateCtrl =
        TextEditingController(text: widget.driver.vehiclePlate ?? '');
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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

class _CreateDriverSheet extends ConsumerStatefulWidget {
  const _CreateDriverSheet();

  @override
  ConsumerState<_CreateDriverSheet> createState() => _CreateDriverSheetState();
}

class _CreateDriverSheetState extends ConsumerState<_CreateDriverSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;
  File? _pickedPhoto;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 900,
    );
    if (picked != null) setState(() => _pickedPhoto = File(picked.path));
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final plate = _plateCtrl.text.trim().toUpperCase();
    if (name.isEmpty || email.isEmpty || password.isEmpty || plate.isEmpty) {
      setState(() => _error = 'Todos los campos son obligatorios.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final uid = await ref.read(authServiceProvider).createUser(
            name: name,
            email: email,
            password: password,
            role: 'driver',
            vehiclePlate: plate,
          );

      if (_pickedPhoto != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('vehicle_photos/$uid.jpg');
        await storageRef.putFile(_pickedPhoto!);
        final url = await storageRef.getDownloadURL();
        await ref
            .read(firestoreProvider)
            .collection('users')
            .doc(uid)
            .update({'vehiclePhotoUrl': url});
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conductor creado exitosamente')));
      }
    } on Exception catch (e) {
      String msg = 'Error al crear conductor.';
      final str = e.toString();
      if (str.contains('email-already-in-use')) {
        msg = 'El email ya está registrado.';
      } else if (str.contains('invalid-email')) {
        msg = 'Email inválido.';
      } else if (str.contains('weak-password')) {
        msg = 'Contraseña muy débil (mínimo 6 caracteres).';
      }
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Nuevo conductor',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            // Foto opcional
            Center(
              child: GestureDetector(
                onTap: _saving ? null : _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      backgroundImage: _pickedPhoto != null
                          ? FileImage(_pickedPhoto!)
                          : null,
                      child: _pickedPhoto == null
                          ? const Icon(Icons.directions_car,
                              size: 40, color: AppTheme.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 14, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text('Foto del vehículo (opcional)',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nombre completo *',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Correo electrónico *',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Contraseña temporal *',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plateCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Placa *',
                prefixIcon: const Icon(Icons.credit_card),
                hintText: 'Ej: ABC-1234',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style:
                      const TextStyle(color: AppTheme.danger, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _create,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Crear conductor'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
