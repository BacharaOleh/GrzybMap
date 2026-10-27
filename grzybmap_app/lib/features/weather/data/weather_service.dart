import 'package:dio/dio.dart';
import '../domain/models.dart';
import '../domain/repositories/weather_repository.dart';
import 'repositories/weather_repository_impl.dart';

/// Legacy service facade delegating to WeatherRepositoryImpl.
class WeatherService implements WeatherRepository {
  final WeatherRepository _repository;

  WeatherService([WeatherRepository? repository])
      : _repository = repository ?? WeatherRepositoryImpl();

  @override
  Future<WeatherRainfall?> getRainfallHistory({
    required double lat,
    required double lng,
    CancelToken? cancelToken,
  }) {
    return _repository.getRainfallHistory(
      lat: lat,
      lng: lng,
      cancelToken: cancelToken,
    );
  }
}
