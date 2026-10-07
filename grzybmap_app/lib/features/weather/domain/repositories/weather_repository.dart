import '../models.dart';

/// Contract for fetching rainfall and weather history.
abstract class WeatherRepository {
  Future<WeatherRainfall?> getRainfallHistory({
    required double lat,
    required double lng,
  });
}
