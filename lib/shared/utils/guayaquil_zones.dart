import 'dart:math';

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

class GuayaquilZone {
  final String id;
  final String name;
  final LatLng center;
  final double radiusKm;

  const GuayaquilZone({
    required this.id,
    required this.name,
    required this.center,
    required this.radiusKm,
  });
}

class GuayaquilZones {
  static const List<GuayaquilZone> zones = [
    GuayaquilZone(
      id: 'centro',
      name: 'Centro',
      center: LatLng(-2.1900, -79.8892),
      radiusKm: 2.5,
    ),
    GuayaquilZone(
      id: 'norte',
      name: 'Norte',
      center: LatLng(-2.1400, -79.9000),
      radiusKm: 4.0,
    ),
    GuayaquilZone(
      id: 'urdesa_oeste',
      name: 'Urdesa / Oeste',
      center: LatLng(-2.1650, -79.9100),
      radiusKm: 2.5,
    ),
    GuayaquilZone(
      id: 'sur',
      name: 'Sur',
      center: LatLng(-2.2400, -79.8800),
      radiusKm: 4.0,
    ),
    GuayaquilZone(
      id: 'aeropuerto',
      name: 'Aeropuerto',
      center: LatLng(-2.1574, -79.8836),
      radiusKm: 2.0,
    ),
    GuayaquilZone(
      id: 'samborondon',
      name: 'Samborondón',
      center: LatLng(-2.1400, -79.8600),
      radiusKm: 4.0,
    ),
    GuayaquilZone(
      id: 'via_costa',
      name: 'Vía a la Costa',
      center: LatLng(-2.1800, -80.0500),
      radiusKm: 8.0,
    ),
    GuayaquilZone(
      id: 'duran',
      name: 'Durán',
      center: LatLng(-2.1700, -79.8300),
      radiusKm: 4.0,
    ),
    GuayaquilZone(
      id: 'noroeste',
      name: 'Noroeste',
      center: LatLng(-2.1000, -79.9300),
      radiusKm: 5.0,
    ),
  ];

  // Devuelve el nombre de la zona que contiene las coordenadas dadas.
  // Cuando hay solapamiento, gana la zona con centro más cercano.
  static String? detectZone(double lat, double lng) {
    GuayaquilZone? closest;
    double closestDistance = double.infinity;

    for (final zone in zones) {
      final distance = _haversineKm(lat, lng, zone.center.lat, zone.center.lng);
      if (distance <= zone.radiusKm && distance < closestDistance) {
        closest = zone;
        closestDistance = distance;
      }
    }

    return closest?.name;
  }

  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;
}
