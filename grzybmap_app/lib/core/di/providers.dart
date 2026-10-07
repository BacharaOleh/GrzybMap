import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/parcel_inspector/domain/repositories/forest_repository.dart';
import '../../features/parcel_inspector/data/repositories/forest_repository_impl.dart';
import '../../features/weather/domain/repositories/weather_repository.dart';
import '../../features/weather/data/repositories/weather_repository_impl.dart';
import '../../features/navigation/service/location_service.dart';
import '../../features/navigation/service/parking_service.dart';

/// Dependency Injection Providers using Riverpod
final forestRepositoryProvider = Provider<ForestRepository>((ref) {
  return ForestRepositoryImpl();
});

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepositoryImpl();
});

final parkingServiceProvider = Provider<ParkingService>((ref) {
  return ParkingService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
