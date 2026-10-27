import 'package:dio/dio.dart';
import '../models.dart';

/// Contract for forest parcel queries and forest data inspection.
abstract class ForestRepository {
  Future<ForestParcel?> getParcelAt({
    required double lat,
    required double lng,
    required String bbox3857,
    required int width,
    required int height,
    required int pixelX,
    required int pixelY,
    required int zoom,
    CancelToken? cancelToken,
  });
}
