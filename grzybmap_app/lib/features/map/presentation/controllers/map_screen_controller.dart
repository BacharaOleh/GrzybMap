import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/gis_projection.dart';
import '../../../parcel_inspector/domain/models.dart';
import '../../../parcel_inspector/domain/repositories/forest_repository.dart';
import '../../../weather/domain/models.dart';
import '../../../weather/domain/regional_rainfall.dart';
import '../../../weather/domain/repositories/weather_repository.dart';
import '../../../weather/data/datasources/rain_radar_service.dart';
import '../../../weather/data/datasources/rain_heatmap_service.dart';
import '../../../mushroom_radar/domain/models.dart';
import '../../../mushroom_radar/domain/parcel_radar.dart';
import '../../../mushroom_radar/service/parcel_radar_service.dart';
import '../../../mushroom_radar/service/match_engine.dart';
import '../../../navigation/service/location_service.dart';
import '../../../navigation/service/parking_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../offline_mode/domain/models/offline_forest_area.dart';
import '../../../offline_mode/data/offline_forest_service.dart';

/// Immutable State for the Map and Mushroom Radar screen
class MapScreenState {
  final String activeBaseLayer; // 'satellite', 'dark', 'topo', 'osm'
  final bool bdlLayerVisible;
  final LatLng? clickedPoint;
  final LatLng? userLocation;
  final ForestParcel? activeParcel;
  final WeatherRainfall? activeWeather;
  final List<MushroomMatchResult> mushroomMatches;
  final bool isLoadingInspection;
  final bool isLocating;
  final bool showOnboarding;
  final int selectedMonth;
  final String? locationErrorMessage;
  final String? locationSourceDescription;
  final LatLng? carLocation;
  final DateTime? carParkedTime;
  final ParkingNavigation? carNavigation;
  final bool showCarRoute;
  final List<ParcelRadarItem> parcelRadars;
  final bool showParcelRadars;
  final bool showRadarMushroomName;
  final bool showRadarTreeSpecies;
  final bool showLowProbabilityRadars;
  final String? targetMushroomId;
  final bool showRainRadarLayer;
  final String? rainRadarUrlTemplate;
  final List<RegionalRainfallPoint> regionalRainfall;
  final bool showLiveRadarCloudLayer;
  final bool isOfflineMode;
  final bool isOfflineData;
  final List<OfflineForestAreaSummary> downloadedAreas;
  final bool isDownloadingOffline;
  final double offlineDownloadProgress;
  final String offlineDownloadStatus;

  const MapScreenState({
    this.activeBaseLayer = 'satellite',
    this.bdlLayerVisible = true,
    this.clickedPoint,
    this.userLocation,
    this.activeParcel,
    this.activeWeather,
    this.mushroomMatches = const [],
    this.isLoadingInspection = false,
    this.isLocating = false,
    this.showOnboarding = true,
    required this.selectedMonth,
    this.locationErrorMessage,
    this.locationSourceDescription,
    this.carLocation,
    this.carParkedTime,
    this.carNavigation,
    this.showCarRoute = false,
    this.parcelRadars = const [],
    this.showParcelRadars = true,
    this.showRadarMushroomName = false,
    this.showRadarTreeSpecies = false,
    this.showLowProbabilityRadars = false,
    this.targetMushroomId,
    this.showRainRadarLayer = false,
    this.rainRadarUrlTemplate,
    this.regionalRainfall = const [],
    this.showLiveRadarCloudLayer = false,
    this.isOfflineMode = false,
    this.isOfflineData = false,
    this.downloadedAreas = const [],
    this.isDownloadingOffline = false,
    this.offlineDownloadProgress = 0.0,
    this.offlineDownloadStatus = '',
  });

  /// Visible parcel radars filtered by active settings (>= 50% by default, or all if low prob enabled)
  List<ParcelRadarItem> get visibleParcelRadars {
    if (!showParcelRadars) return const [];
    if (showLowProbabilityRadars) return parcelRadars;
    return parcelRadars
        .where((r) => r.probabilityPercent >= 50)
        .toList(growable: false);
  }

