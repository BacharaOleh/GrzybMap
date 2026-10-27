import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';

abstract class BdlRemoteDataSource {
  Future<String> fetchFeatureInfoHtml({
    required String bbox3857,
    required int width,
    required int height,
    required int pixelX,
    required int pixelY,
    required int zoom,
    CancelToken? cancelToken,
  });
}

class BdlRemoteDataSourceImpl implements BdlRemoteDataSource {
  final Dio _dio;

  BdlRemoteDataSourceImpl({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 7),
                receiveTimeout: const Duration(seconds: 7),
                headers: kIsWeb
                    ? null
                    : {
                        'User-Agent':
                            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                      },
              ),
            );

  @override
  Future<String> fetchFeatureInfoHtml({
    required String bbox3857,
    required int width,
    required int height,
    required int pixelX,
    required int pixelY,
    required int zoom,
    CancelToken? cancelToken,
  }) async {
    final layers = zoom >= 13 ? '1,3,4' : '4,5';

    final queryParams = {
      'SERVICE': 'WMS',
      'VERSION': '1.1.1',
      'REQUEST': 'GetFeatureInfo',
      'BBOX': bbox3857,
      'SRS': 'EPSG:3857',
      'WIDTH': width.toString(),
      'HEIGHT': height.toString(),
      'LAYERS': layers,
      'QUERY_LAYERS': layers,
      'INFO_FORMAT': 'text/html',
      'X': pixelX.toString(),
      'Y': pixelY.toString(),
    };

    const endpoint = kIsWeb ? '/api/bdl' : ApiConstants.bdlWmsUrl;
    final response = await _dio.get<dynamic>(
      endpoint,
      queryParameters: queryParams,
      cancelToken: cancelToken,
    );

    return response.data.toString();
  }
}
