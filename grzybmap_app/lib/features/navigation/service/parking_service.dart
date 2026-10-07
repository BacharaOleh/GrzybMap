import 'dart:math';

class ParkingNavigation {
  final double distanceMeters;
  final int bearingDegrees;
  final String humanDistance;
  final int walkMinutes;

  const ParkingNavigation({
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.humanDistance,
    required this.walkMinutes,
  });
}

class ParkingService {
  double? _carLat;
  double? _carLng;

  bool get hasCarLocation => _carLat != null && _carLng != null;
  double? get carLat => _carLat;
  double? get carLng => _carLng;

  void saveCarLocation(double lat, double lng) {
    _carLat = lat;
    _carLng = lng;
  }

  void clearCar() {
    _carLat = null;
    _carLng = null;
  }

  ParkingNavigation? calculateNavigationToCar(double currentLat, double currentLng) {
    if (!hasCarLocation) return null;

    final lat1 = currentLat * pi / 180.0;
    final lat2 = _carLat! * pi / 180.0;
    final dLat = (_carLat! - currentLat) * pi / 180.0;
    final dLng = (_carLng! - currentLng) * pi / 180.0;

    // Haversine formula
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = 6371000.0 * c; // Earth radius in meters

    // Bearing formula
    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
    var bearing = atan2(y, x) * 180.0 / pi;
    bearing = (bearing + 360.0) % 360.0;

    final distMeters = distance.roundToDouble();
    final humanDist = distMeters > 1000
        ? '${(distMeters / 1000).toStringAsFixed(2)} km'
        : '${distMeters.toInt()} m';
    final walkMins = (distMeters / 75).round(); // ~4.5 km/h walking speed

    return ParkingNavigation(
      distanceMeters: distMeters,
      bearingDegrees: bearing.round(),
      humanDistance: humanDist,
      walkMinutes: walkMins,
    );
  }
}
