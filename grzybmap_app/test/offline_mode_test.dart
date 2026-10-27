import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grzybmap_app/features/map/presentation/controllers/map_screen_controller.dart';
import 'package:grzybmap_app/features/navigation/service/location_service.dart';
import 'package:grzybmap_app/features/navigation/service/parking_service.dart';
import 'package:grzybmap_app/features/offline_mode/data/offline_forest_service.dart';
import 'package:grzybmap_app/features/offline_mode/domain/models/offline_forest_area.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/models.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/repositories/forest_repository.dart';
import 'package:grzybmap_app/features/weather/domain/models.dart';
import 'package:grzybmap_app/features/weather/domain/repositories/weather_repository.dart';

class FailingForestRepository implements ForestRepository {
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
    CancelToken? cancelToken,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/mock'),
      type: DioExceptionType.connectionError,
      message: 'No cellular connection in forest',
    );
  }
}

class FakeWeatherRepository implements WeatherRepository {
  @override
  Future<WeatherRainfall?> getRainfallHistory({
    required double lat,
    required double lng,
    CancelToken? cancelToken,
  }) async {
    return const WeatherRainfall(
      totalRainMm: 42.0,
      avgTempC: 16.0,
      moistureLabel: 'Optymalna',
      moistureBadgeColor: Colors.green,
      rainBonusScore: 25,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Mode Model Serialization', () {
    test('ForestParcel toMap and fromMap roundtrip preserves all fields', () {
      const parcel = ForestParcel(
        subareaId: '02-14-1-05-12a-00',
        address: 'Bory Tucholskie 12a',
        primarySpecies: TreeSpecies(
          code: 'SO',
          namePl: 'Sosna zwyczajna',
          nameRu: 'Сосна',
          latin: 'Pinus sylvestris',
          icon: '🌲',
          sharePercent: 80,
        ),
        secondarySpecies: [
          TreeSpecies(
            code: 'BRZ',
            namePl: 'Brzoza brodawkowata',
            nameRu: 'Берёза',
            latin: 'Betula pendula',
            icon: '🌳',
            sharePercent: 20,
          ),
        ],
        ageYears: 75,
        ageCategory: '75 lat',
        habitat: ForestHabitat(
          code: 'BŚW',
          namePl: 'Bór świeży',
          descPl: 'Piaszczyste gleby iglaste',
          moisture: 'optimal',
        ),
        status: ForestStatus(
          code: 'GOSP',
          status: ForestLegalStatus.allowed,
          labelPl: 'Las gospodarczy',
          color: Colors.green,
        ),
        areaHa: '5.20 ha',
        inspectorate: 'Nadleśnictwo Tuchola',
        latitude: 53.75,
        longitude: 18.00,
      );

      final map = parcel.toMap();
      final recreated = ForestParcel.fromMap(map);

      expect(recreated.subareaId, '02-14-1-05-12a-00');
      expect(recreated.address, 'Bory Tucholskie 12a');
      expect(recreated.primarySpecies.code, 'SO');
      expect(recreated.primarySpecies.namePl, 'Sosna zwyczajna');
      expect(recreated.secondarySpecies.length, 1);
      expect(recreated.secondarySpecies.first.code, 'BRZ');
      expect(recreated.ageYears, 75);
      expect(recreated.habitat.code, 'BŚW');
      expect(recreated.status.status, ForestLegalStatus.allowed);
      expect(recreated.areaHa, '5.20 ha');
      expect(recreated.latitude, 53.75);
      expect(recreated.longitude, 18.00);
      expect(recreated.compositionSummary, contains('Sosna'));
      expect(recreated.compositionSummary, contains('Brzoza'));
    });

    test('WeatherRainfall toMap and fromMap roundtrip preserves data', () {
      const weather = WeatherRainfall(
        totalRainMm: 38.4,
        avgTempC: 15.6,
        moistureLabel: 'Wysoka',
        moistureBadgeColor: Color(0xFF10B981),
        rainBonusScore: 28,
        periodDays: 14,
        soilTempC: 14.1,
        soilMoistureM3: 0.35,
        isAvailable: true,
      );

      final map = weather.toMap();
      final recreated = WeatherRainfall.fromMap(map);

      expect(recreated.totalRainMm, 38.4);
      expect(recreated.avgTempC, 15.6);
      expect(recreated.moistureLabel, 'Wysoka');
      expect(recreated.rainBonusScore, 28);
      expect(recreated.soilTempC, 14.1);
      expect(recreated.soilMoistureM3, 0.35);
      expect(recreated.soilMoisturePercent, '35.0%');
    });

    test('OfflineForestArea full JSON serialization roundtrip', () {
      const parcel = ForestParcel(
        subareaId: 'OFF-1',
        address: 'Wydzielenie 1a',
        primarySpecies: TreeSpecies(
          code: 'SO',
          namePl: 'Sosna',
          nameRu: '',
          latin: '',
          icon: '🌲',
        ),
        ageYears: 60,
        ageCategory: '60 lat',
        habitat: ForestHabitat(
          code: 'BŚW',
          namePl: 'Bór świeży',
          descPl: '',
          moisture: 'optimal',
        ),
        status: ForestStatus(
          code: 'GOSP',
          status: ForestLegalStatus.allowed,
          labelPl: 'Gospodarczy',
          color: Colors.green,
        ),
        inspectorate: 'Nadleśnictwo',
        latitude: 53.70,
        longitude: 18.00,
      );

      const weather = WeatherRainfall(
        totalRainMm: 30.0,
        avgTempC: 16.0,
        moistureLabel: 'Optymalna',
        moistureBadgeColor: Colors.green,
        rainBonusScore: 20,
      );

      final area = OfflineForestArea(
        id: 'offline_123',
        name: 'Bory Tucholskie 10×10 km',
        downloadedAt: DateTime(2026, 10, 16, 20, 0),
        centerLat: 53.70,
        centerLng: 18.00,
        minLat: 53.65,
        minLng: 17.92,
        maxLat: 53.75,
        maxLng: 18.08,
        radiusKm: 5.0,
        parcelsCount: 1,
        sizeBytes: 1540,
        weatherSnapshot: weather,
        parcels: const [parcel],
      );

      final jsonStr = area.toJson();
      final restored = OfflineForestArea.fromJson(jsonStr);

      expect(restored.id, 'offline_123');
      expect(restored.name, 'Bory Tucholskie 10×10 km');
      expect(restored.centerLat, 53.70);
      expect(restored.parcels.length, 1);
      expect(restored.parcels.first.primarySpecies.namePl, 'Sosna');
      expect(restored.contains(53.71, 18.01), isTrue);
      expect(restored.contains(55.00, 18.00), isFalse);

      final summary = restored.toSummary();
      expect(summary.name, 'Bory Tucholskie 10×10 km');
      expect(summary.formattedSize, '1.5 KB');
      expect(summary.weatherRainMm, 30.0);
    });
  });

