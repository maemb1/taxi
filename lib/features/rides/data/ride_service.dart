import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxi_app/features/auth/data/auth_provider.dart';
import 'package:taxi_app/shared/models/ride.dart';

class RideService {
  final FirebaseFirestore _firestore;

  RideService(this._firestore);

  CollectionReference<Map<String, dynamic>> get _rides =>
      _firestore.collection('rides');

  Future<String> createRide({
    required String clientName,
    required String clientPhone,
    required String origin,
    String? originZone,
    double? originLat,
    double? originLng,
    required String destination,
    String? destZone,
    double? destLat,
    double? destLng,
    String? notes,
  }) async {
    final doc = await _rides.add({
      'clientName': clientName,
      'clientPhone': clientPhone,
      'origin': origin,
      'originZone': originZone,
      'originLat': originLat,
      'originLng': originLng,
      'destination': destination,
      'destZone': destZone,
      'destLat': destLat,
      'destLng': destLng,
      'notes': notes,
      'status': RideStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> setPrice(String rideId, double price) async {
    await _rides.doc(rideId).update({'price': price});
  }

  Future<void> assignDriver(
      String rideId, String driverId, String driverName,
      {String? driverPlate}) async {
    final batch = _firestore.batch();

    batch.update(_rides.doc(rideId), {
      'driverId': driverId,
      'driverName': driverName,
      'driverPlate': driverPlate,
      'status': RideStatus.assigned.name,
      'assignedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_firestore.collection('users').doc(driverId), {
      'status': 'busy',
    });

    await batch.commit();
  }

  Future<void> startRide(String rideId) async {
    await _rides.doc(rideId).update({
      'status': RideStatus.inProgress.name,
    });
  }

  Future<void> completeRide(
      String rideId, String driverId, PaymentType paymentType) async {
    final batch = _firestore.batch();

    batch.update(_rides.doc(rideId), {
      'status': RideStatus.completed.name,
      'paymentType': paymentType.name,
      'completedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_firestore.collection('users').doc(driverId), {
      'status': 'available',
    });

    await batch.commit();
  }

  Future<void> cancelRide(String rideId, String? driverId) async {
    final batch = _firestore.batch();

    batch.update(_rides.doc(rideId), {
      'status': RideStatus.cancelled.name,
    });

    if (driverId != null) {
      batch.update(_firestore.collection('users').doc(driverId), {
        'status': 'available',
      });
    }

    await batch.commit();
  }

  Stream<List<Ride>> watchActiveRides() {
    return _rides
        .where('status', whereIn: ['pending', 'assigned', 'inProgress'])
        .snapshots()
        .map((snap) {
          final rides = snap.docs.map(Ride.fromFirestore).toList();
          rides.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return rides;
        });
  }

  Stream<Ride?> watchDriverActiveRide(String driverId) {
    return _rides
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['assigned', 'inProgress'])
        .snapshots()
        .map((snap) =>
            snap.docs.isEmpty ? null : Ride.fromFirestore(snap.docs.first));
  }

  Stream<List<Ride>> watchHistory() {
    return _rides
        .where('status', whereIn: ['completed', 'cancelled'])
        .limit(100)
        .snapshots()
        .map((snap) {
          final rides = snap.docs.map(Ride.fromFirestore).toList();
          rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rides;
        });
  }

  Stream<List<Ride>> watchRidesByDriver(String driverId) {
    return _rides
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['completed', 'cancelled'])
        .limit(50)
        .snapshots()
        .map((snap) {
          final rides = snap.docs.map(Ride.fromFirestore).toList();
          rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rides;
        });
  }
}

final rideServiceProvider = Provider<RideService>((ref) {
  return RideService(ref.watch(firestoreProvider));
});

final activeRidesProvider = StreamProvider<List<Ride>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(rideServiceProvider).watchActiveRides();
});

final driverActiveRideProvider =
    StreamProvider.family<Ride?, String>((ref, driverId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(rideServiceProvider).watchDriverActiveRide(driverId);
});

final rideHistoryProvider = StreamProvider<List<Ride>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(rideServiceProvider).watchHistory();
});

final driverHistoryProvider =
    StreamProvider.family<List<Ride>, String>((ref, driverId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(rideServiceProvider).watchRidesByDriver(driverId);
});
