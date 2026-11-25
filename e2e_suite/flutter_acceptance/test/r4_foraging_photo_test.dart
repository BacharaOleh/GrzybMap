import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/core/theme/app_theme.dart';
import 'package:grzybmap_app/features/foraging_journal/data/foraging_journal_service.dart';
import 'package:grzybmap_app/features/foraging_journal/domain/models/foraging_spot.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/controllers/foraging_journal_controller.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/foraging_journal_screen.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/widgets/save_spot_dialog.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/widgets/spot_details_sheet.dart';
import 'package:grzybmap_app/features/map/presentation/widgets/mushroom_photo_widget.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_harness.dart';

ForagingSpot _makeSpot({
  String id = 'spot-1',
  String title = 'Polana Borowikowa',
  String mushroomId = 'borowik_szlachetny',
  String mushroomName = 'Borowik szlachetny (Prawdziwek)',
  double latitude = 52.2297,
  double longitude = 21.0122,
  String? photoPath,
  String notes = 'Pod starymi dębami',
}) {
  return ForagingSpot(
    id: id,
    title: title,
    mushroomId: mushroomId,
    mushroomName: mushroomName,
    mushroomEmoji: '🍄',
    quantityAmount: 2.0,
    quantityUnit: 'kg',
    latitude: latitude,
    longitude: longitude,
    foundAt: DateTime(2026, 10, 16, 14, 30),
    notes: notes,
    forestParcelId: '14-01-02-03',
    photoPath: photoPath,
  );
}

Finder _findPhotoAttachTrigger() {
  final byText = find.text('Dodaj zdjęcie do znaleziska');
  if (byText.evaluate().isNotEmpty) return byText;
  final byAltText = find.textContaining('Dodaj zdjęcie');
  if (byAltText.evaluate().isNotEmpty) return byAltText;
  return find.byIcon(Icons.add_a_photo_rounded);
}

Finder _findGallerySourceOption() {
  final byText = find.text('Wybierz z galerii');
  if (byText.evaluate().isNotEmpty) return byText;
  return find.byIcon(Icons.photo_library_rounded);
}

