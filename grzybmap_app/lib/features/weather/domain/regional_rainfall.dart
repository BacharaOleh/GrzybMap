import 'package:flutter/material.dart';

/// Represents 14-day accumulated precipitation for a geographic grid point.
class RegionalRainfallPoint {
  final double latitude;
  final double longitude;
  final double rainfall14DaysMm;
  final String? regionName;

  const RegionalRainfallPoint({
    required this.latitude,
    required this.longitude,
    required this.rainfall14DaysMm,
    this.regionName,
  });

  /// Category label in Polish
  String get categoryLabel {
    if (rainfall14DaysMm >= 35.0) return 'Bardzo mokro (idealne warunki)';
    if (rainfall14DaysMm >= 22.0) return 'Dobre nawilżenie ściółki';
    if (rainfall14DaysMm >= 12.0) return 'Umiarkowane opady';
    return 'Sucho (małe prawdopodobieństwo)';
  }

  /// Heatmap color based on 14-day precipitation
  Color get heatColor {
    if (rainfall14DaysMm >= 35.0) {
      return const Color(0xFF0284C7); // Deep vibrant cyan/blue
    } else if (rainfall14DaysMm >= 22.0) {
      return const Color(0xFF10B981); // Emerald green
    } else if (rainfall14DaysMm >= 12.0) {
      return const Color(0xFFFBBF24); // Warm amber
    } else {
      return const Color(0xFF94A3B8); // Muted slate
    }
  }

  String get formattedMm => '${rainfall14DaysMm.toStringAsFixed(1)} mm';
}
