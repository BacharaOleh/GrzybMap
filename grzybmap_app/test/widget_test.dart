import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/core/di/providers.dart';
import 'package:grzybmap_app/features/mushroom_radar/domain/parcel_radar.dart';
import 'package:grzybmap_app/features/mushroom_radar/service/parcel_radar_service.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/models.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/repositories/forest_repository.dart';
import 'package:grzybmap_app/features/weather/domain/models.dart';
import 'package:grzybmap_app/features/weather/domain/repositories/weather_repository.dart';
import 'package:grzybmap_app/main.dart';

class _FakeWeatherRepository implements WeatherRepository {
  @override
  Future<WeatherRainfall?> getRainfallHistory({
    required double lat,
    required double lng,
    dynamic cancelToken,
  }) async =>
      null;
}

class _FakeForestRepository implements ForestRepository {
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
  }) async =>
      null;
}

class _FakeParcelRadarService implements ParcelRadarService {
  @override
  Future<List<ParcelRadarItem>> fetchVisibleRadars({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    WeatherRainfall? weather,
    required int selectedMonth,
    String? targetMushroomId,
    CancelToken? cancelToken,
  }) async =>
      const [];
}

void main() {
  testWidgets('GrzybMapApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weatherRepositoryProvider.overrideWithValue(_FakeWeatherRepository()),
          forestRepositoryProvider.overrideWithValue(_FakeForestRepository()),
          parcelRadarServiceProvider.overrideWithValue(_FakeParcelRadarService()),
        ],
        child: const GrzybMapApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(GrzybMapApp), findsOneWidget);
  });
}
