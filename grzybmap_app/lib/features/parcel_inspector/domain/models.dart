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

  Map<String, dynamic> toMap() => {
        'code': code,
        'namePl': namePl,
        'nameRu': nameRu,
        'latin': latin,
        'icon': icon,
        'sharePercent': sharePercent,
      };

  factory TreeSpecies.fromMap(Map<String, dynamic> map) {
    return TreeSpecies(
      code: map['code'] as String? ?? '',
      namePl: map['namePl'] as String? ?? '',
      nameRu: map['nameRu'] as String? ?? '',
      latin: map['latin'] as String? ?? '',
      icon: map['icon'] as String? ?? '🌲',
      sharePercent: (map['sharePercent'] as num?)?.toInt() ?? 100,
    );
  }
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

  Map<String, dynamic> toMap() => {
        'code': code,
        'namePl': namePl,
        'descPl': descPl,
        'moisture': moisture,
      };

  factory ForestHabitat.fromMap(Map<String, dynamic> map) {
    return ForestHabitat(
      code: map['code'] as String? ?? '',
      namePl: map['namePl'] as String? ?? '',
      descPl: map['descPl'] as String? ?? '',
      moisture: map['moisture'] as String? ?? 'optimal',
    );
  }
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

  Map<String, dynamic> toMap() => {
        'code': code,
        'status': status.name,
        'labelPl': labelPl,
        'color': color.toARGB32(),
      };

  factory ForestStatus.fromMap(Map<String, dynamic> map) {
    final statusName = map['status'] as String? ?? 'allowed';
    final legalStatus = ForestLegalStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => ForestLegalStatus.allowed,
    );
    final colorVal = map['color'] as int?;
    return ForestStatus(
      code: map['code'] as String? ?? 'GOSP',
      status: legalStatus,
      labelPl: map['labelPl'] as String? ?? 'Las gospodarczy',
      color: colorVal != null ? Color(colorVal) : Colors.green,
    );
  }
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

  Map<String, dynamic> toMap() => {
        'subareaId': subareaId,
        'address': address,
        'primarySpecies': primarySpecies.toMap(),
        'secondarySpecies': secondarySpecies.map((s) => s.toMap()).toList(),
        'ageYears': ageYears,
        'ageCategory': ageCategory,
        'habitat': habitat.toMap(),
        'status': status.toMap(),
        'areaHa': areaHa,
        'inspectorate': inspectorate,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory ForestParcel.fromMap(Map<String, dynamic> map) {
    return ForestParcel(
      subareaId: map['subareaId'] as String? ?? '',
      address: map['address'] as String? ?? '',
      primarySpecies: TreeSpecies.fromMap(
        map['primarySpecies'] as Map<String, dynamic>? ?? const {},
      ),
      secondarySpecies: (map['secondarySpecies'] as List<dynamic>?)
              ?.map((item) => TreeSpecies.fromMap(item as Map<String, dynamic>))
              .toList() ??
          const [],
      ageYears: (map['ageYears'] as num?)?.toInt() ?? 0,
      ageCategory: map['ageCategory'] as String? ?? '',
      habitat: ForestHabitat.fromMap(
        map['habitat'] as Map<String, dynamic>? ?? const {},
      ),
      status: ForestStatus.fromMap(
        map['status'] as Map<String, dynamic>? ?? const {},
      ),
      areaHa: map['areaHa'] as String?,
      inspectorate: map['inspectorate'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
