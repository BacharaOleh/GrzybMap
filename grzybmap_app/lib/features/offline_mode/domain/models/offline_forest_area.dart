import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../parcel_inspector/domain/models.dart';
import '../../../weather/domain/models.dart';

/// Lightweight summary of a downloaded offline forest area for fast list rendering.
@immutable
class OfflineForestAreaSummary {
  final String id;
  final String name;
  final DateTime downloadedAt;
  final double centerLat;
  final double centerLng;
  final double radiusKm;
  final int parcelsCount;
  final int sizeBytes;
  final double weatherRainMm;

  const OfflineForestAreaSummary({
    required this.id,
    required this.name,
    required this.downloadedAt,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
    required this.parcelsCount,
    required this.sizeBytes,
    required this.weatherRainMm,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    final day = downloadedAt.day.toString().padLeft(2, '0');
    final month = downloadedAt.month.toString().padLeft(2, '0');
    final year = downloadedAt.year;
    final hour = downloadedAt.hour.toString().padLeft(2, '0');
    final minute = downloadedAt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'downloadedAt': downloadedAt.toIso8601String(),
        'centerLat': centerLat,
        'centerLng': centerLng,
        'radiusKm': radiusKm,
        'parcelsCount': parcelsCount,
        'sizeBytes': sizeBytes,
        'weatherRainMm': weatherRainMm,
      };

  factory OfflineForestAreaSummary.fromMap(Map<String, dynamic> map) {
    return OfflineForestAreaSummary(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Obszar leśny',
      downloadedAt: DateTime.tryParse(map['downloadedAt'] as String? ?? '') ??
          DateTime.now(),
      centerLat: (map['centerLat'] as num?)?.toDouble() ?? 0.0,
      centerLng: (map['centerLng'] as num?)?.toDouble() ?? 0.0,
      radiusKm: (map['radiusKm'] as num?)?.toDouble() ?? 5.0,
      parcelsCount: (map['parcelsCount'] as num?)?.toInt() ?? 0,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      weatherRainMm: (map['weatherRainMm'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory OfflineForestAreaSummary.fromJson(String source) =>
      OfflineForestAreaSummary.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Full Offline Forest Area containing parcels and weather snapshot.
/// Guarantees 100% hermetic offline scoring without network connectivity.
@immutable
class OfflineForestArea {
  final String id;
  final String name;
  final DateTime downloadedAt;
  final double centerLat;
  final double centerLng;
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;
  final double radiusKm;
  final int parcelsCount;
  final int sizeBytes;
  final WeatherRainfall weatherSnapshot;
  final List<ForestParcel> parcels;

  const OfflineForestArea({
    required this.id,
    required this.name,
    required this.downloadedAt,
    required this.centerLat,
    required this.centerLng,
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
    required this.radiusKm,
    required this.parcelsCount,
    required this.sizeBytes,
    required this.weatherSnapshot,
    required this.parcels,
  });

  /// Checks whether a given coordinate falls within this offline area bounding box.
  /// An optional buffer (in degrees, ~0.01 deg ≈ 1.1 km) accommodates near-boundary inspections.
  bool contains(double lat, double lng, {double bufferDeg = 0.005}) {
    return lat >= (minLat - bufferDeg) &&
        lat <= (maxLat + bufferDeg) &&
        lng >= (minLng - bufferDeg) &&
        lng <= (maxLng + bufferDeg);
  }

  OfflineForestAreaSummary toSummary() {
    return OfflineForestAreaSummary(
      id: id,
      name: name,
      downloadedAt: downloadedAt,
      centerLat: centerLat,
      centerLng: centerLng,
      radiusKm: radiusKm,
      parcelsCount: parcelsCount,
      sizeBytes: sizeBytes,
      weatherRainMm: weatherSnapshot.totalRainMm,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'downloadedAt': downloadedAt.toIso8601String(),
        'centerLat': centerLat,
        'centerLng': centerLng,
        'minLat': minLat,
        'minLng': minLng,
        'maxLat': maxLat,
        'maxLng': maxLng,
        'radiusKm': radiusKm,
        'parcelsCount': parcelsCount,
        'sizeBytes': sizeBytes,
        'weatherSnapshot': weatherSnapshot.toMap(),
        'parcels': parcels.map((p) => p.toMap()).toList(),
      };

  factory OfflineForestArea.fromMap(Map<String, dynamic> map) {
    final rawParcels = map['parcels'] as List<dynamic>? ?? const [];
    final parcelsList = rawParcels
        .map((item) => ForestParcel.fromMap(item as Map<String, dynamic>))
        .toList();

    return OfflineForestArea(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Obszar leśny',
      downloadedAt: DateTime.tryParse(map['downloadedAt'] as String? ?? '') ??
          DateTime.now(),
      centerLat: (map['centerLat'] as num?)?.toDouble() ?? 0.0,
      centerLng: (map['centerLng'] as num?)?.toDouble() ?? 0.0,
      minLat: (map['minLat'] as num?)?.toDouble() ?? 0.0,
      minLng: (map['minLng'] as num?)?.toDouble() ?? 0.0,
      maxLat: (map['maxLat'] as num?)?.toDouble() ?? 0.0,
      maxLng: (map['maxLng'] as num?)?.toDouble() ?? 0.0,
      radiusKm: (map['radiusKm'] as num?)?.toDouble() ?? 5.0,
      parcelsCount: (map['parcelsCount'] as num?)?.toInt() ?? parcelsList.length,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      weatherSnapshot: WeatherRainfall.fromMap(
        map['weatherSnapshot'] as Map<String, dynamic>? ?? const {},
      ),
      parcels: parcelsList,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory OfflineForestArea.fromJson(String source) =>
      OfflineForestArea.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
