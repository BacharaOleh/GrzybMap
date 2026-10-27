import '../../domain/models.dart';
import '../../domain/repositories/forest_search_repository.dart';
import '../datasources/geocoding_remote_data_source.dart';

class ForestSearchRepositoryImpl implements ForestSearchRepository {
  final GeocodingRemoteDataSource _remoteDataSource;
  final Map<String, List<ForestSearchResult>> _cache = {};

  ForestSearchRepositoryImpl({GeocodingRemoteDataSource? remoteDataSource})
      : _remoteDataSource =
            remoteDataSource ?? NominatimGeocodingRemoteDataSource();

  @override
  List<ForestPreset> getPresets() => ForestPreset.all;

  @override
  Future<List<ForestSearchResult>> search(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return getPresets().map((p) => p.toSearchResult()).toList();
    }

    if (_cache.containsKey(clean)) {
      return _cache[clean]!;
    }

    // Check presets first
    final matchingPresets = ForestPreset.all
        .where((p) =>
            p.name.toLowerCase().contains(clean) ||
            p.subtitle.toLowerCase().contains(clean) ||
            p.famousMushrooms.any((m) => m.toLowerCase().contains(clean)))
        .map((p) => p.toSearchResult())
        .toList();

    // Query remote geocoder
    final remoteResults = await _remoteDataSource.searchPlaces(query);

    final combined = <ForestSearchResult>[...matchingPresets];

    for (final remote in remoteResults) {
      final alreadyPresent = combined.any((item) =>
          item.displayName.toLowerCase() == remote.displayName.toLowerCase() ||
          (item.lat - remote.lat).abs() < 0.01 && (item.lon - remote.lon).abs() < 0.01);

      if (!alreadyPresent) {
        combined.add(remote);
      }
    }

    // Limit cache size to 30 queries
    if (_cache.length > 30) {
      _cache.remove(_cache.keys.first);
    }
    _cache[clean] = combined;

    return combined;
  }
}
