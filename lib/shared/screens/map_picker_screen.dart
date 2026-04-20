import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/shared/utils/guayaquil_zones.dart';

class MapPickResult {
  final double lat;
  final double lng;
  final String address;
  final String? zone;
  const MapPickResult({
    required this.lat,
    required this.lng,
    required this.address,
    this.zone,
  });
}

class MapPickerScreen extends StatefulWidget {
  final String title;
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({
    super.key,
    required this.title,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late final MapController _mapController;
  Timer? _debounce;

  double _lat = -2.1900;
  double _lng = -79.8892;
  String _address = 'Mueve el mapa para seleccionar';
  bool _addressReady = false;
  bool _geocoding = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLat != null) {
      _lat = widget.initialLat!;
      _lng = widget.initialLng!;
    }
    // Geocodifica la posición inicial al abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _address = 'Buscando dirección...';
        _geocoding = true;
      });
      _geocode();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
      final center = _mapController.camera.center;
      _lat = center.latitude;
      _lng = center.longitude;
      setState(() {
        _addressReady = false;
        _geocoding = true;
        _address = 'Buscando dirección...';
      });
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 700), _geocode);
    }
  }

  Future<void> _geocode() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$_lat&lon=$_lng&format=json',
      ));
      req.headers.set('Accept-Language', 'es');
      req.headers.set('User-Agent', 'CoopTaxi/1.0 (taxi_app)');
      final response = await req.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>? ?? {};

      final parts = <String>[
        if (addr['road'] != null || addr['pedestrian'] != null || addr['footway'] != null)
          (addr['road'] ?? addr['pedestrian'] ?? addr['footway']) as String,
        if (addr['house_number'] != null) addr['house_number'] as String,
        if (addr['suburb'] != null || addr['neighbourhood'] != null ||
            addr['city_district'] != null)
          (addr['suburb'] ?? addr['neighbourhood'] ?? addr['city_district']) as String,
      ];

      String resolved;
      if (parts.isNotEmpty) {
        resolved = parts.join(', ');
      } else {
        final display = data['display_name'] as String?;
        resolved = display?.split(',').take(3).join(',').trim() ??
            '${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}';
      }

      if (mounted) {
        setState(() {
          _address = resolved;
          _addressReady = true;
          _geocoding = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _address = '${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}';
          _addressReady = true;
          _geocoding = false;
        });
      }
    }
  }

  void _confirm() {
    final zone = GuayaquilZones.detectZone(_lat, _lng);
    Navigator.pop(
      context,
      MapPickResult(lat: _lat, lng: _lng, address: _address, zone: zone),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: ll.LatLng(_lat, _lng),
                    initialZoom: 15,
                    onMapEvent: _onMapEvent,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.taxiapp.taxi_app',
                    ),
                  ],
                ),
                // Pin fijo en el centro
                const IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on,
                            size: 44, color: AppTheme.primary),
                        SizedBox(
                          width: 8,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Barra inferior
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Dirección seleccionada:',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                if (_geocoding)
                  const LinearProgressIndicator()
                else
                  Text(
                    _address,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 2,
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addressReady ? _confirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Confirmar ubicación',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
