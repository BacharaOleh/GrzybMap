import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/core/routing/app_router.dart';
import 'package:grzybmap_app/core/theme/app_theme.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/foraging_journal_screen.dart';
import 'package:grzybmap_app/features/forest_search/presentation/widgets/forest_search_bar.dart';
import 'package:grzybmap_app/features/info/presentation/about_screen.dart';
import 'package:grzybmap_app/features/map/presentation/map_screen.dart';
import 'package:grzybmap_app/features/map/presentation/widgets/car_fab.dart';
import 'package:grzybmap_app/features/map/presentation/widgets/gps_fab.dart';
import 'package:grzybmap_app/features/map/presentation/widgets/map_top_bar.dart';
import 'package:grzybmap_app/features/map/presentation/widgets/tactical_island_bar.dart';
import 'package:grzybmap_app/main.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R2 Visual & Layout Invariants — Tier 1', () {
    testWidgets('[Tier 1] R2: AppTheme.forestDark uses dark brightness and exact forest canvas color',
        (tester) async {
      final theme = AppTheme.forestDark;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF060B08));
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.emeraldNeon);
      expect(theme.colorScheme.error, AppColors.danger);
    });

    testWidgets('[Tier 1] R2: AppColors defines exact tactical palette tokens',
        (tester) async {
      expect(AppColors.canvas, const Color(0xFF060B08));
      expect(AppColors.surface, const Color(0xFF0E1811));
      expect(AppColors.emeraldNeon, const Color(0xFF34D399));
      expect(AppColors.danger, const Color(0xFFF87171));
      expect(AppColors.amberWarn, const Color(0xFFF59E0B));
      expect(AppColors.skyBlue, const Color(0xFF38BDF8));
    });

    testWidgets('[Tier 1] R2: MapTopBar Row uses CrossAxisAlignment.start, ForestSearchBar, and red SOS text',
        (tester) async {
      final seeded = await seedLocalPreferences();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildTestOverrides(
            prefsService: seeded.prefsService,
            journalService: seeded.journalService,
          ),
          child: MaterialApp(
            theme: AppTheme.forestDark,
            home: Scaffold(
              body: MapTopBar(
                onOpenSos: () {},
                onSelectPlace: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ForestSearchBar), findsOneWidget);
      final sosFinder = find.text('SOS');
      expect(sosFinder, findsOneWidget);

      final sosText = tester.widget<Text>(sosFinder);
      expect(sosText.style?.color, AppColors.danger);

      // Verify the Row containing ForestSearchBar and SOS uses CrossAxisAlignment.start
      final topRows = tester.widgetList<Row>(
        find.descendant(of: find.byType(MapTopBar), matching: find.byType(Row)),
      );
      final hasStartRow = topRows.any(
        (r) => r.crossAxisAlignment == CrossAxisAlignment.start,
      );
      expect(hasStartRow, isTrue,
          reason: 'MapTopBar must align ForestSearchBar and SOS with CrossAxisAlignment.start');
    });

    testWidgets('[Tier 1] R2: TacticalIslandBar renders MushroomVectorIcon with CustomPaint and zero mushroom emoji labels',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forestDark,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TacticalIslandBar(
                isRadarsActive: true,
                onToggleRadars: () {},
                journalSpotsCount: 2,
                onOpenJournal: () {},
                onQuickAddSpot: () {},
                offlineAreasCount: 1,
                isOfflineMode: false,
                onOpenOffline: () {},
                activeLayerLabel: 'Satelita',
                onCycleLayer: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MushroomVectorIcon), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MushroomVectorIcon),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(find.text('Radary'), findsOneWidget);
      expect(find.text('Miejsca'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Satelita'), findsOneWidget);

      // Ensure zero emoji in TacticalIslandBar tile labels
      final texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(TacticalIslandBar),
          matching: find.byType(Text),
        ),
      );
      for (final t in texts) {
        expect(t.data?.contains('🍄') ?? false, isFalse,
            reason: 'TacticalIslandBar must use MushroomVectorIcon instead of 🍄 emoji');
      }
    });

    testWidgets('[Tier 1] R2: MapScreen mounts MapTopBar, CarFab, GpsFab, and TacticalIslandBar cleanly',
        (tester) async {
      await withMockTileHttp(() async {
        final seeded = await seedLocalPreferences();
        await tester.pumpWidget(
          ProviderScope(
            overrides: buildTestOverrides(
              prefsService: seeded.prefsService,
              journalService: seeded.journalService,
            ),
            child: MaterialApp(
              theme: AppTheme.forestDark,
              home: const MapScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(MapTopBar), findsOneWidget);
        expect(find.byType(CarFab), findsOneWidget);
        expect(find.byType(GpsFab), findsOneWidget);
        expect(find.byType(TacticalIslandBar), findsOneWidget);
      });
    });
  });

  group('R2 Visual & Layout Invariants — Tier 2 Boundary & Responsive Geometry', () {
    testWidgets('[Tier 2] R2: MapTopBar SOS pill stays top-aligned within bar band even when offline banner is active',
        (tester) async {
      final seeded = await seedLocalPreferences();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildTestOverrides(
            prefsService: seeded.prefsService,
            journalService: seeded.journalService,
          ),
          child: MaterialApp(
            theme: AppTheme.forestDark,
            home: Scaffold(
              body: MapTopBar(
                isOfflineMode: true,
                onOpenOfflineAreas: () {},
                onOpenSos: () {},
                onSelectPlace: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchTop = tester.getTopLeft(find.byType(ForestSearchBar)).dy;
      final sosTop = tester.getTopLeft(find.text('SOS')).dy;
      final sosCenterY = tester.getCenter(find.text('SOS')).dy;

      expect(sosTop, greaterThanOrEqualTo(searchTop));
      expect(sosCenterY, lessThanOrEqualTo(searchTop + 46.0));
    });

    testWidgets('[Tier 2] R2: TacticalIslandBar preserves MushroomVectorIcon and uppercase OFFLINE label when target mushroom & offline active',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forestDark,
          home: Scaffold(
            body: TacticalIslandBar(
              isRadarsActive: true,
              targetMushroomName: 'Borowik',
              onToggleRadars: () {},
              journalSpotsCount: 0,
              onOpenJournal: () {},
              onQuickAddSpot: () {},
              offlineAreasCount: 0,
              isOfflineMode: true,
              onOpenOffline: () {},
              activeLayerLabel: 'Ciemna',
              onCycleLayer: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MushroomVectorIcon), findsOneWidget);
      expect(find.text('Borowik'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('Miejsca'), findsOneWidget);
      expect(find.text('Ciemna'), findsOneWidget);
    });

    testWidgets('[Tier 2] R2: MapScreen geometry at desktop viewport (800x600) keeps CarFab above GpsFab above TacticalIslandBar',
        (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await withMockTileHttp(() async {
        final seeded = await seedLocalPreferences();
        await tester.pumpWidget(
          ProviderScope(
            overrides: buildTestOverrides(
              prefsService: seeded.prefsService,
              journalService: seeded.journalService,
            ),
            child: MaterialApp(
              theme: AppTheme.forestDark,
              home: const MapScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final carRect = tester.getRect(find.byType(CarFab));
        final gpsRect = tester.getRect(find.byType(GpsFab));
        final islandRect = tester.getRect(find.byType(TacticalIslandBar));

        expect(carRect.center.dy, lessThan(gpsRect.center.dy));
        expect(carRect.bottom, lessThanOrEqualTo(gpsRect.top));
        expect(gpsRect.bottom, lessThan(islandRect.top));
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('[Tier 2] R2: MapScreen geometry at mobile viewport (412x915) keeps CarFab above GpsFab above TacticalIslandBar with zero overflow',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await withMockTileHttp(() async {
        final seeded = await seedLocalPreferences();
        await tester.pumpWidget(
          ProviderScope(
            overrides: buildTestOverrides(
              prefsService: seeded.prefsService,
              journalService: seeded.journalService,
            ),
            child: MaterialApp(
              theme: AppTheme.forestDark,
              home: const MapScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final carRect = tester.getRect(find.byType(CarFab));
        final gpsRect = tester.getRect(find.byType(GpsFab));
        final islandRect = tester.getRect(find.byType(TacticalIslandBar));

        expect(carRect.center.dy, lessThan(gpsRect.center.dy));
        expect(carRect.bottom, lessThanOrEqualTo(gpsRect.top));
        expect(gpsRect.bottom, lessThan(islandRect.top));
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('[Tier 2] R2: MapScreen with parked car location preserves CarFab above GpsFab without overlap or overflow',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await withMockTileHttp(() async {
        final seeded = await seedLocalPreferences(
          carLocation: const LatLng(52.055, 21.385),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: buildTestOverrides(
              prefsService: seeded.prefsService,
              journalService: seeded.journalService,
            ),
            child: MaterialApp(
              theme: AppTheme.forestDark,
              home: const MapScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final carRect = tester.getRect(find.byType(CarFab));
        final gpsRect = tester.getRect(find.byType(GpsFab));
        final islandRect = tester.getRect(find.byType(TacticalIslandBar));

        expect(carRect.bottom, lessThanOrEqualTo(gpsRect.top));
        expect(gpsRect.bottom, lessThan(islandRect.top));
        expect(tester.takeException(), isNull);
      });
    });
  });

  group('R2 Cross-Route Tactical Theme Parity — Tier 3', () {
    testWidgets('[Tier 3] R2: GrzybMapApp boots on MapScreen and routes cleanly to /journal and /about preserving dark theme',
        (tester) async {
      await withMockTileHttp(() async {
        final seeded = await seedLocalPreferences();
        await tester.pumpWidget(
          ProviderScope(
            overrides: buildTestOverrides(
              prefsService: seeded.prefsService,
              journalService: seeded.journalService,
            ),
            child: const GrzybMapApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(MapScreen), findsOneWidget);
        final mapContext = tester.element(find.byType(MapScreen));
        expect(Theme.of(mapContext).brightness, Brightness.dark);

        // Navigate to /journal and back
        final nav = Navigator.of(mapContext);
        nav.pushNamed(AppRoutes.journal);
        await tester.pumpAndSettle();
        expect(find.byType(ForagingJournalScreen), findsOneWidget);
        nav.pop();
        await tester.pumpAndSettle();
        expect(find.byType(MapScreen), findsOneWidget);

        // Navigate to /about and back
        nav.pushNamed(AppRoutes.about);
        await tester.pumpAndSettle();
        expect(find.byType(AboutScreen), findsOneWidget);
        nav.pop();
        await tester.pumpAndSettle();
        expect(find.byType(MapScreen), findsOneWidget);
      });
    });
  });
}
