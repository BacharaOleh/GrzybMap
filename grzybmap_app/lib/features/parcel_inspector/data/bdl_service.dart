import '../domain/models.dart';
import '../domain/repositories/forest_repository.dart';
import 'repositories/forest_repository_impl.dart';

/// Legacy service facade delegating to ForestRepositoryImpl.
class BdlService implements ForestRepository {
  final ForestRepository _repository;

  BdlService([ForestRepository? repository])
      : _repository = repository ?? ForestRepositoryImpl();

  @override
  Future<ForestParcel?> getParcelAt({
    required double lat,
    required double lng,
    required String bbox3857,
    required int width,
    required int height,
    required int pixelX,
    required int pixelY,
    required int zoom,
  }) {
    return _repository.getParcelAt(
      lat: lat,
      lng: lng,
      bbox3857: bbox3857,
      width: width,
      height: height,
      pixelX: pixelX,
      pixelY: pixelY,
      zoom: zoom,
    );
  }

  /// Backward-compatible alias for existing call sites.
  Future<ForestParcel?> queryParcelAt({
    required double lat,
    required double lng,
    required String bbox3857,
    required int width,
    required int height,
    required int pixelX,
    required int pixelY,
    required int zoom,
  }) {
    return getParcelAt(
      lat: lat,
      lng: lng,
      bbox3857: bbox3857,
      width: width,
      height: height,
      pixelX: pixelX,
      pixelY: pixelY,
      zoom: zoom,
    );
  }
}
