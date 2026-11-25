import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/core/di/providers.dart';
import 'package:grzybmap_app/core/services/preferences_service.dart';
import 'package:grzybmap_app/features/foraging_journal/data/foraging_journal_service.dart';
import 'package:grzybmap_app/features/foraging_journal/domain/models/foraging_spot.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/controllers/foraging_journal_controller.dart';
import 'package:grzybmap_app/features/forest_reports/data/report_repository.dart';
import 'package:grzybmap_app/features/mushroom_radar/domain/parcel_radar.dart';
import 'package:grzybmap_app/features/mushroom_radar/service/parcel_radar_service.dart';
import 'package:grzybmap_app/features/navigation/service/location_service.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/models.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/repositories/forest_repository.dart';
import 'package:grzybmap_app/features/weather/domain/models.dart';
import 'package:grzybmap_app/features/weather/domain/repositories/weather_repository.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Valid 1x1 transparent PNG bytes (67 bytes).
final Uint8List kTransparent1x1PngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

const String kTransparent1x1PngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

/// Valid 2x2 emerald PNG bytes for distinct user photo rendering checks.
final Uint8List kEmerald2x2PngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEklEQVR42mNk+M/wHwMDAwMjAAYAAf8B/wAAAABJRU5ErkJggg==',
);

/// Mock [HttpOverrides] returning a valid 1x1 PNG with HTTP 200 so `flutter_map`
/// `TileLayer` never hits external servers or raises HTTP 400 errors in widget tests.
class MockTileHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Duration? connectionTimeout;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  int? maxConnectionsPerHost;

  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final Uri uri;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  _FakeHttpClientRequest(this.uri);

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => kTransparent1x1PngBytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([kTransparent1x1PngBytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWeatherRepository implements WeatherRepository {
  @override
  Future<WeatherRainfall?> getRainfallHistory({
    required double lat,
    required double lng,
    dynamic cancelToken,
  }) async =>
      null;
}

class FakeForestRepository implements ForestRepository {
  @override
  Future<ForestParcel?> getParcelAt({
    required double lat,
    required double lng,
    required String bbox3857,
    required int width,
    required int height,
    required int pixelX,
    required int pixelY,
    required int zoom,
    CancelToken? cancelToken,
  }) async =>
      null;
}

class FakeParcelRadarService implements ParcelRadarService {
  @override
  void clearCache() {}

  @override
  Future<List<ParcelRadarItem>> fetchVisibleRadars({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    WeatherRainfall? weather,
    required int selectedMonth,
    String? targetMushroomId,
    double zoom = 15.0,
    int minProbability = 50,
    int maxLimit = 20,
    double minPixelDistance = 75.0,
    CancelToken? cancelToken,
  }) async =>
      const [];
}

class FakeLocationService extends LocationService {
  final LocationResult? stubbedResult;

  FakeLocationService({this.stubbedResult}) : super(Dio());

  @override
  Future<LocationResult?> determineLocation() async => stubbedResult;
}

class FakeForestReportsNotifier extends ForestReportsNotifier {
  FakeForestReportsNotifier() : super(dio: Dio());

  @override
  Future<void> loadReports() async {
    state = const ForestReportsState(reports: [], isLoading: false);
  }
}

/// Asset bundle returning 1x1 PNG bytes for `assets/mushrooms/*.webp` when
/// running from an isolated external package, while delegating other assets.
class FallbackTestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.startsWith('assets/mushrooms/')) {
      return ByteData.sublistView(kTransparent1x1PngBytes);
    }
    return rootBundle.load(key);
  }
}

/// Creates a real temporary image file on disk and registers a mock
/// `plugins.flutter.io/image_picker` platform channel returning its path.
class MockImagePickerFixture {
  static const MethodChannel _channel =
      MethodChannel('plugins.flutter.io/image_picker');

  final Directory tempDir;
  final File imageFile;
  int callCount = 0;

  MockImagePickerFixture._(this.tempDir, this.imageFile);

  factory MockImagePickerFixture.create({String fileName = 'foraging_find.png'}) {
    final dir = Directory.systemTemp.createTempSync('grzybmap_e2e_img_');
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    file.writeAsBytesSync(kTransparent1x1PngBytes);
    return MockImagePickerFixture._(dir, file);
  }

  void install({bool returnNull = false}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall methodCall) async {
      callCount++;
      if (methodCall.method == 'pickImage') {
        return returnNull ? null : imageFile.path;
      }
      if (methodCall.method == 'pickMultiImage') {
        return returnNull ? <String>[] : <String>[imageFile.path];
      }
      if (methodCall.method == 'retrieveLostData') {
        return null;
      }
      return null;
    });
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  }
}

/// Seeds mock [SharedPreferences] with optional foraging spots and layer visibility,
/// and returns initialized [PreferencesService] and [ForagingJournalService].
Future<({SharedPreferences prefs, PreferencesService prefsService, ForagingJournalService journalService})>
    seedLocalPreferences({
  List<ForagingSpot> initialSpots = const [],
  bool isJournalLayerVisible = true,
  bool onboardingDismissed = true,
  LatLng? carLocation,
}) async {
  final initial = <String, Object>{
    'show_secret_spots_layer': isJournalLayerVisible,
    'onboarding_dismissed': onboardingDismissed,
    if (initialSpots.isNotEmpty)
      'foraging_secret_spots': initialSpots.map((s) => s.toJson()).toList(),
    if (carLocation != null) 'car_lat': carLocation.latitude,
    if (carLocation != null) 'car_lng': carLocation.longitude,
    if (carLocation != null) 'car_time': DateTime(2026, 10, 16, 10, 0).toIso8601String(),
  };
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final prefsService = PreferencesService(prefs);
  await prefsService.init();
  final journalService = ForagingJournalService(prefs);
  await journalService.init();
  return (
    prefs: prefs,
    prefsService: prefsService,
    journalService: journalService,
  );
}

List<Override> buildTestOverrides({
  required PreferencesService prefsService,
  required ForagingJournalService journalService,
  LocationResult? locationResult,
}) {
  return [
    preferencesServiceProvider.overrideWithValue(prefsService),
    foragingJournalServiceProvider.overrideWithValue(journalService),
    weatherRepositoryProvider.overrideWithValue(FakeWeatherRepository()),
    forestRepositoryProvider.overrideWithValue(FakeForestRepository()),
    parcelRadarServiceProvider.overrideWithValue(FakeParcelRadarService()),
    locationServiceProvider
        .overrideWithValue(FakeLocationService(stubbedResult: locationResult)),
    forestReportsProvider.overrideWith((ref) => FakeForestReportsNotifier()),
  ];
}

/// Executes [body] with [MockTileHttpOverrides] installed and restores previous
/// [HttpOverrides.current] afterwards.
Future<T> withMockTileHttp<T>(Future<T> Function() body) async {
  return HttpOverrides.runZoned(
    body,
    createHttpClient: (SecurityContext? context) =>
        MockTileHttpOverrides().createHttpClient(context),
  );
}
