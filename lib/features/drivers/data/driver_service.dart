import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:taxi_app/features/auth/data/auth_provider.dart';
import 'package:taxi_app/shared/models/app_user.dart';
import 'package:taxi_app/shared/utils/guayaquil_zones.dart';

class DriverService {
  final FirebaseFirestore _firestore;
  Timer? _zoneTimer;

  DriverService(this._firestore);

  Stream<List<AppUser>> watchDrivers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .snapshots()
        .map((snap) => snap.docs.map(AppUser.fromFirestore).toList()
          ..sort((a, b) => a.status.index.compareTo(b.status.index)));
  }

  Stream<List<AppUser>> watchAvailableDrivers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .snapshots()
        .map((snap) => snap.docs
            .map(AppUser.fromFirestore)
            .where((d) => d.status == DriverStatus.available)
            .toList());
  }

  Future<void> updateStatus(String uid, DriverStatus status) async {
    await _firestore.collection('users').doc(uid).update({
      'status': status.name,
    });

    if (status == DriverStatus.available) {
      _startZoneUpdates(uid);
    } else {
      _stopZoneUpdates();
      await _firestore.collection('users').doc(uid).update({
        'currentZone': null,
      });
    }
  }

  void _startZoneUpdates(String uid) {
    _stopZoneUpdates();
    _updateZone(uid);
    _zoneTimer = Timer.periodic(const Duration(minutes: 7), (_) {
      _updateZone(uid);
    });
  }

  void _stopZoneUpdates() {
    _zoneTimer?.cancel();
    _zoneTimer = null;
  }

  Future<void> _updateZone(String uid) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // ignore: avoid_print
        print('[ZoneService] Permiso denegado: $permission');
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // ignore: avoid_print
        print('[ZoneService] Servicio de ubicación desactivado');
        return;
      }

      // Intenta última posición conocida (funciona con coords simuladas en emulador)
      Position? pos = await Geolocator.getLastKnownPosition();

      // Si no hay última posición, solicita con stream y toma el primer valor
      pos ??= await Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).first.timeout(const Duration(seconds: 10));

      // ignore: avoid_print
      print('[ZoneService] Posición: ${pos.latitude}, ${pos.longitude}');

      final zone = GuayaquilZones.detectZone(pos.latitude, pos.longitude);

      // ignore: avoid_print
      print('[ZoneService] Zona detectada: $zone');

      await _firestore.collection('users').doc(uid).update({
        'currentZone': zone ?? 'Fuera de zona',
        'lastZoneUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('[ZoneService] Error: $e');
    }
  }

  Future<bool> requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void dispose() => _stopZoneUpdates();
}

final driverServiceProvider = Provider<DriverService>((ref) {
  final service = DriverService(ref.watch(firestoreProvider));
  ref.onDispose(service.dispose);
  return service;
});

final allDriversProvider = StreamProvider<List<AppUser>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(driverServiceProvider).watchDrivers();
});

final availableDriversProvider = StreamProvider<List<AppUser>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(driverServiceProvider).watchAvailableDrivers();
});