  bool get hasCar => carLocation != null;

  String get currentTileUrl {
    switch (activeBaseLayer) {
      case 'dark':
        return ApiConstants.esriDarkCanvasUrl;
      case 'topo':
        return ApiConstants.openTopoMapUrl;
      case 'osm':
        return ApiConstants.openStreetMapUrl;
      case 'satellite':
      default:
        return ApiConstants.esriSatelliteUrl;
    }
  }

  String get activeLayerLabel {
    switch (activeBaseLayer) {
      case 'dark':
        return 'Ciemna';
      case 'topo':
        return 'Topograficzna';
      case 'osm':
        return 'Uliczna';
      case 'satellite':
      default:
        return 'Satelita';
    }
  }

  MapScreenState copyWith({
    String? activeBaseLayer,
    bool? bdlLayerVisible,
    LatLng? clickedPoint,
    bool clearClickedPoint = false,
    LatLng? userLocation,
    bool clearUserLocation = false,
    ForestParcel? activeParcel,
    bool clearActiveParcel = false,
    WeatherRainfall? activeWeather,
    bool clearActiveWeather = false,
    List<MushroomMatchResult>? mushroomMatches,
    bool? isLoadingInspection,
    bool? isLocating,
    bool? showOnboarding,
    int? selectedMonth,
    String? locationErrorMessage,
    bool clearLocationErrorMessage = false,
    String? locationSourceDescription,
    LatLng? carLocation,
    bool clearCarLocation = false,
    DateTime? carParkedTime,
    ParkingNavigation? carNavigation,
    bool clearCarNavigation = false,
    bool? showCarRoute,
    List<ParcelRadarItem>? parcelRadars,
    bool? showParcelRadars,
    bool? showRadarMushroomName,
    bool? showRadarTreeSpecies,
    bool? showLowProbabilityRadars,
    String? targetMushroomId,
    bool clearTargetMushroom = false,
    bool? showRainRadarLayer,
    String? rainRadarUrlTemplate,
    List<RegionalRainfallPoint>? regionalRainfall,
    bool? showLiveRadarCloudLayer,
    bool? isOfflineMode,
    bool? isOfflineData,
    List<OfflineForestAreaSummary>? downloadedAreas,
    bool? isDownloadingOffline,
    double? offlineDownloadProgress,
    String? offlineDownloadStatus,
  }) {
    return MapScreenState(
      activeBaseLayer: activeBaseLayer ?? this.activeBaseLayer,
      bdlLayerVisible: bdlLayerVisible ?? this.bdlLayerVisible,
      clickedPoint:
          clearClickedPoint ? null : (clickedPoint ?? this.clickedPoint),
      userLocation:
          clearUserLocation ? null : (userLocation ?? this.userLocation),
      activeParcel:
          clearActiveParcel ? null : (activeParcel ?? this.activeParcel),
      activeWeather:
          clearActiveWeather ? null : (activeWeather ?? this.activeWeather),
      mushroomMatches: mushroomMatches ?? this.mushroomMatches,
      isLoadingInspection: isLoadingInspection ?? this.isLoadingInspection,
      isLocating: isLocating ?? this.isLocating,
      showOnboarding: showOnboarding ?? this.showOnboarding,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      locationErrorMessage: clearLocationErrorMessage
          ? null
          : (locationErrorMessage ?? this.locationErrorMessage),
      locationSourceDescription:
          locationSourceDescription ?? this.locationSourceDescription,
      carLocation:
          clearCarLocation ? null : (carLocation ?? this.carLocation),
      carParkedTime:
          clearCarLocation ? null : (carParkedTime ?? this.carParkedTime),
      carNavigation:
          (clearCarLocation || clearCarNavigation) ? null : (carNavigation ?? this.carNavigation),
      showCarRoute: showCarRoute ?? this.showCarRoute,
      parcelRadars: parcelRadars ?? this.parcelRadars,
      showParcelRadars: showParcelRadars ?? this.showParcelRadars,
      showRadarMushroomName:
          showRadarMushroomName ?? this.showRadarMushroomName,
      showRadarTreeSpecies:
          showRadarTreeSpecies ?? this.showRadarTreeSpecies,
      showLowProbabilityRadars:
          showLowProbabilityRadars ?? this.showLowProbabilityRadars,
      targetMushroomId: clearTargetMushroom
          ? null
          : (targetMushroomId ?? this.targetMushroomId),
      showRainRadarLayer: showRainRadarLayer ?? this.showRainRadarLayer,
      rainRadarUrlTemplate: rainRadarUrlTemplate ?? this.rainRadarUrlTemplate,
      regionalRainfall: regionalRainfall ?? this.regionalRainfall,
      showLiveRadarCloudLayer: showLiveRadarCloudLayer ?? this.showLiveRadarCloudLayer,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      isOfflineData: isOfflineData ?? this.isOfflineData,
      downloadedAreas: downloadedAreas ?? this.downloadedAreas,
      isDownloadingOffline: isDownloadingOffline ?? this.isDownloadingOffline,
      offlineDownloadProgress: offlineDownloadProgress ?? this.offlineDownloadProgress,
      offlineDownloadStatus: offlineDownloadStatus ?? this.offlineDownloadStatus,
    );
  }
}

