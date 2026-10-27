import 'package:dio/dio.dart';

/// Service responsible for fetching dynamic real-time precipitation radar tiles
/// from RainViewer API with native zoom scaling (maxNativeZoom: 7).
class RainRadarService {
  final Dio _dio;

  static const String fallbackRadarPath = '/v2/radar/4c23604d0d44';
  static const String apiEndpoint = 'https://api.rainviewer.com/public/weather-maps.json';

  String _cachedTemplate = 'https://tilecache.rainviewer.com$fallbackRadarPath/256/{z}/{x}/{y}/2/1_1.png';
  DateTime? _lastFetchTime;

  RainRadarService({Dio? dio}) : _dio = dio ?? Dio();

  String get currentTemplate => _cachedTemplate;

  /// Fetches the latest radar timestamp path from RainViewer.
  /// If the request fails or is rate-limited, returns the cached or fallback template.
  Future<String> getLatestRadarUrlTemplate({CancelToken? cancelToken}) async {
    // Cache for 5 minutes
    if (_lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < const Duration(minutes: 5)) {
      return _cachedTemplate;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        apiEndpoint,
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      final data = response.data;
      if (data != null && data['radar'] != null) {
        final pastList = data['radar']['past'] as List?;
        if (pastList != null && pastList.isNotEmpty) {
          final lastItem = pastList.last as Map<String, dynamic>;
          final path = lastItem['path'] as String?;
          if (path != null && path.isNotEmpty) {
            _cachedTemplate = 'https://tilecache.rainviewer.com$path/256/{z}/{x}/{y}/2/1_1.png';
            _lastFetchTime = DateTime.now();
          }
        }
      }
    } catch (_) {
      // Gracefully use fallback on error (offline mode / timeout)
    }

    return _cachedTemplate;
  }
}
