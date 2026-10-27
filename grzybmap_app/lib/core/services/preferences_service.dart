import 'package:shared_preferences/shared_preferences.dart';

/// Local persistent storage service using SharedPreferences.
///
/// Persists critical user settings, saved parking location,
/// onboarding state, and radar preferences across app sessions.
class PreferencesService {
  SharedPreferences? _prefs;

  PreferencesService([this._prefs]);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // --- CAR PARKING PERSISTENCE ---
  static const _keyCarLat = 'car_lat';
  static const _keyCarLng = 'car_lng';
  static const _keyCarTime = 'car_time';

  Future<void> saveCar(double lat, double lng, DateTime time) async {
    await init();
    await _prefs?.setDouble(_keyCarLat, lat);
    await _prefs?.setDouble(_keyCarLng, lng);
    await _prefs?.setString(_keyCarTime, time.toIso8601String());
  }

  Future<void> clearCar() async {
    await init();
    await _prefs?.remove(_keyCarLat);
    await _prefs?.remove(_keyCarLng);
    await _prefs?.remove(_keyCarTime);
  }

  (double lat, double lng, DateTime time)? getCar() {
    if (_prefs == null) return null;
    final lat = _prefs?.getDouble(_keyCarLat);
    final lng = _prefs?.getDouble(_keyCarLng);
    final timeStr = _prefs?.getString(_keyCarTime);

    if (lat != null && lng != null && timeStr != null) {
      final time = DateTime.tryParse(timeStr);
      if (time != null) {
        return (lat, lng, time);
      }
    }
    return null;
  }

  // --- MAP BASE LAYER PERSISTENCE ---
  static const _keyBaseLayer = 'active_base_layer';

  Future<void> saveBaseLayer(String layer) async {
    await init();
    await _prefs?.setString(_keyBaseLayer, layer);
  }

  String? getBaseLayer() {
    return _prefs?.getString(_keyBaseLayer);
  }

  // --- ONBOARDING STATE ---
  static const _keyOnboardingDismissed = 'onboarding_dismissed';

  Future<void> setOnboardingDismissed(bool dismissed) async {
    await init();
    await _prefs?.setBool(_keyOnboardingDismissed, dismissed);
  }

  bool isOnboardingDismissed() {
    return _prefs?.getBool(_keyOnboardingDismissed) ?? false;
  }

  // --- RADAR SETTINGS PERSISTENCE ---
  static const _keyShowNames = 'radar_show_names';
  static const _keyShowForest = 'radar_show_forest';
  static const _keyShowLowProb = 'radar_show_low_prob';
  static const _keyTargetMushroom = 'radar_target_mushroom';

  Future<void> saveRadarSettings({
    bool? showNames,
    bool? showForest,
    bool? showLowProb,
  }) async {
    await init();
    if (showNames != null) await _prefs?.setBool(_keyShowNames, showNames);
    if (showForest != null) await _prefs?.setBool(_keyShowForest, showForest);
    if (showLowProb != null) await _prefs?.setBool(_keyShowLowProb, showLowProb);
  }

  bool getShowNames() => _prefs?.getBool(_keyShowNames) ?? false;
  bool getShowForest() => _prefs?.getBool(_keyShowForest) ?? false;
  bool getShowLowProb() => _prefs?.getBool(_keyShowLowProb) ?? true;

  Future<void> saveTargetMushroom(String? mushroomId) async {
    await init();
    if (mushroomId != null) {
      await _prefs?.setString(_keyTargetMushroom, mushroomId);
    } else {
      await _prefs?.remove(_keyTargetMushroom);
    }
  }

  String? getTargetMushroom() => _prefs?.getString(_keyTargetMushroom);
}
