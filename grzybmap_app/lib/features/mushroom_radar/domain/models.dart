import 'package:flutter/material.dart';

class LookalikeFeature {
  final String featureName;
  final String edibleCharacteristic;
  final String lookalikeCharacteristic;
  final bool isCritical;

  const LookalikeFeature({
    required this.featureName,
    required this.edibleCharacteristic,
    required this.lookalikeCharacteristic,
    this.isCritical = false,
  });
}

class MushroomLookalike {
  final String namePl;
  final String latin;
  final bool isLethal;
  final String warningPl;
  final String? photoAsset;
  final List<LookalikeFeature> features;

  const MushroomLookalike({
    required this.namePl,
    required this.latin,
    required this.isLethal,
    required this.warningPl,
    this.photoAsset,
    this.features = const [],
  });
}

class MushroomAgeRange {
  final int min;
  final int idealMin;
  final int idealMax;
  final int max;

  const MushroomAgeRange({
    required this.min,
    required this.idealMin,
    required this.idealMax,
    required this.max,
  });
}

class Mushroom {
  final String id;
  final String namePl;
  final String nameRu;
  final String latin;
  final String badge;
  final String edibility;
  final Color edibilityColor;
  final List<String> preferredTrees;
  final int treeWeight;
  final MushroomAgeRange preferredAge;
  final List<String> preferredHabitats;
  final List<int> seasonMonths;
  final double minRainfall14d;
  final String descriptionPl;
  final String tipsPl;
  final MushroomLookalike? lookalike;
  final bool isColdTolerant;
  final String? photoAsset;

  const Mushroom({
    required this.id,
    required this.namePl,
    required this.nameRu,
    required this.latin,
    required this.badge,
    required this.edibility,
    required this.edibilityColor,
    required this.preferredTrees,
    required this.treeWeight,
    required this.preferredAge,
    required this.preferredHabitats,
    required this.seasonMonths,
    required this.minRainfall14d,
    required this.descriptionPl,
    required this.tipsPl,
    this.lookalike,
    this.isColdTolerant = false,
    this.photoAsset,
  });
}

class MushroomMatchResult {
  final Mushroom mushroom;
  final int probabilityPercent;
  final String chanceCategory;
  final Color chanceColor;
  final List<String> positiveReasons;
  final List<String> negativeReasons;

  const MushroomMatchResult({
    required this.mushroom,
    required this.probabilityPercent,
    required this.chanceCategory,
    required this.chanceColor,
    required this.positiveReasons,
    required this.negativeReasons,
  });
}
