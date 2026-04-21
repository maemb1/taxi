import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxi_app/features/auth/data/auth_provider.dart';
import 'package:taxi_app/shared/models/app_user.dart';

class CoopSettings {
  final String name;
  final String phone;
  final String? address;

  const CoopSettings({
    required this.name,
    required this.phone,
    this.address,
  });

  factory CoopSettings.empty() =>
      const CoopSettings(name: '', phone: '');

  factory CoopSettings.fromMap(Map<String, dynamic> data) => CoopSettings(
        name: data['name'] ?? '',
        phone: data['phone'] ?? '',
        address: data['address'],
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'address': address,
      };
}

class SettingsService {
  final FirebaseFirestore _firestore;

  SettingsService(this._firestore);

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _firestore.collection('settings').doc('general');

  Stream<CoopSettings> watchSettings() {
    return _settingsDoc.snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return CoopSettings.empty();
      return CoopSettings.fromMap(doc.data()!);
    });
  }

  Future<void> updateSettings(CoopSettings settings) async {
    await _settingsDoc.set(settings.toMap(), SetOptions(merge: true));
  }

  Stream<List<AppUser>> watchAdmins() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .snapshots()
        .map((snap) => snap.docs.map(AppUser.fromFirestore).toList());
  }

  Future<void> changeUserRole(String uid, String newRole) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'role': newRole});
  }
}

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(firestoreProvider));
});

final coopSettingsProvider = StreamProvider<CoopSettings>((ref) {
  return ref.watch(settingsServiceProvider).watchSettings();
});

final adminUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(settingsServiceProvider).watchAdmins();
});
