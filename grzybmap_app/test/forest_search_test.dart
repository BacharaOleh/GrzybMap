import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/features/forest_search/domain/models.dart';
import 'package:grzybmap_app/features/forest_search/data/repositories/forest_search_repository_impl.dart';
import 'package:grzybmap_app/features/forest_search/data/datasources/geocoding_remote_data_source.dart';
import 'package:grzybmap_app/features/forest_search/presentation/controllers/forest_search_controller.dart';

class MockGeocodingDataSource implements GeocodingRemoteDataSource {
  final List<ForestSearchResult> stubbedResults;

  MockGeocodingDataSource([this.stubbedResults = const []]);

  @override
  Future<List<ForestSearchResult>> searchPlaces(String query) async {
    return stubbedResults;
  }
}

void main() {
  group('Forest Search & Presets Domain', () {
    test('ForestPreset.all has at least 8 curated Polish forest presets', () {
      expect(ForestPreset.all.length, greaterThanOrEqualTo(8));
      final tuchola = ForestPreset.all.firstWhere((p) => p.id == 'bory_tucholskie');
      expect(tuchola.name, 'Bory Tucholskie');
      expect(tuchola.lat, closeTo(53.60, 0.1));
      expect(tuchola.lon, closeTo(18.00, 0.1));
      expect(tuchola.famousMushrooms, contains('Borowik szlachetny'));

      final kampinos = ForestPreset.all.firstWhere((p) => p.id == 'puszcza_kampinoska');
      expect(kampinos.name, 'Puszcza Kampinoska');
      expect(kampinos.lat, closeTo(52.32, 0.1));
    });

    test('ForestPreset converts properly to ForestSearchResult', () {
      final preset = ForestPreset.all.first;
      final result = preset.toSearchResult();

      expect(result.id, preset.id);
      expect(result.shortName, preset.name);
      expect(result.category, 'preset');
      expect(result.isForest, isTrue);
      expect(result.latLng.latitude, preset.lat);
      expect(result.latLng.longitude, preset.lon);
    });
  });

  group('ForestSearchRepository', () {
    test('Empty query returns all presets as search results', () async {
      final repo = ForestSearchRepositoryImpl(
        remoteDataSource: MockGeocodingDataSource(),
      );

      final results = await repo.search('');
      expect(results.length, ForestPreset.all.length);
      expect(results.any((r) => r.shortName.contains('Bory Tucholskie')), isTrue);
    });

    test('Query matching preset returns preset without calling remote or in priority', () async {
      final repo = ForestSearchRepositoryImpl(
        remoteDataSource: MockGeocodingDataSource([
          const ForestSearchResult(
            id: 'geo_1',
            displayName: 'Tuchola, gmina Tuchola',
            shortName: 'Tuchola',
            category: 'town',
            lat: 53.58,
            lon: 17.85,
          ),
        ]),
      );

      final results = await repo.search('Tuchol');
      expect(results.isNotEmpty, isTrue);
      // Presets matching should be included
      expect(results.first.shortName, 'Bory Tucholskie');
      // Remote results appended
      expect(results.any((r) => r.id == 'geo_1'), isTrue);
    });

    test('Query results are cached in memory for repeated requests', () async {
      int remoteCallCount = 0;
      final customMock = _CountingMockGeocodingDataSource(() => remoteCallCount++);
      final repo = ForestSearchRepositoryImpl(remoteDataSource: customMock);

      await repo.search('Białowieża');
      expect(remoteCallCount, 1);

      // Second identical query should use memory cache
      await repo.search('Białowieża');
      expect(remoteCallCount, 1);
    });
  });

  group('ForestSearchController', () {
    test('Initial state is clean (results empty by default) and isOpen is false', () {
      final repo = ForestSearchRepositoryImpl(
        remoteDataSource: MockGeocodingDataSource(),
      );
      final controller = ForestSearchNotifier(repo);

      expect(controller.state.isOpen, isFalse);
      expect(controller.state.results, isEmpty);
      expect(controller.state.isLoading, isFalse);
    });

    test('openSearch sets isOpen to true', () {
      final repo = ForestSearchRepositoryImpl(
        remoteDataSource: MockGeocodingDataSource(),
      );
      final controller = ForestSearchNotifier(repo);

      controller.openSearch();
      expect(controller.state.isOpen, isTrue);

      controller.closeSearch();
      expect(controller.state.isOpen, isFalse);
    });

    test('selectPlace updates selectedPlace and closes search dropdown', () {
      final repo = ForestSearchRepositoryImpl(
        remoteDataSource: MockGeocodingDataSource(),
      );
      final controller = ForestSearchNotifier(repo);

      final place = ForestPreset.all.first.toSearchResult();
      controller.openSearch();
      expect(controller.state.isOpen, isTrue);

      controller.selectPlace(place);
      expect(controller.state.isOpen, isFalse);
      expect(controller.state.selectedPlace?.id, place.id);
    });
  });
}

class _CountingMockGeocodingDataSource implements GeocodingRemoteDataSource {
  final void Function() onSearch;

  _CountingMockGeocodingDataSource(this.onSearch);

  @override
  Future<List<ForestSearchResult>> searchPlaces(String query) async {
    onSearch();
    return [];
  }
}
