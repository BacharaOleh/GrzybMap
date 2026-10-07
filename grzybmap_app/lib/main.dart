import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
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

  runApp(
    const ProviderScope(
      child: GrzybMapApp(),
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
