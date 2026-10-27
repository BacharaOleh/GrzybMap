import 'package:flutter/material.dart';

/// Weather, rainfall history, and soil condition model used for mushroom scoring.
class WeatherRainfall {
  final double totalRainMm;
  final double avgTempC;
  final String moistureLabel;
  final Color moistureBadgeColor;
  final int rainBonusScore;
  final int periodDays;
  final double? soilTempC;
  final double? soilMoistureM3;
  final bool isAvailable;

  const WeatherRainfall({
    required this.totalRainMm,
    required this.avgTempC,
    required this.moistureLabel,
    required this.moistureBadgeColor,
    required this.rainBonusScore,
    this.periodDays = 14,
    this.soilTempC,
    this.soilMoistureM3,
    this.isAvailable = true,
  });

  String get soilMoisturePercent =>
      soilMoistureM3 != null ? '${(soilMoistureM3! * 100).toStringAsFixed(1)}%' : '--';

  String get soilTempLabel =>
      soilTempC != null ? '${soilTempC!.toStringAsFixed(1)}°C' : '--';

  Map<String, dynamic> toMap() => {
        'totalRainMm': totalRainMm,
        'avgTempC': avgTempC,
        'moistureLabel': moistureLabel,
        'moistureBadgeColor': moistureBadgeColor.toARGB32(),
        'rainBonusScore': rainBonusScore,
        'periodDays': periodDays,
        'soilTempC': soilTempC,
        'soilMoistureM3': soilMoistureM3,
        'isAvailable': isAvailable,
      };

  factory WeatherRainfall.fromMap(Map<String, dynamic> map) {
    final colorVal = map['moistureBadgeColor'] as int?;
    return WeatherRainfall(
      totalRainMm: (map['totalRainMm'] as num?)?.toDouble() ?? 0.0,
      avgTempC: (map['avgTempC'] as num?)?.toDouble() ?? 15.0,
      moistureLabel: map['moistureLabel'] as String? ?? 'Optymalna',
      moistureBadgeColor: colorVal != null ? Color(colorVal) : Colors.green,
      rainBonusScore: (map['rainBonusScore'] as num?)?.toInt() ?? 0,
      periodDays: (map['periodDays'] as num?)?.toInt() ?? 14,
      soilTempC: (map['soilTempC'] as num?)?.toDouble(),
      soilMoistureM3: (map['soilMoistureM3'] as num?)?.toDouble(),
      isAvailable: map['isAvailable'] as bool? ?? true,
    );
  }
}
