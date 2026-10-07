import 'package:flutter/material.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/info/presentation/about_screen.dart';

/// Application route names and navigator generator.
class AppRoutes {
  AppRoutes._();

  static const String map = '/';
  static const String about = '/about';
}

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.about:
        return MaterialPageRoute(
          builder: (_) => const AboutScreen(),
          settings: settings,
        );
      case AppRoutes.map:
      default:
        return MaterialPageRoute(
          builder: (_) => const MapScreen(),
          settings: settings,
        );
    }
  }
}
