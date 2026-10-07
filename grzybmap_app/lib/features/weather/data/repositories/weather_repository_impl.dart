import 'package:flutter/material.dart';
import '../../domain/models.dart';
import '../../domain/repositories/weather_repository.dart';
import '../datasources/weather_remote_data_source.dart';

class _WeatherCacheEntry {
  final WeatherRainfall data;
  final DateTime cachedAt;

  const _WeatherCacheEntry(this.data, this.cachedAt);

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > const Duration(hours: 1);
}

class WeatherRepositoryImpl implements WeatherRepository {
  final WeatherRemoteDataSource _remoteDataSource;
  final Map<String, _WeatherCacheEntry> _cache = {};

  WeatherRepositoryImpl({WeatherRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? WeatherRemoteDataSourceImpl();

  /// Calculates smooth non-linear rain bonus curve without sharp step jumps.
  /// Range: -15 (severe drought) to +25 (optimal rain soaking over 14 days)
  static int calculateSmoothRainBonus(double rainMm) {
    if (rainMm <= 0.0) return -15;
    if (rainMm < 10.0) {
      // Smooth linear interpolation from -15 to -2
      return (-15.0 + (rainMm / 10.0) * 13.0).round();
    } else if (rainMm < 25.0) {
      // Smooth linear interpolation from -2 to +14
      final t = (rainMm - 10.0) / 15.0;
      return (-2.0 + t * 16.0).round();
    } else if (rainMm < 50.0) {
      // Smooth linear interpolation from +14 to +25
      final t = (rainMm - 25.0) / 25.0;
      return (14.0 + t * 11.0).round();
    } else {
      return 25; // Saturated optimal rain
    }
  }

  @override
  Future<WeatherRainfall?> getRainfallHistory({
    required double lat,
    required double lng,
  }) async {
    final cacheKey = '${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    try {
      final data = await _remoteDataSource.fetchRainfallJson(lat: lat, lng: lng);
      final daily = data['daily'] as Map<String, dynamic>? ?? {};
      final rainList = (daily['precipitation_sum'] as List<dynamic>?)
              ?.where((e) => e != null)
              .map((e) => (e as num).toDouble())
              .toList() ??
          [];
      final tempList = (daily['temperature_2m_max'] as List<dynamic>?)
              ?.where((e) => e != null)
              .map((e) => (e as num).toDouble())
              .toList() ??
          [];

      final totalRain = rainList.fold<double>(0.0, (sum, val) => sum + val);
      final avgTemp = tempList.isNotEmpty
          ? tempList.fold<double>(0.0, (sum, val) => sum + val) / tempList.length
          : 17.5;

      // Extract soil metrics (W2: soil temperature at 6cm and soil moisture 0-1cm)
      final hourly = data['hourly'] as Map<String, dynamic>? ?? {};
      final soilTempList = (hourly['soil_temperature_6cm'] as List<dynamic>?)
              ?.where((e) => e != null)
              .map((e) => (e as num).toDouble())
              .toList() ??
          [];
      final soilMoistList = (hourly['soil_moisture_0_to_1cm'] as List<dynamic>?)
              ?.where((e) => e != null)
              .map((e) => (e as num).toDouble())
              .toList() ??
          [];

      // Recent 24-hour averages for ground conditions
      double? avgSoilTemp;
      if (soilTempList.isNotEmpty) {
        final recent = soilTempList.length > 24
            ? soilTempList.sublist(soilTempList.length - 24)
            : soilTempList;
        avgSoilTemp = recent.fold<double>(0.0, (s, v) => s + v) / recent.length;
      }

      double? avgSoilMoist;
      if (soilMoistList.isNotEmpty) {
        final recent = soilMoistList.length > 24
            ? soilMoistList.sublist(soilMoistList.length - 24)
            : soilMoistList;
        avgSoilMoist = recent.fold<double>(0.0, (s, v) => s + v) / recent.length;
      }

      // Smooth bonus score based on 14-day accumulation
      final bonus = calculateSmoothRainBonus(totalRain);

      String moistureLabel;
      Color badgeColor;

      if (totalRain < 8.0) {
        moistureLabel = 'Przesuszona ściółka (brak wysypu)';
        badgeColor = const Color(0xFFEF4444);
      } else if (totalRain < 20.0) {
        moistureLabel = 'Umiarkowane nawilżenie';
        badgeColor = const Color(0xFFFBBF24);
      } else if (totalRain < 45.0) {
        moistureLabel = 'Dobre nawilżenie ściółki (optimum)';
        badgeColor = const Color(0xFF10B981);
      } else {
        moistureLabel = 'Bardzo obfite opady deszczu!';
        badgeColor = const Color(0xFF38BDF8);
      }

      final result = WeatherRainfall(
        totalRainMm: totalRain,
        avgTempC: avgTemp,
        moistureLabel: moistureLabel,
        moistureBadgeColor: badgeColor,
        rainBonusScore: bonus,
        periodDays: 14,
        soilTempC: avgSoilTemp,
        soilMoistureM3: avgSoilMoist,
        isAvailable: true,
      );

      _cache[cacheKey] = _WeatherCacheEntry(result, DateTime.now());
      return result;
    } catch (e) {
      // W3 fix: Return null on error instead of fabricated 16.5 mm
      return null;
    }
  }
}
