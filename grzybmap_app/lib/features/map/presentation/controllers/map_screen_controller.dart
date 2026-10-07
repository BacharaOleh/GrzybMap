import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/gis_projection.dart';
import '../../../parcel_inspector/domain/models.dart';
import '../../../parcel_inspector/domain/repositories/forest_repository.dart';
import '../../../weather/domain/models.dart';
import '../../../weather/domain/repositories/weather_repository.dart';
import '../../../mushroom_radar/domain/models.dart';
import '../../../mushroom_radar/service/match_engine.dart';
import '../../../navigation/service/location_service.dart';
import '../../../navigation/service/parking_service.dart';

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
  });

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
    );
  }
}

/// StateNotifier handling map events, GIS inspection, multi-tier location, and data fetching.
class MapScreenNotifier extends StateNotifier<MapScreenState> {
  final ForestRepository _forestRepository;
  final WeatherRepository _weatherRepository;
  final ParkingService _parkingService;
  final LocationService _locationService;

  MapScreenNotifier({
    required ForestRepository forestRepository,
    required WeatherRepository weatherRepository,
    required ParkingService parkingService,
    required LocationService locationService,
  })  : _forestRepository = forestRepository,
        _weatherRepository = weatherRepository,
        _parkingService = parkingService,
        _locationService = locationService,
        super(MapScreenState(selectedMonth: DateTime.now().month));

  void cycleBaseLayer() {
    final next = switch (state.activeBaseLayer) {
      'satellite' => 'dark',
      'dark' => 'topo',
      'topo' => 'osm',
      _ => 'satellite',
    };
    state = state.copyWith(activeBaseLayer: next);
  }

  void dismissOnboarding() {
    state = state.copyWith(showOnboarding: false);
  }

  Future<LatLng?> locateUser() async {
    state = state.copyWith(
      isLocating: true,
      clearLocationErrorMessage: true,
    );

    try {
      final res = await _locationService.determineLocation();
      if (res != null) {
        state = state.copyWith(
          userLocation: res.position,
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

  Future<bool> inspectPoint(LatLng point, int zoom) async {
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
      );

      final weatherFuture = _weatherRepository.getRainfallHistory(
        lat: point.latitude,
        lng: point.longitude,
      );

      final results = await Future.wait([parcelFuture, weatherFuture]);
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
        isLoadingInspection: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        clearActiveParcel: true,
        clearActiveWeather: true,
        mushroomMatches: const [],
        isLoadingInspection: false,
      );
      return false;
    }
  }

  void saveCarLocation() {
    if (state.clickedPoint != null) {
      _parkingService.saveCarLocation(
        state.clickedPoint!.latitude,
        state.clickedPoint!.longitude,
      );
    }
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
  );
});
