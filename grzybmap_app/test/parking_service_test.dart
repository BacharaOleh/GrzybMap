import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:grzybmap_app/features/navigation/service/parking_service.dart';
import 'package:grzybmap_app/features/map/presentation/controllers/map_screen_controller.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/models.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/repositories/forest_repository.dart';
import 'package:grzybmap_app/features/weather/domain/models.dart';
import 'package:grzybmap_app/features/weather/domain/repositories/weather_repository.dart';
import 'package:grzybmap_app/features/navigation/service/location_service.dart';

class _FakeForestRepo implements ForestRepository {
  @override
  Future<ForestParcel?> getParcelAt({
    required double lat,
    required double lng,
    required String bbox3857,
    required int width,
    required int height,
    required int pixelX,
    required int pixelY,
    required int zoom,
    dynamic cancelToken,
  }) async => null;
}

class _FakeWeatherRepo implements WeatherRepository {
  @override
  Future<WeatherRainfall?> getRainfallHistory({
    required double lat,
    required double lng,
    dynamic cancelToken,
  }) async => null;
}

class _FakeLocationService implements LocationService {
  @override
  Future<LocationResult?> determineLocation() async => null;
}

void main() {
  group('ParkingService Navigation Math & Formulas', () {
    late ParkingService service;

    setUp(() {
      service = ParkingService();
    });

    test('Initial state has no car', () {
      expect(service.hasCarLocation, isFalse);
      expect(service.calculateNavigationToCar(52.0, 21.0), isNull);
    });

    test('saveCarLocation saves coordinates and calculates accurate distance', () {
      // Car parked at Kampinos
      service.saveCarLocation(52.320, 20.650);
      expect(service.hasCarLocation, isTrue);

      // User walking 500m to the North
      // 1 deg lat ~ 111 km -> 0.0045 deg ~ 500 m
      final nav = service.calculateNavigationToCar(52.3245, 20.650);
      expect(nav, isNotNull);
      expect(nav!.distanceMeters, closeTo(500, 30));
      expect(nav.walkMinutes, closeTo(7, 2));
      // Car is to the South (around 180 deg)
      expect(nav.cardinalDirection, 'S');
      expect(nav.arrowSymbol, '↓');
    });

    test('getCardinalAndArrow correctly categorizes all 8 sectors', () {
      expect(ParkingNavigation.getCardinalAndArrow(0), ('N', '↑'));
      expect(ParkingNavigation.getCardinalAndArrow(45), ('NE', '↗'));
      expect(ParkingNavigation.getCardinalAndArrow(90), ('E', '→'));
      expect(ParkingNavigation.getCardinalAndArrow(135), ('SE', '↘'));
      expect(ParkingNavigation.getCardinalAndArrow(180), ('S', '↓'));
      expect(ParkingNavigation.getCardinalAndArrow(225), ('SW', '↙'));
      expect(ParkingNavigation.getCardinalAndArrow(270), ('W', '←'));
      expect(ParkingNavigation.getCardinalAndArrow(315), ('NW', '↖'));
      expect(ParkingNavigation.getCardinalAndArrow(359), ('N', '↑'));
    });

    test('clearCar removes saved location', () {
      service.saveCarLocation(52.0, 21.0);
      expect(service.hasCarLocation, isTrue);
      service.clearCar();
      expect(service.hasCarLocation, isFalse);
    });
  });

  group('MapScreenNotifier Car Integration', () {
    test('saveCarLocation updates carLocation and notifies state', () {
      final parking = ParkingService();
      final notifier = MapScreenNotifier(
        forestRepository: _FakeForestRepo(),
        weatherRepository: _FakeWeatherRepo(),
        parkingService: parking,
        locationService: _FakeLocationService(),
      );

      expect(notifier.state.hasCar, isFalse);
      expect(notifier.state.carLocation, isNull);

      // Save car at specific point
      const carPoint = LatLng(53.60, 18.00);
      notifier.saveCarLocation(point: carPoint);

      expect(notifier.state.hasCar, isTrue);
      expect(notifier.state.carLocation, carPoint);
      expect(notifier.state.carParkedTime, isNotNull);
      expect(parking.hasCarLocation, isTrue);

      // Clear car
      notifier.clearCarLocation();
      expect(notifier.state.hasCar, isFalse);
      expect(notifier.state.carLocation, isNull);
      expect(notifier.state.carNavigation, isNull);
      expect(parking.hasCarLocation, isFalse);
    });
  });
}