/// Sealed result hierarchy for parcel inspections to prevent race conditions and handle typed errors
sealed class InspectionResult {
  const InspectionResult();
}

class InspectionSuccess extends InspectionResult {
  const InspectionSuccess();
}

class InspectionCancelled extends InspectionResult {
  const InspectionCancelled();
}

class InspectionError extends InspectionResult {
  final String message;
  const InspectionError(this.message);
}

/// StateNotifier handling map events, GIS inspection, multi-tier location, and data fetching.
class MapScreenNotifier extends StateNotifier<MapScreenState> {
  final ForestRepository _forestRepository;
  final WeatherRepository _weatherRepository;
  final ParkingService _parkingService;
  final LocationService _locationService;
  final ParcelRadarService _parcelRadarService;
  final RainRadarService _rainRadarService;
  final RainHeatmapService _rainHeatmapService;
  final PreferencesService? _preferencesService;
  final OfflineForestService? _offlineForestService;

  int _activeRequestId = 0;
  CancelToken? _activeCancelToken;
  int _activeRadarRequestId = 0;
  CancelToken? _activeRadarCancelToken;

  MapScreenNotifier({
    required ForestRepository forestRepository,
    required WeatherRepository weatherRepository,
    required ParkingService parkingService,
    required LocationService locationService,
    ParcelRadarService? parcelRadarService,
    RainRadarService? rainRadarService,
    RainHeatmapService? rainHeatmapService,
    PreferencesService? preferencesService,
    OfflineForestService? offlineForestService,
  })  : _forestRepository = forestRepository,
        _weatherRepository = weatherRepository,
        _parkingService = parkingService,
        _locationService = locationService,
        _parcelRadarService = parcelRadarService ?? ParcelRadarService(),
        _rainRadarService = rainRadarService ?? RainRadarService(),
        _rainHeatmapService = rainHeatmapService ?? RainHeatmapService(),
        _preferencesService = preferencesService,
        _offlineForestService = offlineForestService,
        super(MapScreenState(
          selectedMonth: DateTime.now().month,
          activeBaseLayer: preferencesService?.getBaseLayer() ?? 'satellite',
          showOnboarding: !(preferencesService?.isOnboardingDismissed() ?? false),
          regionalRainfall: (rainHeatmapService ?? RainHeatmapService()).currentPoints,
          carLocation: preferencesService?.getCar() != null
              ? LatLng(preferencesService!.getCar()!.$1, preferencesService.getCar()!.$2)
              : null,
          carParkedTime: preferencesService?.getCar()?.$3,
          showRadarMushroomName: preferencesService?.getShowNames() ?? false,
          showRadarTreeSpecies: preferencesService?.getShowForest() ?? false,
          showLowProbabilityRadars: preferencesService?.getShowLowProb() ?? false,
          isOfflineMode: offlineForestService?.isForcedOffline() ?? false,
          downloadedAreas: offlineForestService?.getAreaSummaries() ?? const [],
        ));

