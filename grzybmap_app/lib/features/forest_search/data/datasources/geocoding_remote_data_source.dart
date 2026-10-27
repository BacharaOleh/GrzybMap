import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models.dart';

abstract class GeocodingRemoteDataSource {
  Future<List<ForestSearchResult>> searchPlaces(String query);
}

class NominatimGeocodingRemoteDataSource implements GeocodingRemoteDataSource {
  final Dio _dio;

  NominatimGeocodingRemoteDataSource({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<List<ForestSearchResult>> searchPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final String url;
      final Map<String, dynamic> queryParams = {
        'q': cleanQuery,
        'countrycodes': 'pl',
        'format': 'json',
        'limit': 6,
        'addressdetails': 1,
      };

      final Options options = Options(
        receiveTimeout: const Duration(seconds: 6),
        sendTimeout: const Duration(seconds: 4),
      );

      if (kIsWeb) {
        url = '/api/search';
      } else {
        url = 'https://nominatim.openstreetmap.org/search';
        options.headers = {
          'User-Agent': 'GrzybMap-App/1.0 (grzybmap@lasy.pl)',
        };
      }

      final response = await _dio.get<dynamic>(
        url,
        queryParameters: queryParams,
        options: options,
      );

      if (response.statusCode != 200 || response.data == null) {
        return [];
      }

      final List<dynamic> list;
      if (response.data is List) {
        list = response.data as List<dynamic>;
      } else {
        return [];
      }

      final results = <ForestSearchResult>[];

      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;

        final rawLat = item['lat'];
        final rawLon = item['lon'];
        if (rawLat == null || rawLon == null) continue;

        final double? lat = double.tryParse(rawLat.toString());
        final double? lon = double.tryParse(rawLon.toString());
        if (lat == null || lon == null) continue;

        final displayName = (item['display_name'] as String?) ?? cleanQuery;
        final name = (item['name'] as String?) ?? cleanQuery;
        final type = (item['type'] as String?) ?? 'place';
        final osmClass = (item['class'] as String?) ?? '';

        final isForest = osmClass == 'leisure' ||
            osmClass == 'landuse' ||
            type == 'forest' ||
            type == 'wood' ||
            displayName.toLowerCase().contains('puszcza') ||
            displayName.toLowerCase().contains('bory') ||
            displayName.toLowerCase().contains('las');

        String emoji = '📍';
        if (isForest) {
          emoji = '🌲';
        } else if (type == 'city' || type == 'town') {
          emoji = '🏙️';
        } else if (type == 'village') {
          emoji = '🏡';
        }

        // Clean subtitle from displayName
        final parts = displayName.split(',');
        String? subtitle;
        if (parts.length > 1) {
          subtitle = parts.sublist(1, parts.length > 3 ? 3 : parts.length).join(',').trim();
        }

        results.add(
          ForestSearchResult(
            id: item['place_id']?.toString() ?? '${lat}_$lon',
            displayName: displayName,
            shortName: name,
            category: isForest ? 'forest' : type,
            lat: lat,
            lon: lon,
            subtitle: subtitle,
            iconEmoji: emoji,
          ),
        );
      }

      return results;
    } catch (e) {
      debugPrint('[GeocodingRemoteDataSource] Error searching "$query": $e');
      return [];
    }
  }
}
