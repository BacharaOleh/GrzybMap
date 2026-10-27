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
  });
}
