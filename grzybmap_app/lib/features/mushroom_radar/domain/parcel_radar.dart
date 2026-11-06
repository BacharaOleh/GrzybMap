import 'package:latlong2/latlong.dart';

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

