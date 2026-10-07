import 'dart:math';
import 'package:flutter/material.dart';
import '../../parcel_inspector/domain/models.dart';
import '../../weather/domain/models.dart';
import '../domain/models.dart';
import '../data/mushroom_database.dart';

class MatchEngine {
  static int _monthDistance(int m1, int m2) {
    final diff = (m1 - m2).abs();
    return min(diff, 12 - diff);
  }

  static int _distanceToSeason(int month, List<int> season) {
    if (season.contains(month)) return 0;
    int minD = 12;
    for (final sm in season) {
      final d = _monthDistance(month, sm);
      if (d < minD) minD = d;
    }
    return minD;
  }

  static String _monthNamePl(int month) {
    const names = [
      '',
      'Styczniu',
      'Lutym',
      'Marcu',
      'Kwietniu',
      'Maju',
      'Czerwcu',
      'Lipcu',
      'Sierpniu',
      'Wrześniu',
      'Październiku',
      'Listopadzie',
      'Grudniu',
    ];
    return month >= 1 && month <= 12 ? names[month] : 'tym miesiącu';
  }

  static String _formatSeason(List<int> months) {
    const nominative = [
      '',
      'Sty',
      'Lut',
      'Mar',
      'Kwi',
      'Maj',
      'Cze',
      'Lip',
      'Sie',
      'Wrz',
      'Paź',
      'Lis',
      'Gru',
    ];
    if (months.isEmpty) return '';
    final sorted = List<int>.from(months)..sort();
    if (sorted.length == 1) return nominative[sorted.first];
    return '${nominative[sorted.first]}–${nominative[sorted.last]}';
  }

