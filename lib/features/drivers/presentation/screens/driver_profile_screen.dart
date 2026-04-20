import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/features/auth/data/auth_provider.dart';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() =>
      _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  bool _uploading = false;

  Future<void> _pickAndUploadPhoto() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final file = File(picked.path);
      final ref_ = FirebaseStorage.instance
          .ref()
          .child('vehicle_photos/${user.uid}.jpg');
      await ref_.putFile(file);
      final url = await ref_.getDownloadURL();

      await ref.read(firestoreProvider).collection('users').doc(user.uid).update({
        'vehiclePhotoUrl': url,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto actualizada correctamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al subir foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      backgroundImage: user.vehiclePhotoUrl != null
                          ? NetworkImage(user.vehiclePhotoUrl!)
                          : null,
                      child: user.vehiclePhotoUrl == null
                          ? const Icon(Icons.directions_car,
                              size: 60, color: AppTheme.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _uploading ? null : _pickAndUploadPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                          child: _uploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black))
                              : const Icon(Icons.camera_alt,
                                  size: 18, color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('Toca el ícono para actualizar foto de tu unidad',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ),
              const SizedBox(height: 32),
              _InfoTile(label: 'Nombre', value: user.name),
              _InfoTile(label: 'Correo', value: user.email),
              if (user.vehiclePlate != null)
                _InfoTile(label: 'Placa', value: user.vehiclePlate!),
              if (user.currentZone != null)
                _InfoTile(label: 'Zona actual', value: user.currentZone!),
            ],
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
