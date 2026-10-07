import 'package:flutter/material.dart';

class TreeSpecies {
  final String code;
  final String namePl;
  final String nameRu;
  final String latin;
  final String icon;
  final int sharePercent;

  const TreeSpecies({
    required this.code,
    required this.namePl,
    required this.nameRu,
    required this.latin,
    required this.icon,
    this.sharePercent = 100,
  });
}

class ForestHabitat {
  final String code;
  final String namePl;
  final String descPl;
  final String moisture;

  const ForestHabitat({
    required this.code,
    required this.namePl,
    required this.descPl,
    required this.moisture,
  });
}

enum ForestLegalStatus { allowed, protective, forbidden }

class ForestStatus {
  final String code;
  final ForestLegalStatus status;
  final String labelPl;
  final Color color;

  const ForestStatus({
    required this.code,
    required this.status,
    required this.labelPl,
    required this.color,
  });
}

class ForestParcel {
  final String subareaId;
  final String address;
  final TreeSpecies primarySpecies;
  final List<TreeSpecies> secondarySpecies;
  final int ageYears;
  final String ageCategory;
  final ForestHabitat habitat;
  final ForestStatus status;
  final String? areaHa;
  final String inspectorate;
  final double latitude;
  final double longitude;

  const ForestParcel({
    required this.subareaId,
    required this.address,
    required this.primarySpecies,
    this.secondarySpecies = const [],
    required this.ageYears,
    required this.ageCategory,
    required this.habitat,
    required this.status,
    this.areaHa,
    required this.inspectorate,
    required this.latitude,
    required this.longitude,
  });

  /// All tree species present in this forest stand, starting with primary.
  List<TreeSpecies> get allSpecies => [primarySpecies, ...secondarySpecies];

  /// Human-readable stand composition summary, e.g. "🌲 Sosna (70%), 🌳 Brzoza (30%)"
  String get compositionSummary {
    return allSpecies
        .map((s) => '${s.icon} ${s.namePl} (${s.sharePercent}%)')
        .join(', ');
  }
}
