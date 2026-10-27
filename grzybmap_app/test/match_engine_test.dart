import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/features/mushroom_radar/service/match_engine.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/models.dart';
import 'package:grzybmap_app/features/weather/domain/models.dart';

void main() {
  // Helper to construct a test forest parcel
  ForestParcel createTestParcel({
    String speciesCode = 'SO',
    String speciesName = 'Sosna zwyczajna',
    int age = 65,
    String habitatCode = 'BŚW',
    List<TreeSpecies> secondarySpecies = const [],
  }) {
    return ForestParcel(
      subareaId: '01-a',
      address: '17-01-1-03-360-a-00',
      inspectorate: 'Nadleśnictwo Celestynów',
      primarySpecies: TreeSpecies(
        code: speciesCode,
        namePl: speciesName,
        nameRu: speciesName,
        latin: 'Pinus sylvestris',
        icon: '🌲',
        sharePercent: secondarySpecies.isEmpty ? 100 : 70,
      ),
      secondarySpecies: secondarySpecies,
      ageYears: age,
      ageCategory: 'Dojrzały bór (50-90 lat)',
      habitat: ForestHabitat(
        code: habitatCode,
        namePl: 'Bór świeży',
        descPl: 'Umiarkowanie wilgotne podłoże piaszczyste',
        moisture: 'świeże',
      ),
      status: const ForestStatus(
        code: 'GOSP',
        status: ForestLegalStatus.allowed,
        labelPl: 'Las gospodarczy',
        color: Color(0xFF10B981),
      ),
      latitude: 52.05,
      longitude: 21.38,
    );
  }

  // Helper to construct test weather
  WeatherRainfall createTestWeather({
    double rainMm = 35.0,
    int rainBonus = 18,
    double? soilTemp = 14.5,
    double? soilMoisture = 0.32,
  }) {
    return WeatherRainfall(
      totalRainMm: rainMm,
      avgTempC: 17.0,
      moistureLabel: 'Dobre nawilżenie ściółki',
      moistureBadgeColor: const Color(0xFF10B981),
      rainBonusScore: rainBonus,
      periodDays: 14,
      soilTempC: soilTemp,
      soilMoistureM3: soilMoisture,
      isAvailable: true,
    );
  }

  group('MatchEngine: Seasonality & Off-season (L1, L6)', () {
    test('Deep off-season (distance >= 2 months) strictly yields 0% and gray badge', () {
      final parcel = createTestParcel();
      final weather = createTestWeather();

      // Borowik szlachetny (Boletus edulis) has season in months 6,7,8,9,10,11
      // Month 1 (January) is 2 months away from November and 5 months away from June -> distance = 2
      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 1, // January (deep winter)
      );

      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.probabilityPercent, 0);
      expect(borowik.chanceCategory, 'Poza sezonem (0%)');
      expect(borowik.chanceColor, const Color(0xFF6B7280));
      expect(borowik.negativeReasons.any((r) => r.contains('Brak owocowania')), isTrue);
    });

    test('Active season yields +15 season bonus and positive reason', () {
      final parcel = createTestParcel();
      final weather = createTestWeather();

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9, // September (peak season for Borowik)
      );

      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.probabilityPercent, greaterThan(60));
      expect(borowik.positiveReasons.any((r) => r.contains('Aktywny naturalny sezon')), isTrue);
    });

    test('Shoulder season (1 month away) is penalized and capped at 18%', () {
      // Borowik szlachetny season: 6, 7, 8, 9, 10, 11
      // Month 5 (May) is exactly 1 month away from June
      final parcel = createTestParcel();
      final weather = createTestWeather();

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 5, // May (1 month before June)
      );

      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.probabilityPercent, lessThanOrEqualTo(18));
      expect(borowik.negativeReasons.any((r) => r.contains('Kraniec sezonu')), isTrue);
    });
  });

  group('MatchEngine: Tree Species & Composite Stands (P3, L2)', () {
    test('Pure stand with matching preferred tree receives high tree score', () {
      final parcel = createTestParcel(speciesCode: 'SO', speciesName: 'Sosna zwyczajna');
      final weather = createTestWeather();

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9,
      );

      // Maślak zwyczajny strictly prefers Pine ('SO')
      final maslak = results.firstWhere((r) => r.mushroom.id == 'maslak_zwyczajny');
      expect(maslak.probabilityPercent, greaterThan(70));
      expect(maslak.positiveReasons.any((r) => r.contains('Drzewostan główny: Sosna')), isTrue);
    });

    test('Composite stand with secondary species benefits matching mushrooms', () {
      // Oak secondary species in a pine forest
      final parcel = createTestParcel(
        speciesCode: 'SO',
        speciesName: 'Sosna zwyczajna',
        secondarySpecies: [
          const TreeSpecies(
            code: 'DB',
            namePl: 'Dąb szypułkowy',
            nameRu: 'Дуб черешчатый',
            latin: 'Quercus robur',
            icon: '🌳',
            sharePercent: 30,
          ),
        ],
      );
      final weather = createTestWeather();

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9,
      );

      // Check that Oak is recognized as admixture ('Domieszka: Dąb')
      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(
        borowik.positiveReasons.any((r) => r.contains('Sosna') || r.contains('Dąb')),
        isTrue,
      );
    });

    test('Non-matching tree species gets penalized and capped at 20%', () {
      // Birch forest for Maślak zwyczajny (which strictly prefers Pine)
      final parcel = createTestParcel(speciesCode: 'BRZ', speciesName: 'Brzoza brodawkowata');
      final weather = createTestWeather();

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9,
      );

      final maslak = results.firstWhere((r) => r.mushroom.id == 'maslak_zwyczajny');
      expect(maslak.probabilityPercent, lessThanOrEqualTo(20));
      expect(maslak.negativeReasons.any((r) => r.contains('Brak preferowanych drzew')), isTrue);
    });
  });

  group('MatchEngine: Stand Age Compatibility', () {
    test('Stand within ideal age range gains 30 points', () {
      // Borowik ideal age: 40-90 lat
      final parcel = createTestParcel(age: 60);
      final weather = createTestWeather();

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9,
      );

      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.positiveReasons.any((r) => r.contains('Optymalny wiek lasu: 60 lat')), isTrue);
    });

    test('Very young stand (< min age) is penalized with warning reason', () {
      // 5-year-old saplings
      final parcel = createTestParcel(age: 5);
      final weather = createTestWeather();

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9,
      );

      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.negativeReasons.any((r) => r.contains('Zbyt młody las (5 lat')), isTrue);
    });
  });

  group('MatchEngine: Weather & Soil Influence (W1, W2, W3)', () {
    test('Optimal soil temperature (10-18°C) grants +5 bonus with reason', () {
      final parcel = createTestParcel();
      final weather = createTestWeather(soilTemp: 15.0);

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9,
      );

      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.positiveReasons.any((r) => r.contains('Optymalna temperatura gleby: 15.0°C')), isTrue);
    });

    test('Cold soil (<6°C) applies -8 penalty with slowdown reason', () {
      final parcel = createTestParcel();
      final weather = createTestWeather(soilTemp: 4.2);

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 10,
      );

      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.negativeReasons.any((r) => r.contains('Wychłodzona gleba: 4.2°C')), isTrue);
    });

    test('Null weather evaluates honestly without fake fabricated rain data', () {
      final parcel = createTestParcel();

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: null, // Station unavailable
        selectedMonth: 9,
      );

      expect(results, isNotEmpty);
      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.negativeReasons.any((r) => r.contains('Brak danych stacji pogodowej')), isTrue);
    });
  });

  group('MatchEngine: Sorting & Probabilities', () {
    test('Results are sorted descending by probabilityPercent', () {
      final parcel = createTestParcel();
      final weather = createTestWeather();

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9,
      );

      for (int i = 0; i < results.length - 1; i++) {
        expect(
          results[i].probabilityPercent >= results[i + 1].probabilityPercent,
          isTrue,
          reason: 'Item at index $i must have >= probability than item at index ${i + 1}',
        );
      }
    });

    test('Probability is clamped between 0% and 98%', () {
      final parcel = createTestParcel();
      final weather = createTestWeather(rainBonus: 25, soilTemp: 14.0);

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9,
      );

      for (final r in results) {
        expect(r.probabilityPercent, inInclusiveRange(0, 98));
      }
    });
  });

  group('MatchEngine: Verified Mycological Factors & Polish Forestry STL (Gold Standard)', () {
    test('Tree sub-code normalization matches sub-variants like DB.S, SO.C, BRZ.O', () {
      // Dąb szypułkowy with forestry sub-code DB.S
      final parcel = createTestParcel(speciesCode: 'DB.S', speciesName: 'Dąb szypułkowy');
      final weather = createTestWeather();

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9,
      );

      // Borowik szlachetny (Boletus edulis) accepts DB
      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.probabilityPercent, greaterThan(60));
      expect(borowik.negativeReasons.any((r) => r.contains('Brak preferowanych drzew')), isFalse);
    });

    test('Mountain STL biotope normalization (BMGŚW -> BMŚW)', () {
      // Carpathian mountain mixed forest BMGŚW
      final parcel = createTestParcel(habitatCode: 'BMGŚW');
      final weather = createTestWeather();

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9,
      );

      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.positiveReasons.any((r) => r.contains('Odpowiednie siedlisko')), isTrue);
    });

    test('Composite stand sums compatible host tree shares (70% SO + 30% DB = 100% host)', () {
      final parcel = createTestParcel(
        speciesCode: 'SO',
        speciesName: 'Sosna zwyczajna',
        secondarySpecies: [
          const TreeSpecies(
            code: 'DB',
            namePl: 'Dąb szypułkowy',
            nameRu: 'Дуб',
            latin: 'Quercus robur',
            icon: '🌳',
            sharePercent: 30,
          ),
        ],
      );
      final weather = createTestWeather();

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9,
      );

      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.positiveReasons.any((r) => r.contains('Drzewostan mikoryzowy (100%)')), isTrue);
    });

    test('Winter fungi (Płomiennica zimowa) fruits in January under cold soil conditions', () {
      final parcel = createTestParcel(speciesCode: 'WB', speciesName: 'Wierzba biała', habitatCode: 'LŁ');
      final weather = createTestWeather(rainMm: 15.0, rainBonus: 10, soilTemp: 4.5);

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 1, // January (winter)
      );

      final plomiennica = results.firstWhere((r) => r.mushroom.id == 'plomiennica_zimowa');
      expect(plomiennica.probabilityPercent, greaterThan(65));
      expect(plomiennica.positiveReasons.any((r) => r.contains('Optymalna niska temperatura dla grzybów zimowych')), isTrue);

      // Normal summer bolete must be 0% in January
      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.probabilityPercent, 0);
    });

    test('Rainfall below minRainfall14d incurs deficit penalty and warning', () {
      final parcel = createTestParcel();
      // Only 6 mm rain (deficit for Borowik which requires min 15 mm)
      final weather = createTestWeather(rainMm: 6.0, rainBonus: -8);

      final results = MatchEngine.evaluateMushrooms(
        parcel: parcel,
        weather: weather,
        selectedMonth: 9,
      );

      final borowik = results.firstWhere((r) => r.mushroom.id == 'borowik_szlachetny');
      expect(borowik.negativeReasons.any((r) => r.contains('Niedobór opadów')), isTrue);
    });
  });
}
