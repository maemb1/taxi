import 'package:cloud_firestore/cloud_firestore.dart';

enum RideStatus { pending, assigned, inProgress, completed, cancelled }

enum PaymentType { cash, transfer }

class Ride {
  final String id;
  final String clientName;
  final String clientPhone;
  final String origin;
  final String? originZone;
  final String destination;
  final String? destZone;
  final String? notes;
  final String? driverId;
  final String? driverName;
  final String? driverPlate;
  final RideStatus status;
  final double? price;
  final PaymentType? paymentType;
  final DateTime createdAt;
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;
  final DateTime? assignedAt;
  final DateTime? completedAt;

  const Ride({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    required this.origin,
    this.originZone,
    required this.destination,
    this.destZone,
    this.notes,
    this.driverId,
    this.driverName,
    this.driverPlate,
    this.status = RideStatus.pending,
    this.price,
    this.paymentType,
    required this.createdAt,
    this.assignedAt,
    this.completedAt,
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
  });

  bool get isPending => status == RideStatus.pending;
  bool get isActive =>
      status == RideStatus.assigned || status == RideStatus.inProgress;

  factory Ride.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Ride(
      id: doc.id,
      clientName: data['clientName'] ?? '',
      clientPhone: data['clientPhone'] ?? '',
      origin: data['origin'] ?? '',
      originZone: data['originZone'],
      destination: data['destination'] ?? '',
      destZone: data['destZone'],
      notes: data['notes'],
      driverId: data['driverId'],
      driverName: data['driverName'],
      driverPlate: data['driverPlate'],
      status: _parseStatus(data['status']),
      price: (data['price'] as num?)?.toDouble(),
      paymentType: _parsePayment(data['paymentType']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      originLat: (data['originLat'] as num?)?.toDouble(),
      originLng: (data['originLng'] as num?)?.toDouble(),
      destLat: (data['destLat'] as num?)?.toDouble(),
      destLng: (data['destLng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'clientName': clientName,
        'clientPhone': clientPhone,
        'origin': origin,
        'originZone': originZone,
        'destination': destination,
        'destZone': destZone,
        'notes': notes,
        'driverId': driverId,
        'driverName': driverName,
        'driverPlate': driverPlate,
        'status': status.name,
        'price': price,
        'paymentType': paymentType?.name,
        'originLat': originLat,
        'originLng': originLng,
        'destLat': destLat,
        'destLng': destLng,
        'createdAt': Timestamp.fromDate(createdAt),
        'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      };

  Ride copyWith({
    String? originZone,
    String? destZone,
    String? driverId,
    double? price,
    String? driverName,
    String? driverPlate,
    RideStatus? status,
    PaymentType? paymentType,
    DateTime? assignedAt,
    DateTime? completedAt,
  }) =>
      Ride(
        id: id,
        clientName: clientName,
        clientPhone: clientPhone,
        origin: origin,
        originZone: originZone ?? this.originZone,
        destination: destination,
        destZone: destZone ?? this.destZone,
        notes: notes,
        driverId: driverId ?? this.driverId,
        driverName: driverName ?? this.driverName,
        driverPlate: driverPlate ?? this.driverPlate,
        status: status ?? this.status,
        paymentType: paymentType ?? this.paymentType,
        createdAt: createdAt,
        assignedAt: assignedAt ?? this.assignedAt,
        completedAt: completedAt ?? this.completedAt,
      );

  static RideStatus _parseStatus(String? value) {
    switch (value) {
      case 'assigned':
        return RideStatus.assigned;
      case 'inProgress':
        return RideStatus.inProgress;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
        return RideStatus.cancelled;
      default:
        return RideStatus.pending;
    }
  }

  static PaymentType? _parsePayment(String? value) {
    switch (value) {
      case 'cash':
        return PaymentType.cash;
      case 'transfer':
        return PaymentType.transfer;
      default:
        return null;
    }
  }
}
