import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Utilities for GIS projections and bounding box calculations (EPSG:3857).
class GisProjection {
  GisProjection._();

  /// Calculates a Web Mercator (EPSG:3857) bounding box string centered at [point]
  /// with a radius of [radiusMeters] around it.
  /// 
  /// Result format: `minX,minY,maxX,maxY`
  static String calculateBbox3857(LatLng point, {double radiusMeters = 150.0}) {
    final rad = point.latitude * pi / 180.0;
    final y = log(tan(pi / 4.0 + rad / 2.0)) * 6378137.0;
    final x = point.longitude * 20037508.34 / 180.0;
    final d = radiusMeters;
    return '${(x - d).toStringAsFixed(2)},${(y - d).toStringAsFixed(2)},${(x + d).toStringAsFixed(2)},${(y + d).toStringAsFixed(2)}';
  }
}
