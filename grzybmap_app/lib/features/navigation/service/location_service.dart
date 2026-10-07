import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationResult {
  final LatLng position;
  final String sourceDescription; // e.g. 'GPS urządzenia', 'Sieć/IP (Warszawa)'

  const LocationResult({
    required this.position,
    required this.sourceDescription,
  });
}

/// Robust multi-tier location service:
/// 1. Tries hardware/browser GPS via Geolocator
/// 2. If unavailable on desktop PC/Windows, falls back seamlessly to IP geolocation (/api/geo or geojs)
class LocationService {
  final Dio _dio;

  LocationService([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
              ),
            );

  Future<LocationResult?> determineLocation() async {
    // Tier 1: Try device / browser GPS with low accuracy (fast & desktop compatible)
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 3),
        ),
      );
      return LocationResult(
        position: LatLng(pos.latitude, pos.longitude),
        sourceDescription: 'GPS urządzenia',
      );
    } catch (_) {
      // Device GPS unavailable or disabled (e.g. desktop PC without GPS) -> proceed to Tier 2
    }

    // Tier 2: Check last known position
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        return LocationResult(
          position: LatLng(lastPos.latitude, lastPos.longitude),
          sourceDescription: 'Ostatnia znana pozycja',
        );
      }
    } catch (_) {}

    // Tier 3: High-reliability IP-based geolocation fallback
    final geoEndpoints = [
      if (kIsWeb) '/api/geo',
      'https://get.geojs.io/v1/ip/geo.json',
      'https://ipapi.co/json/',
    ];

    for (final url in geoEndpoints) {
      try {
        final res = await _dio.get(url);
        final data = res.data is Map<String, dynamic>
            ? res.data as Map<String, dynamic>
            : null;
        if (data != null) {
          final latRaw = data['latitude'] ?? data['lat'];
          final lngRaw = data['longitude'] ?? data['lon'] ?? data['lng'];
          final city = data['city']?.toString() ?? 'Polska';

          if (latRaw != null && lngRaw != null) {
            final lat = double.tryParse(latRaw.toString());
            final lng = double.tryParse(lngRaw.toString());
            if (lat != null && lng != null) {
              return LocationResult(
                position: LatLng(lat, lng),
                sourceDescription: 'Lokalizacja sieciowa ($city)',
              );
            }
          }
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }
}