  group('OfflineForestService', () {
    late SharedPreferences prefs;
    late OfflineForestService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = OfflineForestService(
        prefs: prefs,
        weatherRepository: FakeWeatherRepository(),
      );
    });

    test('downloads area and finds nearest parcel offline', () async {
      final area = await service.downloadArea(
        name: 'Puszcza Kampinoska 10×10 km',
        center: const LatLng(52.33, 20.65),
        radiusKm: 5.0,
      );

      expect(area.id, startsWith('offline_'));
      expect(area.name, 'Puszcza Kampinoska 10×10 km');
      expect(area.parcels.isNotEmpty, isTrue);

      final summaries = service.getAreaSummaries();
      expect(summaries.length, 1);
      expect(summaries.first.id, area.id);

      // Search parcel right at center
      final found = service.findClosestParcel(52.33, 20.65);
      expect(found, isNotNull);
      expect(found!.area.name, 'Puszcza Kampinoska 10×10 km');
      expect(found.distanceMeters, lessThan(3000));
      expect(found.weather.totalRainMm, greaterThan(0));

      // Coordinate far away outside any downloaded area
      final notFound = service.findClosestParcel(50.00, 19.00);
      expect(notFound, isNull);
    });

    test('forced offline toggle persists correctly', () async {
      expect(service.isForcedOffline(), isFalse);
      await service.setForcedOffline(true);
      expect(service.isForcedOffline(), isTrue);
      await service.setForcedOffline(false);
      expect(service.isForcedOffline(), isFalse);
    });

    test('deletes area and clears all areas', () async {
      final area1 = await service.downloadArea(
        name: 'Area 1',
        center: const LatLng(52.0, 20.0),
      );
      final area2 = await service.downloadArea(
        name: 'Area 2',
        center: const LatLng(53.0, 21.0),
      );

      expect(service.getAreaSummaries().length, 2);

      await service.deleteArea(area1.id);
      final remaining = service.getAreaSummaries();
      expect(remaining.length, 1);
      expect(remaining.first.id, area2.id);

      await service.clearAll();
      expect(service.getAreaSummaries(), isEmpty);
    });
  });

  group('MapScreenNotifier Offline Fallback & Inspection', () {
    late SharedPreferences prefs;
    late OfflineForestService offlineService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      offlineService = OfflineForestService(
        prefs: prefs,
        weatherRepository: FakeWeatherRepository(),
      );
    });

    test('inspectPoint falls back to offline cache when network fails', () async {
      // 1. Download area into offline cache
      await offlineService.downloadArea(
        name: 'Bory Offline Cache',
        center: const LatLng(53.75, 18.00),
      );

      // 2. Map notifier using FailingForestRepository
      final notifier = MapScreenNotifier(
        forestRepository: FailingForestRepository(),
        weatherRepository: FakeWeatherRepository(),
        parkingService: ParkingService(null),
        locationService: LocationService(),
        offlineForestService: offlineService,
      );

      // 3. Inspect point within downloaded area
      final result = await notifier.inspectPoint(const LatLng(53.75, 18.00), 14);

      // 4. Must succeed via offline fallback!
      expect(result, isA<InspectionSuccess>());
      expect(notifier.state.isOfflineData, isTrue);
      expect(notifier.state.activeParcel, isNotNull);
      expect(notifier.state.activeWeather, isNotNull);
      expect(notifier.state.mushroomMatches.isNotEmpty, isTrue);
    });

    test('forced offline mode inspects parcel with 0 network calls', () async {
      // 1. Prepare offline area
      await offlineService.downloadArea(
        name: 'Kampinos Offline',
        center: const LatLng(52.30, 20.70),
      );
      await offlineService.setForcedOffline(true);

      final notifier = MapScreenNotifier(
        forestRepository: FailingForestRepository(),
        weatherRepository: FakeWeatherRepository(),
        parkingService: ParkingService(null),
        locationService: LocationService(),
        offlineForestService: offlineService,
      );

      expect(notifier.state.isOfflineMode, isTrue);

      final result = await notifier.inspectPoint(const LatLng(52.30, 20.70), 14);
      expect(result, isA<InspectionSuccess>());
      expect(notifier.state.isOfflineData, isTrue);
      expect(notifier.state.activeParcel?.address, isNotEmpty);
    });
  });
}
