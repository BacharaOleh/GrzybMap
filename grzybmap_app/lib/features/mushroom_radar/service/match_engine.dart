import 'dart:math';
import 'package:flutter/material.dart';
import '../../parcel_inspector/domain/models.dart';
import '../../weather/domain/models.dart';
import '../domain/models.dart';
import '../data/mushroom_database.dart';

/// Deterministic Mycological Ecological Niche & Habitat Suitability Engine.
///
/// Implements 5-factor scoring verified against Polish State Forests (BDL)
/// and forestry research (IBL):
/// 1. Host Tree Mycorrhiza (tree species compatibility + composite stand algebra)
/// 2. Stand Age (ideal maturity brackets)
/// 3. Forest Habitat STL (lowland, upland, and mountain biotope normalization)
/// 4. Seasonality (12-month ring modular distance with 0% hard floor)
/// 5. Hydrothermal Soil & Rain Dynamics (14-day rainfall curve + 6cm soil temp)
class MatchEngine {
  /// Normalizes all 45+ BDL tree species codes into canonical mycorrhizal groups
  /// (e.g. "DB.S", "DB.B", "DB.C", "DĄB" -> "DB", "SO.C", "SO.B" -> "SO").
  static String getBaseSpeciesCode(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    if (code == 'DĄB' || code.startsWith('DB')) return 'DB';
    if (code.startsWith('SO')) return 'SO';
    if (code.startsWith('ŚW')) return 'ŚW';
    if (code.startsWith('BRZ')) return 'BRZ';
    if (code.startsWith('JD')) return 'JD';
    if (code.startsWith('MD')) return 'MD';
    if (code.startsWith('OL')) return 'OL';
    if (code.startsWith('BK')) return 'BK';
    if (code.startsWith('GB')) return 'GB';
    if (code.startsWith('OS')) return 'OS';
    if (code.startsWith('LP') || code.startsWith('LIP')) return 'LP';
    if (code.startsWith('WZ') || code.startsWith('WIĄZ')) return 'WZ';
    if (code.startsWith('TP')) return 'TP';
    if (code.startsWith('WB') || code.startsWith('WIERZ')) return 'WB';
    if (code.startsWith('KL')) return 'KL';
    if (code.startsWith('JS')) return 'JS';
    if (code.startsWith('JRZ')) return 'JRZ';
    if (code.startsWith('CZRM')) return 'CZRM';
    return code.contains('.') ? code.split('.').first : code;
  }

  /// Normalizes upland and mountain STL variants to base habitat equivalents
  /// (e.g. BMGŚW, BMWYŻŚW -> BMŚW, LMGŚW, LMWYŻŚW -> LMŚW).
  static String getBaseHabitatCode(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    final stripped = code.replaceAll('WYŻ', '').replaceAll('G', '');
    return stripped.isNotEmpty ? stripped : code;
  }

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

  /// Computes ranked list of mushrooms with verified ecological suitability.
  static List<MushroomMatchResult> evaluateMushrooms({
    required ForestParcel parcel,
    required WeatherRainfall? weather,
    required int selectedMonth,
  }) {
    final speciesAge = parcel.ageYears;
    final rainBonus = weather?.rainBonusScore ?? 0;

    final results = MushroomDatabase.allMushrooms.map((mush) {
      final positiveReasons = <String>[];
      final negativeReasons = <String>[];

      // Check modular 12-month season distance
      final seasonDistance = _distanceToSeason(selectedMonth, mush.seasonMonths);

      // 1. Seasonality check (deep off-season >= 2 months must be strictly 0%)
      if (seasonDistance >= 2) {
        return MushroomMatchResult(
          mushroom: mush,
          probabilityPercent: 0,
          chanceCategory: 'Poza sezonem (0%)',
          chanceColor: const Color(0xFF6B7280), // Neutral gray
          positiveReasons: [],
          negativeReasons: [
            'Brak owocowania w ${_monthNamePl(selectedMonth)} (sezon: ${_formatSeason(mush.seasonMonths)})',
            if (!mush.preferredTrees.contains(getBaseSpeciesCode(parcel.primarySpecies.code)))
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
      double compatibleShare = 0.0;
      final matchingSpeciesList = <TreeSpecies>[];

      for (final sp in parcel.allSpecies) {
        final rawCode = sp.code.trim().toUpperCase();
        final baseCode = getBaseSpeciesCode(rawCode);
        if (mush.preferredTrees.contains(baseCode) || mush.preferredTrees.contains(rawCode)) {
          compatibleShare += sp.sharePercent / 100.0;
          matchingSpeciesList.add(sp);
        }
      }

      double treeScore = 0;
      final isPreferredTree = matchingSpeciesList.isNotEmpty;

      if (isPreferredTree) {
        compatibleShare = min(1.0, compatibleShare);
        treeScore = mush.treeWeight * compatibleShare;

        final isOnlyPrimary = matchingSpeciesList.length == 1 &&
            matchingSpeciesList.first.code == parcel.primarySpecies.code;

        if (isOnlyPrimary) {
          positiveReasons.add(
            'Drzewostan główny: ${parcel.primarySpecies.namePl} (${parcel.primarySpecies.sharePercent}%)',
          );
        } else {
          final treeNames = matchingSpeciesList
              .map((s) => '${s.namePl} (${s.sharePercent}%)')
              .join(', ');
          positiveReasons.add(
            'Drzewostan mikoryzowy (${(compatibleShare * 100).round()}%): $treeNames',
          );
        }
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

      // 4. Habitat Soil Compatibility (Max 15 points, normalized for lowland & mountain STL)
      double habitatScore = 0;
      final rawHabitatCode = parcel.habitat.code.trim().toUpperCase();
      final baseHabitatCode = getBaseHabitatCode(rawHabitatCode);

      final isHabitatMatch = mush.preferredHabitats.contains(rawHabitatCode) ||
          mush.preferredHabitats.contains(baseHabitatCode);

      if (isHabitatMatch) {
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

        // Species-specific rainfall requirement check
        if (weather.totalRainMm < mush.minRainfall14d) {
          final deficit = mush.minRainfall14d - weather.totalRainMm;
          final deficitPenalty = min(8.0, (deficit / mush.minRainfall14d) * 10.0);
          rawScore -= deficitPenalty;
          negativeReasons.add(
            'Niedobór opadów (min. ${mush.minRainfall14d.toStringAsFixed(0)} mm, odnotowano ${weather.totalRainMm.toStringAsFixed(1)} mm)',
          );
        }

        // Soil temperature (6cm depth) with cold-tolerant fungi handling
        if (weather.soilTempC != null) {
          final temp = weather.soilTempC!;
          if (mush.isColdTolerant) {
            // Winter fungi (e.g. Flammulina velutipes, Pleurotus ostreatus) thrive in cold
            if (temp >= 1.0 && temp <= 9.0) {
              positiveReasons.add(
                'Optymalna niska temperatura dla grzybów zimowych: ${temp.toStringAsFixed(1)}°C (+6 pkt)',
              );
              rawScore += 6.0;
            } else if (temp > 16.0) {
              negativeReasons.add('Zbyt ciepło dla grzybów zimowych: ${temp.toStringAsFixed(1)}°C');
              rawScore -= 8.0;
            }
          } else {
            // Normal summer/autumn fungi
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
