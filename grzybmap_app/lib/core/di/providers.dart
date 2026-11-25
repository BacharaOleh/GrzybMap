import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/parcel_inspector/data/datasources/bdl_remote_data_source.dart';
import '../../features/parcel_inspector/domain/repositories/forest_repository.dart';
import '../../features/parcel_inspector/data/repositories/forest_repository_impl.dart';
import '../../features/weather/data/datasources/weather_remote_data_source.dart';
import '../../features/weather/domain/repositories/weather_repository.dart';
import '../../features/weather/data/repositories/weather_repository_impl.dart';
import '../../features/navigation/service/location_service.dart';
import '../../features/navigation/service/parking_service.dart';
import '../../features/forest_search/data/datasources/geocoding_remote_data_source.dart';
import '../../features/forest_search/domain/repositories/forest_search_repository.dart';
import '../../features/forest_search/data/repositories/forest_search_repository_impl.dart';
import '../../features/mushroom_radar/service/parcel_radar_service.dart';
import '../../features/weather/data/datasources/rain_radar_service.dart';
import '../../features/weather/data/datasources/rain_heatmap_service.dart';
import '../../features/offline_mode/data/offline_forest_service.dart';
import '../services/preferences_service.dart';

/// Shared Dio instance factory with balanced mobile/web timeouts.
/// Intentionally omits global User-Agent (blocked on Web XHR) and sendTimeout
/// (to avoid Dio warnings on GET requests); per-request Options override as needed.
Dio createAppDio() {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );
}

/// Dependency Injection Providers using Riverpod
final dioProvider = Provider<Dio>((ref) {
  return createAppDio();
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});

final offlineForestServiceProvider = Provider<OfflineForestService>((ref) {
  final weatherRepo = ref.watch(weatherRepositoryProvider);
  final dio = ref.watch(dioProvider);
  return OfflineForestService(
    dio: dio,
    weatherRepository: weatherRepo,
  );
});

final forestRepositoryProvider = Provider<ForestRepository>((ref) {
  return ForestRepositoryImpl(
    remoteDataSource: BdlRemoteDataSourceImpl(dio: ref.watch(dioProvider)),
  );
});

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepositoryImpl(
    remoteDataSource: WeatherRemoteDataSourceImpl(dio: ref.watch(dioProvider)),
  );
});

final parkingServiceProvider = Provider<ParkingService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final service = ParkingService(prefs);
  service.restoreFromPreferences();
  return service;
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(ref.watch(dioProvider));
});

final forestSearchRepositoryProvider = Provider<ForestSearchRepository>((ref) {
  return ForestSearchRepositoryImpl(
    remoteDataSource: NominatimGeocodingRemoteDataSource(
      dio: ref.watch(dioProvider),
    ),
  );
});

final parcelRadarServiceProvider = Provider<ParcelRadarService>((ref) {
  return ParcelRadarService(dio: ref.watch(dioProvider));
});

final rainRadarServiceProvider = Provider<RainRadarService>((ref) {
  return RainRadarService(dio: ref.watch(dioProvider));
});

final rainHeatmapServiceProvider = Provider<RainHeatmapService>((ref) {
  return RainHeatmapService(dio: ref.watch(dioProvider));
});