bool _hasNonStockImageWidget(WidgetTester tester, {Finder? within}) {
  final imageFinder = within != null
      ? find.descendant(of: within, matching: find.byType(Image))
      : find.byType(Image);
  for (final img in tester.widgetList<Image>(imageFinder)) {
    if (img.image is! AssetImage) {
      return true;
    }
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R4 Foraging Journal Photo Attachment & Persistence — Tier 1', () {
    testWidgets('[Tier 1] R4: ForagingSpot JSON roundtrip preserves photoPath and decodes legacy JSON without photoPath as null',
        (tester) async {
      final withPhoto = _makeSpot(photoPath: kTransparent1x1PngBase64);
      final restoredWithPhoto = ForagingSpot.fromJson(withPhoto.toJson());
      expect(restoredWithPhoto.photoPath, kTransparent1x1PngBase64);
      expect(restoredWithPhoto.hasPhoto, isTrue);

      final legacyJson = jsonEncode({
        'id': 'legacy-1',
        'title': 'Stare miejsce',
        'mushroomId': 'borowik_szlachetny',
        'mushroomName': 'Borowik szlachetny',
        'mushroomEmoji': '🍄',
        'quantityAmount': 1.5,
        'quantityUnit': 'kg',
        'latitude': 52.1,
        'longitude': 21.1,
        'foundAt': '2026-09-01T10:00:00.000',
      });
      final restoredLegacy = ForagingSpot.fromJson(legacyJson);
      expect(restoredLegacy.photoPath, isNull);
      expect(restoredLegacy.hasPhoto, isFalse);
    });

    testWidgets('[Tier 1] R4: ForagingJournalService persists spot photoPath across service re-instantiation',
        (tester) async {
      final seeded = await seedLocalPreferences();
      final spot = _makeSpot(id: 'persist-1', photoPath: kTransparent1x1PngBase64);
      await seeded.journalService.saveSpot(spot);

      final reloadedService = ForagingJournalService(seeded.prefs);
      await reloadedService.init();
      final spots = reloadedService.getSpots();

      expect(spots.length, 1);
      expect(spots.first.id, 'persist-1');
      expect(spots.first.photoPath, kTransparent1x1PngBase64);
    });

    testWidgets('[Tier 1] R4: SaveSpotDialog attaches a photo via image_picker, previews it, and persists photoPath',
        (tester) async {
      final pickerFixture = MockImagePickerFixture.create();
      pickerFixture.install();
      addTearDown(pickerFixture.dispose);

      final seeded = await seedLocalPreferences();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foragingJournalServiceProvider.overrideWithValue(seeded.journalService),
          ],
          child: MaterialApp(
            theme: AppTheme.forestDark,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    SaveSpotDialog.show(
                      context: ctx,
                      location: const LatLng(52.23, 21.01),
                    );
                  },
                  child: const Text('Open SaveSpotDialog'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open SaveSpotDialog'));
      await tester.pumpAndSettle();

      final attachTrigger = _findPhotoAttachTrigger();
      expect(attachTrigger, findsOneWidget);
      await tester.ensureVisible(attachTrigger);
      await tester.pumpAndSettle();
      await tester.tap(attachTrigger);
      await tester.pumpAndSettle();

      final galleryOption = _findGallerySourceOption();
      if (galleryOption.evaluate().isNotEmpty) {
        await tester.tap(galleryOption);
        await tester.pumpAndSettle();
      }

      expect(pickerFixture.callCount, greaterThanOrEqualTo(1));
      expect(_hasNonStockImageWidget(tester, within: find.byType(SaveSpotDialog)), isTrue,
          reason: 'SaveSpotDialog must render a preview of the picked user photo');

      final saveBtn = find.text('Zapisz w Dzienniku');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      final reloaded = ForagingJournalService(seeded.prefs);
      await reloaded.init();
      final savedSpots = reloaded.getSpots();
      expect(savedSpots.length, 1);
      expect(savedSpots.first.photoPath, isNotNull);
      expect(savedSpots.first.photoPath!.trim(), isNotEmpty);
      expect(savedSpots.first.hasPhoto, isTrue);
    });

    testWidgets('[Tier 1] R4: ForagingJournalScreen renders MushroomPhotoWidget stock fallback when photoPath is null',
        (tester) async {
      final spotNoPhoto = _makeSpot(id: 'no-photo', photoPath: null);
      final seeded = await seedLocalPreferences(initialSpots: [spotNoPhoto]);

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

      expect(find.text('Polana Borowikowa'), findsOneWidget);
      expect(find.byType(MushroomPhotoWidget), findsOneWidget);
      expect(_hasNonStockImageWidget(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('[Tier 1] R4: SpotDetailsSheet renders attached user photo and metadata cleanly',
        (tester) async {
      final spotWithPhoto = _makeSpot(
        id: 'detail-photo',
        photoPath: kTransparent1x1PngBase64,
      );

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FallbackTestAssetBundle(),
          child: MaterialApp(
            theme: AppTheme.forestDark,
            home: Scaffold(
              body: SpotDetailsSheet(
                spot: spotWithPhoto,
                onDelete: () {},
                onNavigate: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Polana Borowikowa'), findsOneWidget);
      expect(_hasNonStockImageWidget(tester, within: find.byType(SpotDetailsSheet)), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('R4 Foraging Journal Photo Edge Cases, Fallbacks & Draft/Edit — Tier 2', () {
    testWidgets('[Tier 2] R4: SaveSpotDialog allows removing an attached photo and saves spot with photoPath == null',
        (tester) async {
      final seeded = await seedLocalPreferences();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foragingJournalServiceProvider.overrideWithValue(seeded.journalService),
          ],
          child: MaterialApp(
            theme: AppTheme.forestDark,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    SaveSpotDialog.show(
                      context: ctx,
                      location: const LatLng(52.23, 21.01),
                      initialPhotoBase64: kTransparent1x1PngBase64,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final removeBtn = find.byTooltip('Usuń zdjęcie');
      expect(removeBtn, findsOneWidget);
      await tester.ensureVisible(removeBtn);
      await tester.pumpAndSettle();
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();

      final saveBtn = find.text('Zapisz w Dzienniku');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      final spots = seeded.journalService.getSpots();
      expect(spots.length, 1);
      expect(spots.first.hasPhoto, isFalse);
    });

    testWidgets('[Tier 2] R4: ForagingJournalScreen and SpotDetailsSheet fall back gracefully with zero errors on invalid or missing photoPath',
        (tester) async {
      final invalidSpot = _makeSpot(
        id: 'corrupt-photo',
        photoPath: '/nonexistent/path/missing_photo_12345.jpg',
      );
      final seeded = await seedLocalPreferences(initialSpots: [invalidSpot]);

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

      expect(find.text('Polana Borowikowa'), findsOneWidget);
      expect(find.byType(MushroomPhotoWidget), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Polana Borowikowa'));
      await tester.pumpAndSettle();

      expect(find.byType(SpotDetailsSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('[Tier 2] R4: SaveSpotDialog handles cancelled image picker (null file) gracefully',
        (tester) async {
      final pickerFixture = MockImagePickerFixture.create();
      pickerFixture.install(returnNull: true);
      addTearDown(pickerFixture.dispose);

      final seeded = await seedLocalPreferences();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foragingJournalServiceProvider.overrideWithValue(seeded.journalService),
          ],
          child: MaterialApp(
            theme: AppTheme.forestDark,
            home: const Scaffold(
              body: SaveSpotDialog(
                location: LatLng(52.23, 21.01),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final attachTrigger = _findPhotoAttachTrigger();
      await tester.ensureVisible(attachTrigger);
      await tester.pumpAndSettle();
      await tester.tap(attachTrigger);
      await tester.pumpAndSettle();

      final galleryOption = _findGallerySourceOption();
      if (galleryOption.evaluate().isNotEmpty) {
        await tester.tap(galleryOption);
        await tester.pumpAndSettle();
      }

      expect(find.byTooltip('Usuń zdjęcie'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('[Tier 2] R4: Spot card and SpotDetailsSheet render real user photo from disk path when photoPath is a file path',
        (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('grzybmap_r4_file_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      final photoFile = File('${tempDir.path}${Platform.pathSeparator}spot.png');
      photoFile.writeAsBytesSync(kEmerald2x2PngBytes);

      final filePhotoSpot = _makeSpot(
        id: 'disk-photo',
        photoPath: photoFile.path,
      );
      final seeded = await seedLocalPreferences(initialSpots: [filePhotoSpot]);

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

      expect(
        _hasNonStockImageWidget(tester),
        isTrue,
        reason:
            'ForagingJournalScreen card must render non-stock Image when photoPath points to a real image file on disk',
      );

      await tester.tap(find.text('Polana Borowikowa'));
      await tester.pumpAndSettle();

      expect(
        _hasNonStockImageWidget(tester, within: find.byType(SpotDetailsSheet)),
        isTrue,
        reason:
            'SpotDetailsSheet must render non-stock Image when photoPath points to a real image file on disk',
      );
    });

    testWidgets('[Tier 2] R4: SaveSpotDialog and journal support saving/editing a draft or existing spot with photo',
        (tester) async {
      final seeded = await seedLocalPreferences();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foragingJournalServiceProvider.overrideWithValue(seeded.journalService),
          ],
          child: MaterialApp(
            theme: AppTheme.forestDark,
            home: const Scaffold(
              body: SaveSpotDialog(
                location: LatLng(52.23, 21.01),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // R4 requires draft support when saving/editing a foraging spot
      final draftTrigger = find.byWidgetPredicate((w) {
        if (w is Text && w.data != null) {
          final lower = w.data!.toLowerCase();
          return lower.contains('szkic');
        }
        return false;
      });
      expect(
        draftTrigger,
        findsWidgets,
        reason:
            'R4 requires a draft save option (e.g. "Zapisz szkic" / "Szkic") in SaveSpotDialog',
      );
    });
  });

  group('R4 Full Foraging Photo Lifecycle — Tier 4 Scenario', () {
    testWidgets('[Tier 4] R4: Attach photo in SaveSpotDialog -> persist across SharedPreferences reload -> render in ForagingJournalScreen & SpotDetailsSheet',
        (tester) async {
      final pickerFixture = MockImagePickerFixture.create(fileName: 'boletus_find.png');
      pickerFixture.install();
      addTearDown(pickerFixture.dispose);

      final seeded = await seedLocalPreferences();

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FallbackTestAssetBundle(),
          child: ProviderScope(
            overrides: [
              foragingJournalServiceProvider.overrideWithValue(seeded.journalService),
            ],
            child: MaterialApp(
              theme: AppTheme.forestDark,
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () {
                      SaveSpotDialog.show(
                        context: ctx,
                        location: const LatLng(51.9194, 19.1451),
                      );
                    },
                    child: const Text('New Spot'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Spot'));
      await tester.pumpAndSettle();

      final attachTrigger = _findPhotoAttachTrigger();
      await tester.ensureVisible(attachTrigger);
      await tester.pumpAndSettle();
      await tester.tap(attachTrigger);
      await tester.pumpAndSettle();

      final galleryOption = _findGallerySourceOption();
      if (galleryOption.evaluate().isNotEmpty) {
        await tester.tap(galleryOption);
        await tester.pumpAndSettle();
      }

      final saveBtn = find.text('Zapisz w Dzienniku');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Simulate restart with a fresh SharedPreferences-backed service instance
      final freshPrefs = await SharedPreferences.getInstance();
      final reloadedService = ForagingJournalService(freshPrefs);
      await reloadedService.init();

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: FallbackTestAssetBundle(),
          child: ProviderScope(
            overrides: [
              foragingJournalServiceProvider.overrideWithValue(reloadedService),
            ],
            child: MaterialApp(
              theme: AppTheme.forestDark,
              home: const ForagingJournalScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_hasNonStockImageWidget(tester), isTrue);

      await tester.tap(find.textContaining('Borowik').first);
      await tester.pumpAndSettle();
      expect(find.byType(SpotDetailsSheet), findsOneWidget);
      expect(_hasNonStockImageWidget(tester, within: find.byType(SpotDetailsSheet)), isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
