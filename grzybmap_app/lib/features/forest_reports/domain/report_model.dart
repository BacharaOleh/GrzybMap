import 'package:flutter/material.dart';

enum ForestReportCategory {
  trash,
  fallenTree,
  fireHazard,
  vandalism;

  String get id {
    switch (this) {
      case ForestReportCategory.trash:
        return 'trash';
      case ForestReportCategory.fallenTree:
        return 'fallen_tree';
      case ForestReportCategory.fireHazard:
        return 'fire_hazard';
      case ForestReportCategory.vandalism:
        return 'vandalism';
    }
  }

  String get labelPl {
    switch (this) {
      case ForestReportCategory.trash:
        return 'Dzikie wysypisko śmieci';
      case ForestReportCategory.fallenTree:
        return 'Wiatrołom na drodze pożarowej';
      case ForestReportCategory.fireHazard:
        return 'Dym / Zagrożenie pożarowe';
      case ForestReportCategory.vandalism:
        return 'Zniszczona infrastruktura leśna';
    }
  }

  String get shortLabel {
    switch (this) {
      case ForestReportCategory.trash:
        return 'Śmieci';
      case ForestReportCategory.fallenTree:
        return 'Wiatrołom';
      case ForestReportCategory.fireHazard:
        return 'Ogień/Dym';
      case ForestReportCategory.vandalism:
        return 'Infrastruktura';
    }
  }

  IconData get iconData {
    switch (this) {
      case ForestReportCategory.trash:
        return Icons.delete_outline_rounded;
      case ForestReportCategory.fallenTree:
        return Icons.forest_rounded;
      case ForestReportCategory.fireHazard:
        return Icons.local_fire_department_rounded;
      case ForestReportCategory.vandalism:
        return Icons.warning_amber_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ForestReportCategory.trash:
        return const Color(0xFFEF4444);
      case ForestReportCategory.fallenTree:
        return const Color(0xFFF59E0B);
      case ForestReportCategory.fireHazard:
        return const Color(0xFFDC2626);
      case ForestReportCategory.vandalism:
        return const Color(0xFFFB923C);
    }
  }

  static ForestReportCategory fromString(String val) {
    switch (val.toLowerCase()) {
      case 'trash':
        return ForestReportCategory.trash;
      case 'fallen_tree':
      case 'fallentree':
        return ForestReportCategory.fallenTree;
      case 'fire_hazard':
      case 'firehazard':
        return ForestReportCategory.fireHazard;
      case 'vandalism':
        return ForestReportCategory.vandalism;
      default:
        return ForestReportCategory.trash;
    }
  }
}

enum ForestReportStatus {
  pending,
  verified,
  inProgress,
  resolved;

  String get labelPl {
    switch (this) {
      case ForestReportStatus.pending:
        return 'Oczekuje';
      case ForestReportStatus.verified:
        return 'Zweryfikowane';
      case ForestReportStatus.inProgress:
        return 'W realizacji (ZUL)';
      case ForestReportStatus.resolved:
        return 'Rozwiązane';
    }
  }

  Color get color {
    switch (this) {
      case ForestReportStatus.pending:
        return const Color(0xFF94A3B8);
      case ForestReportStatus.verified:
        return const Color(0xFF38BDF8);
      case ForestReportStatus.inProgress:
        return const Color(0xFFF59E0B);
      case ForestReportStatus.resolved:
        return const Color(0xFF10B981);
    }
  }

  static ForestReportStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'verified':
        return ForestReportStatus.verified;
      case 'in_progress':
      case 'inprogress':
        return ForestReportStatus.inProgress;
      case 'resolved':
        return ForestReportStatus.resolved;
      default:
        return ForestReportStatus.pending;
    }
  }
}

/// Domain model representing an environmental or infrastructure incident
/// reported by forest visitors to the State Forests (Nadleśnictwo).
class ForestReport {
  final String id;
  final ForestReportCategory category;
  final double latitude;
  final double longitude;
  final String nadlesnictwo;
  final String oddzial;
  final String description;
  final String? photoUrl;
  final String? photoBase64;
  final ForestReportStatus status;
  final DateTime createdAt;
  final int confirmationsCount;

  const ForestReport({
    required this.id,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.nadlesnictwo,
    required this.oddzial,
    required this.description,
    this.photoUrl,
    this.photoBase64,
    this.status = ForestReportStatus.pending,
    required this.createdAt,
    this.confirmationsCount = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.id,
        'latitude': latitude,
        'longitude': longitude,
        'nadlesnictwo': nadlesnictwo,
        'oddzial': oddzial,
        'description': description,
        'photoUrl': photoUrl,
        'photoBase64': photoBase64,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'confirmationsCount': confirmationsCount,
      };

  factory ForestReport.fromJson(Map<String, dynamic> json) {
    return ForestReport(
      id: json['id'] as String? ?? '',
      category: ForestReportCategory.fromString(json['category'] as String? ?? 'trash'),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      nadlesnictwo: json['nadlesnictwo'] as String? ?? '',
      oddzial: json['oddzial'] as String? ?? '',
      description: json['description'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      photoBase64: json['photoBase64'] as String?,
      status: ForestReportStatus.fromString(json['status'] as String? ?? 'pending'),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      confirmationsCount: (json['confirmationsCount'] as num?)?.toInt() ?? 1,
    );
  }
}
