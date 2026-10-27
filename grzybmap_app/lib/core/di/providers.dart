import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/parcel_inspector/domain/repositories/forest_repository.dart';
import '../../features/parcel_inspector/data/repositories/forest_repository_impl.dart';
import '../../features/weather/domain/repositories/weather_repository.dart';
import '../../features/weather/data/repositories/weather_repository_impl.dart';
import '../../features/navigation/service/location_service.dart';
import '../../features/navigation/service/parking_service.dart';
import '../../features/forest_search/domain/repositories/forest_search_repository.dart';
import '../../features/forest_search/data/repositories/forest_search_repository_impl.dart';
import '../../features/mushroom_radar/service/parcel_radar_service.dart';
import '../../features/weather/data/datasources/rain_radar_service.dart';
import '../../features/weather/data/datasources/rain_heatmap_service.dart';
import '../../features/offline_mode/data/offline_forest_service.dart';
import '../services/preferences_service.dart';

/// Dependency Injection Providers using Riverpod
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});

final offlineForestServiceProvider = Provider<OfflineForestService>((ref) {
  final weatherRepo = ref.watch(weatherRepositoryProvider);
  return OfflineForestService(weatherRepository: weatherRepo);
});

final forestRepositoryProvider = Provider<ForestRepository>((ref) {
  return ForestRepositoryImpl();
});

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepositoryImpl();
});

final parkingServiceProvider = Provider<ParkingService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final service = ParkingService(prefs);
  service.restoreFromPreferences();
  return service;
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final forestSearchRepositoryProvider = Provider<ForestSearchRepository>((ref) {
  return ForestSearchRepositoryImpl();
});

final parcelRadarServiceProvider = Provider<ParcelRadarService>((ref) {
  return ParcelRadarService();
});

final rainRadarServiceProvider = Provider<RainRadarService>((ref) {
  return RainRadarService();
});

final rainHeatmapServiceProvider = Provider<RainHeatmapService>((ref) {
  return RainHeatmapService();
});
