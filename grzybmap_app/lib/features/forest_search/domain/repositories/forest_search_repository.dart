import '../models.dart';

abstract class ForestSearchRepository {
  Future<List<ForestSearchResult>> search(String query);
  List<ForestPreset> getPresets();
}
