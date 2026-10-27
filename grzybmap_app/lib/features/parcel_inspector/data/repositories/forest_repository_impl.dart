import 'package:dio/dio.dart';
import '../../domain/models.dart';
import '../../domain/repositories/forest_repository.dart';
import '../bdl_parser.dart';
import '../datasources/bdl_remote_data_source.dart';

class _ParcelCacheEntry {
  final ForestParcel? parcel;
  final DateTime cachedAt;
  final Duration ttl;

  _ParcelCacheEntry(
    this.parcel,
    this.cachedAt, {
    this.ttl = const Duration(hours: 6),
  });

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}

class ForestRepositoryImpl implements ForestRepository {
  final BdlRemoteDataSource _remoteDataSource;
  final Map<String, _ParcelCacheEntry> _cache = {};
  static const int _maxCacheSize = 200;

  ForestRepositoryImpl({BdlRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? BdlRemoteDataSourceImpl();

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
    CancelToken? cancelToken,
  }) async {
    final cacheKey = '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.parcel;
    }

    try {
      final html = await _remoteDataSource.fetchFeatureInfoHtml(
        bbox3857: bbox3857,
        width: width,
        height: height,
        pixelX: pixelX,
        pixelY: pixelY,
        zoom: zoom,
        cancelToken: cancelToken,
      );

      final parcel = BdlParser.parseHtml(
        htmlString: html,
        lat: lat,
        lng: lng,
      );

      // Enforce bounded cache size
      if (_cache.length >= _maxCacheSize) {
        _cache.remove(_cache.keys.first);
      }

      // Valid parcels cached for 6 hours; null responses (e.g. temporary failures) for 5 minutes
      final ttl = parcel != null
          ? const Duration(hours: 6)
          : const Duration(minutes: 5);

      _cache[cacheKey] = _ParcelCacheEntry(parcel, DateTime.now(), ttl: ttl);
      return parcel;
    } on DioException {
      // Allow higher layer to distinguish cancellation and network failures
      rethrow;
    } on FormatException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