  @override
  void dispose() {
    _activeCancelToken?.cancel('MapScreenNotifier disposed');
    _activeRadarCancelToken?.cancel('MapScreenNotifier disposed');
    super.dispose();
  }

  void cycleBaseLayer() {
    final next = switch (state.activeBaseLayer) {
      'satellite' => 'dark',
      'dark' => 'topo',
      'topo' => 'osm',
      _ => 'satellite',
    };
    state = state.copyWith(activeBaseLayer: next);
    _preferencesService?.saveBaseLayer(next);
  }

  void dismissOnboarding() {
    state = state.copyWith(showOnboarding: false);
    _preferencesService?.setOnboardingDismissed(true);
  }

  Future<LatLng?> locateUser() async {
    state = state.copyWith(
      isLocating: true,
      clearLocationErrorMessage: true,
    );

    try {
      final res = await _locationService.determineLocation();
      if (res != null) {
        ParkingNavigation? nav;
        if (state.carLocation != null) {
          nav = _parkingService.calculateNavigationToCar(
            res.position.latitude,
            res.position.longitude,
          );
        }
        state = state.copyWith(
          userLocation: res.position,
          carNavigation: nav,
          locationSourceDescription: res.sourceDescription,
          isLocating: false,
          showOnboarding: false,
          clearLocationErrorMessage: true,
        );
        return res.position;
      } else {
        state = state.copyWith(
          isLocating: false,
          locationErrorMessage:
              'Nie udało się ustalić pozycji. Sprawdź połączenie z siecią.',
        );
        return null;
      }
    } catch (e) {
      state = state.copyWith(
        isLocating: false,
        locationErrorMessage: 'Błąd lokalizacji: $e',
      );
      return null;
    }
  }

