import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/di/providers.dart';
import 'core/routing/app_router.dart';
import 'core/services/preferences_service.dart';
import 'core/theme/app_theme.dart';
import 'features/offline_mode/data/offline_forest_service.dart';
import 'features/weather/data/datasources/weather_remote_data_source.dart';
import 'features/weather/data/repositories/weather_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set transparent dark status bar for Android / iOS
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.canvas,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final dio = createAppDio();
  final weatherRepository = WeatherRepositoryImpl(
    remoteDataSource: WeatherRemoteDataSourceImpl(dio: dio),
  );
  final preferencesService = PreferencesService();
  final offlineForestService = OfflineForestService(
    dio: dio,
    weatherRepository: weatherRepository,
  );

  try {
    await Future.wait([
      preferencesService.init(),
      offlineForestService.init(),
    ]);
  } catch (e) {
    debugPrint('[main] Storage pre-hydration failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        weatherRepositoryProvider.overrideWithValue(weatherRepository),
        preferencesServiceProvider.overrideWithValue(preferencesService),
        offlineForestServiceProvider.overrideWithValue(offlineForestService),
      ],
      child: const GrzybMapApp(),
    ),
  );
}

class GrzybMapApp extends StatelessWidget {
  const GrzybMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrzybMap Polska',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forestDark,
      initialRoute: AppRoutes.map,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
