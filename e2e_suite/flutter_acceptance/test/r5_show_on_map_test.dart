import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/core/theme/app_theme.dart';
import 'package:grzybmap_app/features/foraging_journal/domain/models/foraging_spot.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/controllers/foraging_journal_controller.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/foraging_journal_screen.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/widgets/spot_details_sheet.dart';
import 'package:grzybmap_app/features/map/presentation/map_screen.dart';
import 'package:grzybmap_app/main.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/test_harness.dart';

ForagingSpot _distantSpot({
  String id = 'distant-1',
  String title = 'Sekretna Polana Łódzka',
  String mushroomId = 'borowik_szlachetny',
  String mushroomName = 'Borowik szlachetny (Prawdziwek)',
  double latitude = 51.9194,
  double longitude = 19.1451,
  String? photoPath,
  DateTime? foundAt,
}) {
  return ForagingSpot(
    id: id,
    title: title,
    mushroomId: mushroomId,
    mushroomName: mushroomName,
    mushroomEmoji: '🍄',
    quantityAmount: 3.0,
    quantityUnit: 'kg',
    latitude: latitude,
    longitude: longitude,
    foundAt: foundAt ?? DateTime(2026, 10, 16, 14, 30),
    notes: 'Ukryte stanowisko',
    photoPath: photoPath,
  );
}

Finder _findShowOnMapTrigger() {
  final byText = find.text('Pokaż na mapie');
  if (byText.evaluate().isNotEmpty) return byText;
  return find.byTooltip('Pokaż na mapie');
}

