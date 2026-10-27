import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/core/services/preferences_service.dart';
import 'package:grzybmap_app/features/navigation/service/parking_service.dart';
import 'package:grzybmap_app/features/map/presentation/controllers/map_screen_controller.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/repositories/forest_repository.dart';
import 'package:grzybmap_app/features/weather/domain/repositories/weather_repository.dart';
import 'package:grzybmap_app/features/navigation/service/location_service.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/models.dart';
import 'package:grzybmap_app/features/weather/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Persists and restores car parking location', () async {
      final prefsService = PreferencesService();
      await prefsService.init();

      expect(prefsService.getCar(), isNull);

      final now = DateTime(2026, 10, 16, 14, 30);
      await prefsService.saveCar(54.1234, 18.5678, now);

      final saved = prefsService.getCar();
      expect(saved, isNotNull);
      expect(saved!.$1, 54.1234);
      expect(saved.$2, 18.5678);
      expect(saved.$3, now);

      await prefsService.clearCar();
      expect(prefsService.getCar(), isNull);
    });

    test('Persists base layer and onboarding state', () async {
      final prefsService = PreferencesService();
      await prefsService.init();

      expect(prefsService.getBaseLayer(), isNull);
      expect(prefsService.isOnboardingDismissed(), isFalse);

      await prefsService.saveBaseLayer('dark');
      await prefsService.setOnboardingDismissed(true);

      expect(prefsService.getBaseLayer(), 'dark');
      expect(prefsService.isOnboardingDismissed(), isTrue);
    });

    test('Persists radar settings', () async {
      final prefsService = PreferencesService();
      await prefsService.init();

      expect(prefsService.getShowNames(), isFalse);
      expect(prefsService.getShowForest(), isFalse);
      expect(prefsService.getShowLowProb(), isTrue);

      await prefsService.saveRadarSettings(
        showNames: true,
        showForest: true,
        showLowProb: false,
      );

      expect(prefsService.getShowNames(), isTrue);
      expect(prefsService.getShowForest(), isTrue);
      expect(prefsService.getShowLowProb(), isFalse);
    });
  });

  group('PreferencesService Integration with Controllers', () {
    test('ParkingService auto-restores saved position', () async {
      SharedPreferences.setMockInitialValues({
        'car_lat': 52.2297,
        'car_lng': 21.0122,
        'car_time': DateTime(2026, 10, 16, 12, 0).toIso8601String(),
      });

      final prefsService = PreferencesService();
      await prefsService.init();

      final parkingService = ParkingService(prefsService);
      parkingService.restoreFromPreferences();

      expect(parkingService.hasCarLocation, isTrue);
      expect(parkingService.carLat, 52.2297);
      expect(parkingService.carLng, 21.0122);
    });

    test('MapScreenNotifier initializes with saved base layer and car', () async {
      final parkedTime = DateTime(2026, 10, 16, 10, 0);
      SharedPreferences.setMockInitialValues({
        'active_base_layer': 'topo',
        'onboarding_dismissed': true,
        'car_lat': 53.80,
        'car_lng': 18.20,
        'car_time': parkedTime.toIso8601String(),
      });

      final prefsService = PreferencesService();
      await prefsService.init();

      final parkingService = ParkingService(prefsService);
      parkingService.restoreFromPreferences();

      final notifier = MapScreenNotifier(
        forestRepository: _FakeForestRepo(),
        weatherRepository: _FakeWeatherRepo(),
        parkingService: parkingService,
        locationService: _FakeLocationService(),
        preferencesService: prefsService,
      );

      expect(notifier.state.activeBaseLayer, 'topo');
      expect(notifier.state.showOnboarding, isFalse);
      expect(notifier.state.hasCar, isTrue);
      expect(notifier.state.carLocation, const LatLng(53.80, 18.20));

      // Test cycleBaseLayer persists new layer
      notifier.cycleBaseLayer(); // 'topo' -> 'osm'
      expect(notifier.state.activeBaseLayer, 'osm');
      await Future<void>.delayed(Duration.zero);
      expect(prefsService.getBaseLayer(), 'osm');
    });
  });
}
