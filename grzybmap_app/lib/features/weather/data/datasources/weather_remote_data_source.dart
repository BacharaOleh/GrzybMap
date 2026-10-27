import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';

abstract class WeatherRemoteDataSource {
  Future<Map<String, dynamic>> fetchRainfallJson({
    required double lat,
    required double lng,
    CancelToken? cancelToken,
  });
}

class WeatherRemoteDataSourceImpl implements WeatherRemoteDataSource {
  final Dio _dio;

  WeatherRemoteDataSourceImpl({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
              ),
            );

  @override
  Future<Map<String, dynamic>> fetchRainfallJson({
    required double lat,
    required double lng,
    CancelToken? cancelToken,
  }) async {
    final url = ApiConstants.openMeteoRainUrl(lat, lng);
    final response = await _dio.get<Map<String, dynamic>>(
      url,
      cancelToken: cancelToken,
    );
    return response.data as Map<String, dynamic>;
  }
}
