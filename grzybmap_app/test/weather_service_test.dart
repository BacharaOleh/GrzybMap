import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/features/weather/data/repositories/weather_repository_impl.dart';
import 'package:grzybmap_app/features/weather/domain/models.dart';
import 'package:grzybmap_app/features/weather/data/datasources/weather_remote_data_source.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/models.dart';
import 'package:grzybmap_app/features/mushroom_radar/service/match_engine.dart';

class MockWeatherRemoteDataSource implements WeatherRemoteDataSource {
  final Map<String, dynamic>? responseData;
  final bool shouldThrow;

  MockWeatherRemoteDataSource({this.responseData, this.shouldThrow = false});

  @override
  Future<Map<String, dynamic>> fetchRainfallJson({
    required double lat,
    required double lng,
  }) async {
    if (shouldThrow) throw Exception('Network timeout or 500 error');
    return responseData ?? {};
  }
}

void main() {
  group('Weather Service (W1, W2, W3)', () {
    test('W1: Smooth rain bonus calculation without step jumps', () {
      expect(WeatherRepositoryImpl.calculateSmoothRainBonus(0.0), -15);
      expect(WeatherRepositoryImpl.calculateSmoothRainBonus(5.0), -9);
      expect(WeatherRepositoryImpl.calculateSmoothRainBonus(10.0), -2);
      expect(WeatherRepositoryImpl.calculateSmoothRainBonus(25.0), 14);
      expect(WeatherRepositoryImpl.calculateSmoothRainBonus(50.0), 25);
    });

    test('W2: Soil temperature and moisture correctly parsed from hourly data', () async {
      final mockData = {
        'daily': {
          'precipitation_sum': List.filled(14, 2.5), // 35 mm
          'temperature_2m_max': List.filled(14, 18.0),
        },
        'hourly': {
          'soil_temperature_6cm': List.filled(360, 14.5),
          'soil_moisture_0_to_1cm': List.filled(360, 0.32),
        }
      };

      final repo = WeatherRepositoryImpl(
        remoteDataSource: MockWeatherRemoteDataSource(responseData: mockData),
      );

      final result = await repo.getRainfallHistory(lat: 52.05, lng: 21.38);

      expect(result, isNotNull);
      expect(result!.totalRainMm, closeTo(35.0, 0.01));
      expect(result.periodDays, 14);
      expect(result.soilTempC, closeTo(14.5, 0.01));
      expect(result.soilTempLabel, '14.5°C');
      expect(result.soilMoistureM3, closeTo(0.32, 0.01));
      expect(result.soilMoisturePercent, '32.0%');
    });

    test('W3: Weather error returns null without fake 16.5mm fallback', () async {
      final repo = WeatherRepositoryImpl(
        remoteDataSource: MockWeatherRemoteDataSource(shouldThrow: true),
      );

      final result = await repo.getRainfallHistory(lat: 52.05, lng: 21.38);
      expect(result, isNull);
    });

    test('MatchEngine evaluates cleanly with null weather (honest fallback)', () {
      final parcel = ForestParcel(
        subareaId: '12-a',
        address: '01-02-12-a',
        inspectorate: 'Nadleśnictwo Celestynów',
        primarySpecies: const TreeSpecies(
          code: 'SO',
          namePl: 'Sosna zwyczajna',
          nameRu: 'Сосна обыкновенная',
          latin: 'Pinus sylvestris',
          icon: '🌲',
          sharePercent: 100,
        ),
        ageYears: 65,
        ageCategory: 'Dojrzały drzewostan (rębny)',
        habitat: const ForestHabitat(
          code: 'BŚW',
          namePl: 'Bór świeży',
          descPl: 'Umiarkowanie wilgotne podłoże piaszczyste',
          moisture: 'świeże',
        ),
        status: const ForestStatus(
          code: 'GOSP',
          status: ForestLegalStatus.allowed,
          labelPl: 'Las gospodarczy — zbiór dozwolony',
          color: Color(0xFF10B981),
        ),
        latitude: 52.05,
        longitude: 21.38,
      );

      final resultsWithNullWeather = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: null,
        selectedMonth: 9, // September
      );

      expect(resultsWithNullWeather.isNotEmpty, true);
      // Borowik szlachetny (Borowik sosnowy) or Maślak should score reasonably
      final top = resultsWithNullWeather.first;
      expect(top.probabilityPercent, greaterThan(0));
      // Checks that reasons explicitly state lack of weather data
      expect(
        top.negativeReasons.any((r) => r.contains('Brak danych stacji pogodowej')),
        isTrue,
      );
    });
  });
}
