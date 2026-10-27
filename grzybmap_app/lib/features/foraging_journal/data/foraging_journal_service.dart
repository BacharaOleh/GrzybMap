import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/foraging_spot.dart';

/// Local offline storage service for the private foraging journal.
///
/// Guaranteed zero cloud transmission. All secret spots remain
/// strictly local in the device's persistent storage.
class ForagingJournalService {
  static const _keySpots = 'foraging_secret_spots';
  static const _keyLayerVisible = 'show_secret_spots_layer';

  SharedPreferences? _prefs;

  ForagingJournalService([this._prefs]);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Retrieves all saved secret foraging spots, sorted newest first.
  List<ForagingSpot> getSpots() {
    final rawList = _prefs?.getStringList(_keySpots) ?? [];
    final spots = <ForagingSpot>[];
    for (final raw in rawList) {
      try {
        spots.add(ForagingSpot.fromJson(raw));
      } catch (_) {
        // Skip malformed entries
      }
    }
    spots.sort((a, b) => b.foundAt.compareTo(a.foundAt));
    return spots;
  }

  /// Adds a new spot or updates an existing one by ID.
  Future<List<ForagingSpot>> saveSpot(ForagingSpot spot) async {
    await init();
    final currentSpots = getSpots();
    final index = currentSpots.indexWhere((s) => s.id == spot.id);
    if (index >= 0) {
      currentSpots[index] = spot;
    } else {
      currentSpots.insert(0, spot);
    }
    final rawList = currentSpots.map((s) => s.toJson()).toList();
    await _prefs?.setStringList(_keySpots, rawList);
    return currentSpots;
  }

  /// Deletes a spot by ID.
  Future<List<ForagingSpot>> deleteSpot(String spotId) async {
    await init();
    final currentSpots = getSpots().where((s) => s.id != spotId).toList();
    final rawList = currentSpots.map((s) => s.toJson()).toList();
    await _prefs?.setStringList(_keySpots, rawList);
    return currentSpots;
  }

  /// Deletes all secret spots from storage.
  Future<void> clearAllSpots() async {
    await init();
    await _prefs?.remove(_keySpots);
  }

  /// Visibility toggle state for secret spots on the map.
  bool isLayerVisible() {
    return _prefs?.getBool(_keyLayerVisible) ?? true;
  }

  /// Updates map layer visibility setting.
  Future<void> setLayerVisible(bool visible) async {
    await init();
    await _prefs?.setBool(_keyLayerVisible, visible);
  }
}