  Future<InspectionResult> inspectPoint(LatLng point, int zoom) async {
    // 1. Generation ID to drop stale responses from rapid clicks
    final requestId = ++_activeRequestId;

    // 2. Abort previous in-flight HTTP requests to save bandwidth and prevent races
    _activeCancelToken?.cancel('New point clicked');
    _activeCancelToken = CancelToken();
    final cancelToken = _activeCancelToken!;

    // Clear previous parcel, weather, matches immediately so stale data never leaks
    state = state.copyWith(
      clickedPoint: point,
      isLoadingInspection: true,
      showOnboarding: false,
      clearActiveParcel: true,
      clearActiveWeather: true,
      mushroomMatches: const [],
    );

    final bbox = GisProjection.calculateBbox3857(point);

    // If offline mode is active, directly query the hermetic local cache
    if (state.isOfflineMode) {
      final offlineResult = _offlineForestService?.findClosestParcel(point.latitude, point.longitude);
      if (offlineResult != null) {
        final matches = MatchEngine.evaluateMushrooms(
          parcel: offlineResult.parcel,
          weather: offlineResult.weather,
          selectedMonth: state.selectedMonth,
        );
        state = state.copyWith(
          activeParcel: offlineResult.parcel,
          activeWeather: offlineResult.weather,
          mushroomMatches: matches,
          isOfflineData: true,
          isLoadingInspection: false,
        );
        return const InspectionSuccess();
      } else {
        state = state.copyWith(
          clearActiveParcel: true,
          clearActiveWeather: true,
          mushroomMatches: const [],
          isOfflineData: false,
          isLoadingInspection: false,
        );
        return const InspectionError(
          'Brak połączenia z siecią i brak pobranego rejonu offline dla tego lasu. Pobierz pakiet 10×10 km w menedżerze offline.',
        );
      }
    }

    try {
      final parcelFuture = _forestRepository.getParcelAt(
        lat: point.latitude,
        lng: point.longitude,
        bbox3857: bbox,
        width: 100,
        height: 100,
        pixelX: 50,
        pixelY: 50,
        zoom: zoom,
        cancelToken: cancelToken,
      );

      final weatherFuture = _weatherRepository.getRainfallHistory(
        lat: point.latitude,
        lng: point.longitude,
        cancelToken: cancelToken,
      );

      final results = await Future.wait([parcelFuture, weatherFuture]);

      // If a newer click occurred while waiting, silently discard this response
      if (requestId != _activeRequestId || cancelToken.isCancelled) {
        return const InspectionCancelled();
      }

      final parcel = results[0] as ForestParcel?;
      final weather = results[1] as WeatherRainfall?;

      final matches = parcel != null
          ? MatchEngine.evaluateMushrooms(
              parcel: parcel,
              weather: weather,
              selectedMonth: state.selectedMonth,
            )
          : <MushroomMatchResult>[];

      state = state.copyWith(
        activeParcel: parcel,
        clearActiveParcel: parcel == null,
        activeWeather: weather,
        clearActiveWeather: weather == null,
        mushroomMatches: matches,
        isOfflineData: false,
        isLoadingInspection: false,
      );
      return const InspectionSuccess();
    } on DioException catch (dioErr) {
      if (cancelToken.isCancelled || requestId != _activeRequestId) {
        return const InspectionCancelled();
      }

      // Check offline fallback before reporting connection loss
      final offlineFallback = _offlineForestService?.findClosestParcel(point.latitude, point.longitude);
      if (offlineFallback != null) {
        final matches = MatchEngine.evaluateMushrooms(
          parcel: offlineFallback.parcel,
          weather: offlineFallback.weather,
          selectedMonth: state.selectedMonth,
        );
        state = state.copyWith(
          activeParcel: offlineFallback.parcel,
          activeWeather: offlineFallback.weather,
          mushroomMatches: matches,
          isOfflineData: true,
          isLoadingInspection: false,
        );
        return const InspectionSuccess();
      }

      final message = switch (dioErr.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'Serwer BDL nie odpowiada na czas (limit czasu). Spróbuj ponownie lub pobierz rejon offline.',
        DioExceptionType.connectionError =>
          'Brak połączenia z siecią lub serwerem leśnym BDL.',
        DioExceptionType.badResponse =>
          'Błąd serwera BDL (${dioErr.response?.statusCode ?? 500}).',
        _ => 'Błąd komunikacji z BDL: ${dioErr.message ?? 'błąd połączenia'}',
      };

      state = state.copyWith(
        clearActiveParcel: true,
        clearActiveWeather: true,
        mushroomMatches: const [],
        isOfflineData: false,
        isLoadingInspection: false,
      );
      return InspectionError(message);
    } catch (_) {
      if (requestId != _activeRequestId) {
        return const InspectionCancelled();
      }

      final offlineFallback = _offlineForestService?.findClosestParcel(point.latitude, point.longitude);
      if (offlineFallback != null) {
        final matches = MatchEngine.evaluateMushrooms(
          parcel: offlineFallback.parcel,
          weather: offlineFallback.weather,
          selectedMonth: state.selectedMonth,
        );
        state = state.copyWith(
          activeParcel: offlineFallback.parcel,
          activeWeather: offlineFallback.weather,
          mushroomMatches: matches,
          isOfflineData: true,
          isLoadingInspection: false,
        );
        return const InspectionSuccess();
      }

      state = state.copyWith(
        clearActiveParcel: true,
        clearActiveWeather: true,
        mushroomMatches: const [],
        isOfflineData: false,
        isLoadingInspection: false,
      );
      return const InspectionError('Wystąpił błąd podczas pobierania danych o lesie.');
    }
  }

  void saveCarLocation({LatLng? point}) {
    final target = point ?? state.userLocation ?? state.clickedPoint;
    if (target != null) {
      final now = DateTime.now();
      _parkingService.saveCarLocation(target.latitude, target.longitude, time: now);
      final nav = state.userLocation != null
          ? _parkingService.calculateNavigationToCar(
              state.userLocation!.latitude,
              state.userLocation!.longitude,
            )
          : null;
      state = state.copyWith(
        carLocation: target,
        carParkedTime: now,
        carNavigation: nav,
        showCarRoute: false,
      );
    }
  }

  void toggleCarRoute() {
    if (state.carLocation == null) return;
    state = state.copyWith(showCarRoute: !state.showCarRoute);
  }