Future<void> _openJournalFromMap(WidgetTester tester) async {
  await tester.tap(find.text('Miejsca'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dziennik Grzybiarza'));
  await tester.pumpAndSettle();
  expect(find.byType(ForagingJournalScreen), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R5 "Show on Map" (Pokaż na mapie) Navigation — Tier 1', () {
    testWidgets('[Tier 1] R5: ForagingJournalScreen exposes Pokaż na mapie action on spot cards',
        (tester) async {
      final seeded = await seedLocalPreferences(initialSpots: [_distantSpot()]);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FallbackTestAssetBundle(),
          child: ProviderScope(
            overrides: [
              foragingJournalServiceProvider.overrideWithValue(seeded.journalService),
            ],
            child: MaterialApp(
              theme: AppTheme.forestDark,
              home: const ForagingJournalScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_findShowOnMapTrigger(), findsWidgets);
    });

    testWidgets('[Tier 1] R5: SpotDetailsSheet opened from ForagingJournalScreen renders Pokaż na mapie button',
        (tester) async {
      final seeded = await seedLocalPreferences(initialSpots: [_distantSpot()]);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FallbackTestAssetBundle(),
          child: ProviderScope(
            overrides: [
              foragingJournalServiceProvider.overrideWithValue(seeded.journalService),
            ],
            child: MaterialApp(
              theme: AppTheme.forestDark,
              home: const ForagingJournalScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sekretna Polana Łódzka'));
      await tester.pumpAndSettle();

      expect(find.byType(SpotDetailsSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SpotDetailsSheet),
          matching: find.text('Pokaż na mapie'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('[Tier 1] R5: Tapping Pokaż na mapie on card in ForagingJournalScreen closes journal and returns selected spot',
        (tester) async {
      final spot = _distantSpot();
      final seeded = await seedLocalPreferences(initialSpots: [spot]);
      ForagingSpot? returned;

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FallbackTestAssetBundle(),
          child: ProviderScope(
            overrides: [
              foragingJournalServiceProvider.overrideWithValue(seeded.journalService),
            ],
            child: MaterialApp(
              theme: AppTheme.forestDark,
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      final res = await Navigator.of(ctx).push<Object?>(
                        MaterialPageRoute<ForagingSpot?>(
                          builder: (_) => const ForagingJournalScreen(),
                        ),
                      );
                      if (res is ForagingSpot) returned = res;
                    },
                    child: const Text('Go Journal'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go Journal'));
      await tester.pumpAndSettle();
      expect(find.byType(ForagingJournalScreen), findsOneWidget);

      await tester.tap(_findShowOnMapTrigger().first);
      await tester.pumpAndSettle();

      expect(find.byType(ForagingJournalScreen), findsNothing);
      expect(returned, isNotNull);
      expect(returned!.id, spot.id);
      expect(returned!.latitude, closeTo(51.9194, 0.0001));
      expect(returned!.longitude, closeTo(19.1451, 0.0001));
    });

    testWidgets('[Tier 1] R5: Tapping Pokaż na mapie inside SpotDetailsSheet closes sheet and journal and returns to MapScreen',
        (tester) async {
      await withMockTileHttp(() async {
        final spot = _distantSpot();
        final seeded = await seedLocalPreferences(
          initialSpots: [spot],
          isJournalLayerVisible: true,
        );

        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: FallbackTestAssetBundle(),
            child: ProviderScope(
              overrides: buildTestOverrides(
                prefsService: seeded.prefsService,
                journalService: seeded.journalService,
              ),
              child: const GrzybMapApp(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await _openJournalFromMap(tester);

        await tester.tap(find.text('Sekretna Polana Łódzka'));
        await tester.pumpAndSettle();
        expect(find.byType(SpotDetailsSheet), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(SpotDetailsSheet),
            matching: find.text('Pokaż na mapie'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SpotDetailsSheet), findsNothing);
        expect(find.byType(ForagingJournalScreen), findsNothing);
        expect(find.byType(MapScreen), findsOneWidget);
      });
    });

    testWidgets('[Tier 1] R5: MapScreen centers FlutterMap camera on spot coordinates with zoom >= 15.0 after Pokaż na mapie',
        (tester) async {
      await withMockTileHttp(() async {
        final spot = _distantSpot();
        final seeded = await seedLocalPreferences(
          initialSpots: [spot],
          isJournalLayerVisible: true,
        );

        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: FallbackTestAssetBundle(),
            child: ProviderScope(
              overrides: buildTestOverrides(
                prefsService: seeded.prefsService,
                journalService: seeded.journalService,
              ),
              child: const GrzybMapApp(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await _openJournalFromMap(tester);
        await tester.tap(_findShowOnMapTrigger().first);
        await tester.pumpAndSettle();

        final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
        final camera = flutterMap.mapController!.camera;
        expect(camera.center.latitude, closeTo(51.9194, 0.001));
        expect(camera.center.longitude, closeTo(19.1451, 0.001));
        expect(camera.zoom, greaterThanOrEqualTo(15.0));
      });
    });
  });

  group('R5 "Show on Map" Layer Visibility & Corner Cases — Tier 2', () {
    testWidgets('[Tier 2] R5: Pokaż na mapie forces journal layer visible when show_secret_spots_layer was false initially',
        (tester) async {
      await withMockTileHttp(() async {
        final spot = _distantSpot();
        final seeded = await seedLocalPreferences(
          initialSpots: [spot],
          isJournalLayerVisible: false,
        );

        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: FallbackTestAssetBundle(),
            child: ProviderScope(
              overrides: buildTestOverrides(
                prefsService: seeded.prefsService,
                journalService: seeded.journalService,
              ),
              child: const GrzybMapApp(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final mapElement = tester.element(find.byType(MapScreen));
        final container = ProviderScope.containerOf(mapElement);
        expect(container.read(foragingJournalProvider).isLayerVisible, isFalse);

        await _openJournalFromMap(tester);
        await tester.tap(_findShowOnMapTrigger().first);
        await tester.pumpAndSettle();

        expect(
          container.read(foragingJournalProvider).isLayerVisible,
          isTrue,
          reason:
              'R5 requires Pokaż na mapie to ensure the spots map layer is visible when returning to MapScreen',
        );
        expect(
          find.textContaining('3 kg'),
          findsOneWidget,
          reason: 'Spot marker pill must be rendered on MapScreen after Pokaż na mapie',
        );
      });
    });

    testWidgets('[Tier 2] R5: Pokaż na mapie keeps layer visible and marker rendered when layer was already visible',
        (tester) async {
      await withMockTileHttp(() async {
        final spot = _distantSpot();
        final seeded = await seedLocalPreferences(
          initialSpots: [spot],
          isJournalLayerVisible: true,
        );

        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: FallbackTestAssetBundle(),
            child: ProviderScope(
              overrides: buildTestOverrides(
                prefsService: seeded.prefsService,
                journalService: seeded.journalService,
              ),
              child: const GrzybMapApp(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await _openJournalFromMap(tester);
        await tester.tap(_findShowOnMapTrigger().first);
        await tester.pumpAndSettle();

        final container =
            ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
        expect(container.read(foragingJournalProvider).isLayerVisible, isTrue);
        expect(find.textContaining('3 kg'), findsOneWidget);
      });
    });

    testWidgets('[Tier 2] R5: Sequential Pokaż na mapie navigations to two distant spots recenter FlutterMap to each spot',
        (tester) async {
      await withMockTileHttp(() async {
        final spotA = _distantSpot(
          id: 'spot-a',
          title: 'Polana A',
          latitude: 50.0647,
          longitude: 19.9450,
          foundAt: DateTime(2026, 10, 17, 10, 0),
        );
        final spotB = _distantSpot(
          id: 'spot-b',
          title: 'Polana B',
          latitude: 54.3520,
          longitude: 18.6466,
          foundAt: DateTime(2026, 10, 16, 10, 0),
        );
        final seeded = await seedLocalPreferences(
          initialSpots: [spotA, spotB],
          isJournalLayerVisible: true,
        );

        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: FallbackTestAssetBundle(),
            child: ProviderScope(
              overrides: buildTestOverrides(
                prefsService: seeded.prefsService,
                journalService: seeded.journalService,
              ),
              child: const GrzybMapApp(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // First spot (Kraków)
        await _openJournalFromMap(tester);
        await tester.tap(_findShowOnMapTrigger().at(0));
        await tester.pumpAndSettle();

        var camera = tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;
        expect(camera.center.latitude, closeTo(50.0647, 0.001));
        expect(camera.center.longitude, closeTo(19.9450, 0.001));

        // Second spot (Gdańsk)
        await _openJournalFromMap(tester);
        await tester.tap(_findShowOnMapTrigger().at(1));
        await tester.pumpAndSettle();

        camera = tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;
        expect(camera.center.latitude, closeTo(54.3520, 0.001));
        expect(camera.center.longitude, closeTo(18.6466, 0.001));
      });
    });

    testWidgets('[Tier 2] R5: Pokaż na mapie centers map properly even when species filter is active in ForagingJournalScreen',
        (tester) async {
      await withMockTileHttp(() async {
        final borowik = _distantSpot(
          id: 'b-1',
          title: 'Las Borowikowy',
          mushroomId: 'borowik_szlachetny',
          mushroomName: 'Borowik szlachetny (Prawdziwek)',
          latitude: 52.4064,
          longitude: 16.9252,
          foundAt: DateTime(2026, 10, 17, 12, 0),
        );
        final kurka = _distantSpot(
          id: 'k-1',
          title: 'Złote Kurki',
          mushroomId: 'pieprznik_jadalny',
          mushroomName: 'Pieprznik jadalny (Kurka)',
          latitude: 53.1325,
          longitude: 23.1688,
          foundAt: DateTime(2026, 10, 16, 12, 0),
        );
        final seeded = await seedLocalPreferences(
          initialSpots: [borowik, kurka],
          isJournalLayerVisible: true,
        );

        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: FallbackTestAssetBundle(),
            child: ProviderScope(
              overrides: buildTestOverrides(
                prefsService: seeded.prefsService,
                journalService: seeded.journalService,
              ),
              child: const GrzybMapApp(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await _openJournalFromMap(tester);

        final kurkaFilter = find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.text('Pieprznik jadalny (Kurka)'),
        );
        await tester.ensureVisible(kurkaFilter);
        await tester.pumpAndSettle();
        await tester.tap(kurkaFilter);
        await tester.pumpAndSettle();

        expect(find.text('Złote Kurki'), findsOneWidget);
        expect(find.text('Las Borowikowy'), findsNothing);

        await tester.tap(_findShowOnMapTrigger().first);
        await tester.pumpAndSettle();

        final camera = tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;
        expect(camera.center.latitude, closeTo(53.1325, 0.001));
        expect(camera.center.longitude, closeTo(23.1688, 0.001));
      });
    });

    testWidgets('[Tier 2] R5: Pokaż na mapie works for a spot with an attached user photo and displays marker on MapScreen',
        (tester) async {
      await withMockTileHttp(() async {
        final photoSpot = _distantSpot(
          id: 'photo-spot',
          title: 'Złoty Zagajnik',
          latitude: 51.1079,
          longitude: 17.0385,
          photoPath: kTransparent1x1PngBase64,
        );
        final seeded = await seedLocalPreferences(
          initialSpots: [photoSpot],
          isJournalLayerVisible: true,
        );

        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: FallbackTestAssetBundle(),
            child: ProviderScope(
              overrides: buildTestOverrides(
                prefsService: seeded.prefsService,
                journalService: seeded.journalService,
              ),
              child: const GrzybMapApp(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await _openJournalFromMap(tester);
        await tester.tap(_findShowOnMapTrigger().first);
        await tester.pumpAndSettle();

        final camera = tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;
        expect(camera.center.latitude, closeTo(51.1079, 0.001));
        expect(camera.center.longitude, closeTo(17.0385, 0.001));
        expect(find.textContaining('3 kg'), findsOneWidget);
      });
    });
  });

  group('R5 End-to-End Map & Journal Parity Flow — Tier 4 Scenario', () {
    testWidgets('[Tier 4] R5: Full flow from MapScreen -> Journal -> SpotDetailsSheet -> Pokaż na mapie enables layer, centers map, and preserves R2 layout',
        (tester) async {
      await withMockTileHttp(() async {
        final spot = _distantSpot(
          id: 'tier4-spot',
          title: 'Bieszczadzka Polana',
          latitude: 49.2512,
          longitude: 22.4119,
          photoPath: kTransparent1x1PngBase64,
        );
        final seeded = await seedLocalPreferences(
          initialSpots: [spot],
          isJournalLayerVisible: false,
        );

        await tester.pumpWidget(
          DefaultAssetBundle(
            bundle: FallbackTestAssetBundle(),
            child: ProviderScope(
              overrides: buildTestOverrides(
                prefsService: seeded.prefsService,
                journalService: seeded.journalService,
              ),
              child: const GrzybMapApp(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await _openJournalFromMap(tester);
        await tester.tap(find.text('Bieszczadzka Polana'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(SpotDetailsSheet),
            matching: find.text('Pokaż na mapie'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ForagingJournalScreen), findsNothing);
        expect(find.byType(MapScreen), findsOneWidget);

        final container =
            ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
        expect(container.read(foragingJournalProvider).isLayerVisible, isTrue);

        final camera = tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;
        expect(camera.center.latitude, closeTo(49.2512, 0.001));
        expect(camera.center.longitude, closeTo(22.4119, 0.001));
        expect(camera.zoom, greaterThanOrEqualTo(15.0));
        expect(find.textContaining('3 kg'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
