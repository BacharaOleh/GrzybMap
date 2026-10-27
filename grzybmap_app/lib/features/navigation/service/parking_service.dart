import 'dart:math';
import '../../../core/services/preferences_service.dart';

class ParkingNavigation {
  final double distanceMeters;
  final int bearingDegrees;
  final String humanDistance;
  final int walkMinutes;
  final String cardinalDirection; // e.g. 'NW'
  final String arrowSymbol; // e.g. '↖'

  const ParkingNavigation({
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.humanDistance,
    required this.walkMinutes,
    required this.cardinalDirection,
    required this.arrowSymbol,
  });

  static (String, String) getCardinalAndArrow(int bearing) {
    final normalized = (bearing % 360 + 360) % 360;
    if (normalized >= 337.5 || normalized < 22.5) return ('N', '↑');
    if (normalized < 67.5) return ('NE', '↗');
    if (normalized < 112.5) return ('E', '→');
    if (normalized < 157.5) return ('SE', '↘');
    if (normalized < 202.5) return ('S', '↓');
    if (normalized < 247.5) return ('SW', '↙');
    if (normalized < 292.5) return ('W', '←');
    return ('NW', '↖');
  }
}

class ParkingService {
  final PreferencesService? _preferencesService;
  double? _carLat;
  double? _carLng;
  DateTime? _parkedTime;

  ParkingService([this._preferencesService]);

  bool get hasCarLocation => _carLat != null && _carLng != null;
  double? get carLat => _carLat;
  double? get carLng => _carLng;
  DateTime? get parkedTime => _parkedTime;

  void restoreFromPreferences() {
    final saved = _preferencesService?.getCar();
    if (saved != null) {
      _carLat = saved.$1;
      _carLng = saved.$2;
      _parkedTime = saved.$3;
    }
  }

  void saveCarLocation(double lat, double lng, {DateTime? time}) {
    _carLat = lat;
    _carLng = lng;
    _parkedTime = time ?? DateTime.now();
    _preferencesService?.saveCar(lat, lng, _parkedTime!);
  }

  void clearCar() {
    _carLat = null;
    _carLng = null;
    _parkedTime = null;
    _preferencesService?.clearCar();
  }

  String get humanParkedElapsed {
    if (_parkedTime == null) return '';
    final elapsed = DateTime.now().difference(_parkedTime!);
    if (elapsed.inMinutes < 1) return 'przed chwilą';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min temu';
    final hours = elapsed.inHours;
    final mins = elapsed.inMinutes % 60;
    return '$hours godz. $mins min temu';
  }

  ParkingNavigation? calculateNavigationToCar(double currentLat, double currentLng) {
    if (!hasCarLocation) return null;

    final lat1 = currentLat * pi / 180.0;
    final lat2 = _carLat! * pi / 180.0;
    final dLat = (_carLat! - currentLat) * pi / 180.0;
    final dLng = (_carLng! - currentLng) * pi / 180.0;

    // Haversine formula for spherical distance
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
    final humanDist = distMeters >= 1000
        ? '${(distMeters / 1000).toStringAsFixed(1)} km'
        : '${distMeters.toInt()} m';
    final walkMins = (distMeters / 75).round(); // ~4.5 km/h walking speed

    final (cardinal, arrow) = ParkingNavigation.getCardinalAndArrow(bearing.round());

    return ParkingNavigation(
      distanceMeters: distMeters,
      bearingDegrees: bearing.round(),
      humanDistance: humanDist,
      walkMinutes: walkMins,
      cardinalDirection: cardinal,
      arrowSymbol: arrow,
    );
  }
}