  void setCarRouteVisible(bool visible) {
    state = state.copyWith(showCarRoute: visible);
  }

  void clearCarLocation() {
    _parkingService.clearCar();
    state = state.copyWith(
      clearCarLocation: true,
      clearCarNavigation: true,
      showCarRoute: false,
    );
  }

  void recalculateCarNavigation() {
    if (state.carLocation != null && state.userLocation != null) {
      final nav = _parkingService.calculateNavigationToCar(
        state.userLocation!.latitude,
        state.userLocation!.longitude,
      );
      state = state.copyWith(carNavigation: nav);
    }
  }

  Future<void> updateVisibleRadars(LatLngBounds bounds, double zoom) async {
    if (!state.showParcelRadars || zoom < 13.5) {
      if (state.parcelRadars.isNotEmpty) {
        state = state.copyWith(parcelRadars: const []);
      }
      return;
    }

    if (state.isOfflineMode) {
      final summaries = _offlineForestService?.getAreaSummaries() ?? [];
      final localRadars = <ParcelRadarItem>[];
      for (final summary in summaries) {
        final area = _offlineForestService?.getArea(summary.id);
        if (area == null) continue;
        for (final p in area.parcels) {
          if (p.latitude >= bounds.south &&
              p.latitude <= bounds.north &&
              p.longitude >= bounds.west &&
              p.longitude <= bounds.east) {
            final matches = MatchEngine.evaluateMushrooms(
              parcel: p,
              weather: area.weatherSnapshot,
              selectedMonth: state.selectedMonth,
            );
            if (matches.isNotEmpty) {
              final best = matches.first;
              localRadars.add(
                ParcelRadarItem(
                  id: '${p.latitude.toStringAsFixed(4)}_${p.longitude.toStringAsFixed(4)}',
                  centroid: LatLng(p.latitude, p.longitude),
                  speciesName: p.primarySpecies.namePl.split(' ').first,
                  speciesShort: ParcelRadarService.toShortTreeName(p.primarySpecies.namePl),
                  ageYears: p.ageYears,
                  areaHa: double.tryParse(p.areaHa?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? 3.5,
                  probabilityPercent: best.probabilityPercent,
                  topMushroomName: ParcelRadarService.toShortMushroomName(best.mushroom.namePl),
                ),
              );
            }
          }
        }
      }
      state = state.copyWith(parcelRadars: localRadars);
      return;
    }

    final reqId = ++_activeRadarRequestId;
    _activeRadarCancelToken?.cancel('New camera viewport');
    _activeRadarCancelToken = CancelToken();

    try {
      WeatherRainfall? currentWeather = state.activeWeather;
      if (currentWeather == null) {
        try {
          final centerLat = (bounds.south + bounds.north) / 2;
          final centerLng = (bounds.west + bounds.east) / 2;
          currentWeather = await _weatherRepository.getRainfallHistory(
            lat: centerLat,
            lng: centerLng,
          );
          state = state.copyWith(activeWeather: currentWeather);
        } catch (_) {}
      }

      final items = await _parcelRadarService.fetchVisibleRadars(
        minLat: bounds.south,
        minLng: bounds.west,
        maxLat: bounds.north,
        maxLng: bounds.east,
        weather: currentWeather,
        selectedMonth: state.selectedMonth,
        targetMushroomId: state.targetMushroomId,
        cancelToken: _activeRadarCancelToken,
      );

      if (reqId == _activeRadarRequestId && !(_activeRadarCancelToken?.isCancelled ?? false)) {
        state = state.copyWith(parcelRadars: items);
      }
    } catch (_) {
      // Ignored network/cancellation
    }
  }

  void toggleParcelRadars() {
    state = state.copyWith(showParcelRadars: !state.showParcelRadars);
  }

  void toggleRadarMushroomName() {
    final next = !state.showRadarMushroomName;
    state = state.copyWith(showRadarMushroomName: next);
    _preferencesService?.saveRadarSettings(showNames: next);
  }

  void toggleRadarTreeSpecies() {
    final next = !state.showRadarTreeSpecies;
    state = state.copyWith(showRadarTreeSpecies: next);
    _preferencesService?.saveRadarSettings(showForest: next);
  }

  void toggleLowProbabilityRadars() {
    final next = !state.showLowProbabilityRadars;
    state = state.copyWith(showLowProbabilityRadars: next);
    _preferencesService?.saveRadarSettings(showLowProb: next);
  }

  void setTargetMushroom(String? mushroomId) {
    if (mushroomId == null) {
      state = state.copyWith(clearTargetMushroom: true);
      _preferencesService?.saveTargetMushroom(null);
    } else {
      state = state.copyWith(targetMushroomId: mushroomId);
      _preferencesService?.saveTargetMushroom(mushroomId);
    }
  }

  Future<void> toggleRainRadarLayer() async {
    final next = !state.showRainRadarLayer;
    state = state.copyWith(showRainRadarLayer: next);
    if (next) {
      try {
        final points = await _rainHeatmapService.fetch14DaysRainfallGrid();
        state = state.copyWith(regionalRainfall: points);
      } catch (_) {}
    }
  }

  Future<void> toggleLiveRadarClouds() async {
    final next = !state.showLiveRadarCloudLayer;
    state = state.copyWith(showLiveRadarCloudLayer: next);
    if (next && state.rainRadarUrlTemplate == null) {
      try {
        final template = await _rainRadarService.getLatestRadarUrlTemplate();
        state = state.copyWith(rainRadarUrlTemplate: template);
      } catch (_) {}
    }
  }

  // --- OFFLINE MODE CONTROLS ---

  Future<void> toggleOfflineMode() async {
    final next = !state.isOfflineMode;
    state = state.copyWith(isOfflineMode: next);
    await _offlineForestService?.setForcedOffline(next);
  }

  Future<void> setOfflineMode(bool enabled) async {
    state = state.copyWith(isOfflineMode: enabled);
    await _offlineForestService?.setForcedOffline(enabled);
  }

  void refreshDownloadedAreas() {
    final areas = _offlineForestService?.getAreaSummaries() ?? const [];
    state = state.copyWith(downloadedAreas: areas);
  }

  Future<void> downloadOfflineArea({
    required String name,
    required LatLng center,
    double radiusKm = 5.0,
  }) async {
    final service = _offlineForestService;
    if (service == null) return;
    state = state.copyWith(
      isDownloadingOffline: true,
      offlineDownloadProgress: 0.05,
      offlineDownloadStatus: 'Przygotowanie do pobrania...',
    );

    try {
      await service.downloadArea(
        name: name,
        center: center,
        radiusKm: radiusKm,
        onProgress: (progress, status) {
          state = state.copyWith(
            offlineDownloadProgress: progress,
            offlineDownloadStatus: status,
          );
        },
      );
      final updated = service.getAreaSummaries();
      state = state.copyWith(
        isDownloadingOffline: false,
        downloadedAreas: updated,
        offlineDownloadProgress: 1.0,
        offlineDownloadStatus: 'Pobieranie zakończone!',
      );
    } catch (e) {
      state = state.copyWith(
        isDownloadingOffline: false,
        offlineDownloadStatus: 'Błąd pobierania: $e',
      );
    }
  }

  Future<void> deleteOfflineArea(String id) async {
    await _offlineForestService?.deleteArea(id);
    refreshDownloadedAreas();
  }
}

/// Provider for MapScreenState and its controller
final mapScreenProvider =
    StateNotifierProvider<MapScreenNotifier, MapScreenState>((ref) {
  return MapScreenNotifier(
    forestRepository: ref.watch(forestRepositoryProvider),
    weatherRepository: ref.watch(weatherRepositoryProvider),
    parkingService: ref.watch(parkingServiceProvider),
    locationService: ref.watch(locationServiceProvider),
    parcelRadarService: ref.watch(parcelRadarServiceProvider),
    rainRadarService: ref.watch(rainRadarServiceProvider),
    rainHeatmapService: ref.watch(rainHeatmapServiceProvider),
    preferencesService: ref.watch(preferencesServiceProvider),
    offlineForestService: ref.watch(offlineForestServiceProvider),
  );
});