  /// Computes ranked list of mushrooms with smooth probability and rationale
  static List<MushroomMatchResult> evaluateMushrooms({
    required ForestParcel parcel,
    required WeatherRainfall? weather,
    required int selectedMonth,
  }) {
    final speciesCode = parcel.primarySpecies.code.trim().toUpperCase();
    final speciesAge = parcel.ageYears;
    final habitatCode = parcel.habitat.code.trim().toUpperCase();
    final rainBonus = weather?.rainBonusScore ?? 0;

    final results = MushroomDatabase.allMushrooms.map((mush) {
      final positiveReasons = <String>[];
      final negativeReasons = <String>[];

      // Check season distance
      final seasonDistance = _distanceToSeason(selectedMonth, mush.seasonMonths);

      // 1. Seasonality check (deep off-season must be 0%)
      if (seasonDistance >= 2) {
        return MushroomMatchResult(
          mushroom: mush,
          probabilityPercent: 0,
          chanceCategory: 'Poza sezonem (0%)',
          chanceColor: const Color(0xFF6B7280), // Neutral gray
          positiveReasons: [],
          negativeReasons: [
            'Brak owocowania w ${_monthNamePl(selectedMonth)} (sezon: ${_formatSeason(mush.seasonMonths)})',
            if (!mush.preferredTrees.contains(speciesCode))
              'Rzadziej pod: ${parcel.primarySpecies.namePl}',
          ],
        );
      }

      double seasonScore = 0;
      if (seasonDistance == 0) {
        seasonScore = 15.0;
        positiveReasons.add('Aktywny naturalny sezon owocowania');
      } else {
        // 1 month away from season: rare early/late occurrences
        seasonScore = -10.0;
        negativeReasons.add('Kraniec sezonu (pojedyncze, rzadkie okazy)');
      }

      // 2. Tree Species Compatibility (Max 40 points, evaluating composite stands)
      TreeSpecies? bestTree;
      double bestTreeScore = 0;

      for (final sp in parcel.allSpecies) {
        final code = sp.code.trim().toUpperCase();
        if (mush.preferredTrees.contains(code)) {
          final spShare = sp.sharePercent / 100.0;
          final score = mush.treeWeight * spShare;
          if (score > bestTreeScore) {
            bestTreeScore = score;
            bestTree = sp;
          }
        }
      }

      double treeScore = 0;
      final isPreferredTree = bestTree != null;

      if (isPreferredTree) {
        treeScore = bestTreeScore;
        final isPrimary = bestTree == parcel.primarySpecies;
        positiveReasons.add(
          isPrimary
              ? 'Drzewostan główny: ${bestTree.namePl} (${bestTree.sharePercent}%)'
              : 'Domieszka: ${bestTree.namePl} (${bestTree.sharePercent}%)',
        );
      } else {
        treeScore = 2.0;
        negativeReasons.add(
          'Brak preferowanych drzew (wymaga: ${mush.preferredTrees.join(", ")})',
        );
      }

      // 3. Stand Age Compatibility (Max 30 points)
      double ageScore = 0;
      final ageRange = mush.preferredAge;
      if (speciesAge >= ageRange.idealMin && speciesAge <= ageRange.idealMax) {
        ageScore = 30.0;
        positiveReasons.add(
          'Optymalny wiek lasu: $speciesAge lat (${ageRange.idealMin}–${ageRange.idealMax})',
        );
      } else if (speciesAge >= ageRange.min && speciesAge <= ageRange.max) {
        ageScore = 18.0;
        positiveReasons.add('Wiek odpowiedni: $speciesAge lat');
      } else if (speciesAge < ageRange.min) {
        ageScore = 2.0;
        negativeReasons.add(
          'Zbyt młody las ($speciesAge lat, preferuje min. ${ageRange.min})',
        );
      } else {
        ageScore = 6.0;
        negativeReasons.add('Przejrzały starodrzew ($speciesAge lat)');
      }

      // 4. Habitat Soil Compatibility (Max 15 points)
      double habitatScore = 0;
      if (mush.preferredHabitats.contains(habitatCode)) {
        habitatScore = 15.0;
        positiveReasons.add(
          'Odpowiednie siedlisko: ${parcel.habitat.namePl}',
        );
      } else {
        habitatScore = 3.0;
      }

      // Initial raw score calculation
      double rawScore =
          treeScore + ageScore + habitatScore + seasonScore + rainBonus;

      // 5. Weather & Soil conditions (W1 & W2)
      if (weather == null) {
        negativeReasons.add('Brak danych stacji pogodowej (ocena neutralna)');
      } else {
        // Rainfall influence (14 days accumulation)
        if (rainBonus >= 10) {
          positiveReasons.add(
            'Obfite opady (14 dni): ${weather.totalRainMm.toStringAsFixed(1)} mm (+$rainBonus pkt)',
          );
        } else if (rainBonus <= -5) {
          negativeReasons.add(
            'Przesuszona ściółka (14 dni): ${weather.totalRainMm.toStringAsFixed(1)} mm ($rainBonus pkt)',
          );
        }

        // Soil temperature (6cm depth)
        if (weather.soilTempC != null) {
          final temp = weather.soilTempC!;
          if (temp >= 10.0 && temp <= 18.0) {
            positiveReasons.add(
              'Optymalna temperatura gleby: ${temp.toStringAsFixed(1)}°C (+5 pkt)',
            );
            rawScore += 5.0;
          } else if (temp < 6.0) {
            negativeReasons.add(
              'Wychłodzona gleba: ${temp.toStringAsFixed(1)}°C (spowolniony wzrost)',
            );
            rawScore -= 8.0;
          } else if (temp > 24.0) {
            negativeReasons.add('Przegrzana gleba: ${temp.toStringAsFixed(1)}°C');
            rawScore -= 5.0;
          }
        }

        // Soil surface moisture
        if (weather.soilMoistureM3 != null) {
          final moist = weather.soilMoistureM3!;
          if (moist >= 0.28) {
            positiveReasons.add(
              'Dobre nawilżenie podłoża (${weather.soilMoisturePercent})',
            );
          } else if (moist < 0.16) {
            negativeReasons.add(
              'Sucha wierzchnia warstwa gleby (${weather.soilMoisturePercent})',
            );
          }
        }
      }

      // Heavy penalties for fundamental mismatch
      if (seasonDistance == 1) {
        rawScore = min(rawScore, 18.0);
      }
      if (!isPreferredTree) {
        rawScore = min(rawScore, 20.0);
      }

      // Clamp between 0% and 98% (no artificial 5% floor)
      final probability = max(0, min(98, rawScore.round()));

      String chanceCategory = 'Niska';
      Color chanceColor = const Color(0xFFEF4444); // Red

      if (probability >= 75) {
        chanceCategory = 'Bardzo wysoka szansa!';
        chanceColor = const Color(0xFF10B981); // Emerald
      } else if (probability >= 50) {
        chanceCategory = 'Dobra szansa';
        chanceColor = const Color(0xFF34D399); // Light green
      } else if (probability >= 25) {
        chanceCategory = 'Umiarkowana szansa';
        chanceColor = const Color(0xFFFBBF24); // Amber
      } else if (probability > 0) {
        chanceCategory = 'Niska szansa';
        chanceColor = const Color(0xFFF87171); // Light red
      } else {
        chanceCategory = 'Brak szans (0%)';
        chanceColor = const Color(0xFF6B7280); // Gray
      }

      return MushroomMatchResult(
        mushroom: mush,
        probabilityPercent: probability,
        chanceCategory: chanceCategory,
        chanceColor: chanceColor,
        positiveReasons: positiveReasons,
        negativeReasons: negativeReasons,
      );
    }).toList();

    // Sort descending by probability
    results.sort((a, b) => b.probabilityPercent.compareTo(a.probabilityPercent));
    return results;
  }
}
