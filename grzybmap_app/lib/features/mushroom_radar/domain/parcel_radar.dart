import 'package:latlong2/latlong.dart';

/// Density and clustering mode for mushroom radar badges on the map.
enum RadarDensityMode {
  /// Minimal mode: shows only top 6–12 highest-scoring forest parcels with wide spacing.
  minimal,

  /// Balanced mode (recommended default): shows top 10–22 points with comfortable spacing.
  balanced,

  /// All parcels mode: disables aggressive spatial thinning, showing all parcels in viewport.
  all,
}

extension RadarDensityModeX on RadarDensityMode {
  String get labelPl {
    switch (this) {
      case RadarDensityMode.minimal:
        return 'Czysta (TOP 10)';
      case RadarDensityMode.balanced:
        return 'Zbalansowana (TOP 20)';
      case RadarDensityMode.all:
        return 'Wszystkie';
    }
  }

  String get shortLabel {
    switch (this) {
      case RadarDensityMode.minimal:
        return 'Czysta';
      case RadarDensityMode.balanced:
        return 'Zbalansowana';
      case RadarDensityMode.all:
        return 'Wszystkie';
    }
  }

  String get descriptionPl {
    switch (this) {
      case RadarDensityMode.minimal:
        return 'Maksymalnie 10 kluczowych sektorów z dużym odstępem';
      case RadarDensityMode.balanced:
        return 'Optymalne klastrowanie przestrzenne (zalecane)';
      case RadarDensityMode.all:
        return 'Wszystkie wykryte wydzielenia bez usuwania nakładania';
    }
  }

  int getMaxLimit(double zoom) {
    switch (this) {
      case RadarDensityMode.minimal:
        return zoom < 14.5 ? 6 : (zoom < 16.0 ? 10 : 14);
      case RadarDensityMode.balanced:
        return zoom < 14.5 ? 10 : (zoom < 16.0 ? 18 : 25);
      case RadarDensityMode.all:
        return 75;
    }
  }

  double get minPixelDistance {
    switch (this) {
      case RadarDensityMode.minimal:
        return 95.0;
      case RadarDensityMode.balanced:
        return 75.0;
      case RadarDensityMode.all:
        return 35.0;
    }
  }
}

class ParcelRadarItem {
  final String id;
  final LatLng centroid;
  final String speciesName;
  final String speciesShort;
  final int ageYears;
  final double areaHa;
  final int probabilityPercent;
  final String topMushroomName;
  final int nearbyCount;
  final bool isHero;

  int get probability => probabilityPercent;

  const ParcelRadarItem({
    required this.id,
    required this.centroid,
    required this.speciesName,
    required this.speciesShort,
    required this.ageYears,
    required this.areaHa,
    required this.probabilityPercent,
    required this.topMushroomName,
    this.nearbyCount = 0,
    this.isHero = true,
  });

  ParcelRadarItem copyWith({
    String? id,
    LatLng? centroid,
    String? speciesName,
    String? speciesShort,
    int? ageYears,
    double? areaHa,
    int? probabilityPercent,
    String? topMushroomName,
    int? nearbyCount,
    bool? isHero,
  }) {
    return ParcelRadarItem(
      id: id ?? this.id,
      centroid: centroid ?? this.centroid,
      speciesName: speciesName ?? this.speciesName,
      speciesShort: speciesShort ?? this.speciesShort,
      ageYears: ageYears ?? this.ageYears,
      areaHa: areaHa ?? this.areaHa,
      probabilityPercent: probabilityPercent ?? this.probabilityPercent,
      topMushroomName: topMushroomName ?? this.topMushroomName,
      nearbyCount: nearbyCount ?? this.nearbyCount,
      isHero: isHero ?? this.isHero,
    );
  }
}

