import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, driver }

enum DriverStatus { available, busy, offline }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? vehiclePhotoUrl;
  final String? vehiclePlate;
  final String? fcmToken;
  final DriverStatus status;
  final String? currentZone;
  final DateTime? lastZoneUpdate;
  final bool isActive;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.vehiclePhotoUrl,
    this.vehiclePlate,
    this.fcmToken,
    this.status = DriverStatus.offline,
    this.currentZone,
    this.lastZoneUpdate,
    this.isActive = true,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isDriver => role == UserRole.driver;
  bool get isAvailable => status == DriverStatus.available;

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] == 'admin' ? UserRole.admin : UserRole.driver,
      vehiclePhotoUrl: data['vehiclePhotoUrl'],
      vehiclePlate: data['vehiclePlate'],
      fcmToken: data['fcmToken'],
      status: _parseStatus(data['status']),
      currentZone: data['currentZone'],
      lastZoneUpdate: (data['lastZoneUpdate'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'email': email,
        'role': role.name,
        'vehiclePhotoUrl': vehiclePhotoUrl,
        'vehiclePlate': vehiclePlate,
        'fcmToken': fcmToken,
        'status': status.name,
        'currentZone': currentZone,
        'lastZoneUpdate':
            lastZoneUpdate != null ? Timestamp.fromDate(lastZoneUpdate!) : null,
        'isActive': isActive,
      };

  AppUser copyWith({
    String? name,
    String? vehiclePhotoUrl,
    String? vehiclePlate,
    String? fcmToken,
    DriverStatus? status,
    String? currentZone,
    DateTime? lastZoneUpdate,
    bool? isActive,
  }) =>
      AppUser(
        uid: uid,
        name: name ?? this.name,
        email: email,
        role: role,
        vehiclePhotoUrl: vehiclePhotoUrl ?? this.vehiclePhotoUrl,
        vehiclePlate: vehiclePlate ?? this.vehiclePlate,
        fcmToken: fcmToken ?? this.fcmToken,
        status: status ?? this.status,
        currentZone: currentZone ?? this.currentZone,
        lastZoneUpdate: lastZoneUpdate ?? this.lastZoneUpdate,
        isActive: isActive ?? this.isActive,
      );

  static DriverStatus _parseStatus(String? value) {
    switch (value) {
      case 'available':
        return DriverStatus.available;
      case 'busy':
        return DriverStatus.busy;
      default:
        return DriverStatus.offline;
    }
  }
}
