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
}
