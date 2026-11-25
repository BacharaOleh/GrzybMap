import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grzybmap_app/core/theme/app_theme.dart';
import 'package:grzybmap_app/features/foraging_journal/data/foraging_journal_service.dart';
import 'package:grzybmap_app/features/foraging_journal/domain/models/foraging_spot.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/controllers/foraging_journal_controller.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/foraging_journal_screen.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/widgets/save_spot_dialog.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/widgets/spot_details_sheet.dart';
import 'package:grzybmap_app/features/map/presentation/widgets/mushroom_photo_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final testSpot1 = ForagingSpot(
    id: 'spot-1',
    title: 'Polana Borowikowa',
    mushroomId: 'borowik_szlachetny',
    mushroomName: 'Borowik szlachetny (Prawdziwek)',
    mushroomEmoji: '🍄',
    quantityAmount: 2.5,
    quantityUnit: 'kg',
    latitude: 52.2297,
    longitude: 21.0122,
    foundAt: DateTime(2026, 10, 16, 14, 30),
    notes: 'Pod starymi dębami na mchu',
    forestParcelId: '14-01-02-03',
  );

  final testSpot2 = ForagingSpot(
    id: 'spot-2',
    title: 'Złote Kurki',
    mushroomId: 'pieprznik_jadalny',
    mushroomName: 'Pieprznik jadalny (Kurka)',
    mushroomEmoji: '🍄',
    quantityAmount: 20.0,
    quantityUnit: 'szt.',
    latitude: 52.2300,
    longitude: 21.0150,
    foundAt: DateTime(2026, 10, 17, 10, 15),
  );

  Widget createWidgetUnderTest(Widget child, {List<ForagingSpot>? initialSpots}) {
    if (initialSpots != null) {
      final jsonList = initialSpots.map((s) => s.toJson()).toList();
      prefs.setStringList('foraging_secret_spots', jsonList);
    }
    final service = ForagingJournalService(prefs);
    return ProviderScope(
      overrides: [
        foragingJournalServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: AppTheme.forestDark,
        home: Scaffold(body: child),
      ),
    );
  }

  group('ForagingJournalScreen Widget Tests', () {
    testWidgets('displays stats header with tabular numbers and without purple accents', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ForagingJournalScreen(),
          initialSpots: [testSpot1, testSpot2],
        ),
      );
      await tester.pumpAndSettle();

      // Verify stats header labels
      expect(find.text('Miejscówki'), findsOneWidget);
      expect(find.text('Łączny zbiór'), findsOneWidget);
      expect(find.text('Prywatność'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 spots
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // Verify no purple color (0xFF8B5CF6) is present on text widgets
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final text in textWidgets) {
        expect(text.style?.color != const Color(0xFF8B5CF6), isTrue);
      }
    });

    testWidgets('renders spot cards with MushroomPhotoWidget and concentric radii', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ForagingJournalScreen(),
          initialSpots: [testSpot1],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Polana Borowikowa'), findsOneWidget);
      // Species name appears in spot card and in species filter bar
      expect(find.text('Borowik szlachetny (Prawdziwek)'), findsNWidgets(2));
      expect(find.text('2.5 kg'), findsOneWidget);

      // Must render MushroomPhotoWidget
      expect(find.byType(MushroomPhotoWidget), findsOneWidget);

      final photoWidget = tester.widget<MushroomPhotoWidget>(find.byType(MushroomPhotoWidget));
      expect(photoWidget.borderRadius, AppRadii.inner); // Concentric inner radius (10.0)
      expect(photoWidget.assetPath, 'assets/mushrooms/borowik_szlachetny.webp');
    });

    testWidgets('renders species filter pills and filters spots on tap', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ForagingJournalScreen(),
          initialSpots: [testSpot1, testSpot2],
        ),
      );
      await tester.pumpAndSettle();

      // Both spots initially visible
      expect(find.text('Polana Borowikowa'), findsOneWidget);
      expect(find.text('Złote Kurki'), findsOneWidget);

      // Tap Kurka filter pill in filter bar (scroll into view first)
      final filterPills = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('Pieprznik jadalny (Kurka)'),
      );
      expect(filterPills, findsOneWidget);
      await tester.ensureVisible(filterPills);
      await tester.pumpAndSettle();
      await tester.tap(filterPills);
      await tester.pumpAndSettle();

      // Only Kurka spot remains visible
      expect(find.text('Złote Kurki'), findsOneWidget);
      expect(find.text('Polana Borowikowa'), findsNothing);

      // Tap 'Wszystkie' to reset (scroll back into view first)
      final allPill = find.text('Wszystkie');
      await tester.ensureVisible(allPill);
      await tester.pumpAndSettle();
      await tester.tap(allPill);
      await tester.pumpAndSettle();

      expect(find.text('Polana Borowikowa'), findsOneWidget);
      expect(find.text('Złote Kurki'), findsOneWidget);
    });

    testWidgets('displays vectorized empty state when no spots exist', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ForagingJournalScreen(),
          initialSpots: [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Brak zapisanych miejscówek'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    });

    testWidgets('tapping explore icon on spot card pops screen returning selected spot', (tester) async {
      final jsonList = [testSpot1, testSpot2].map((s) => s.toJson()).toList();
      await prefs.setStringList('foraging_secret_spots', jsonList);

      ForagingSpot? returnedSpot;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foragingJournalServiceProvider.overrideWithValue(ForagingJournalService(prefs)),
          ],
          child: MaterialApp(
            theme: AppTheme.forestDark,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    returnedSpot = await Navigator.of(ctx).push<ForagingSpot>(
                      MaterialPageRoute(builder: (_) => const ForagingJournalScreen()),
                    );
                  },
                  child: const Text('Open Journal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open journal
      await tester.tap(find.text('Open Journal'));
      await tester.pumpAndSettle();

      expect(find.text('Polana Borowikowa'), findsOneWidget);

      // Tap 'Pokaż na mapie' button on card
      final exploreBtn = find.byTooltip('Pokaż na mapie');
      expect(exploreBtn, findsWidgets);
      await tester.tap(exploreBtn.first);
      await tester.pumpAndSettle();

      expect(returnedSpot, isNotNull);
      expect(returnedSpot!.title, 'Złote Kurki');
    });
  });

  group('SaveSpotDialog Widget Tests', () {
    testWidgets('renders sentence case section labels and clean input borders', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const SaveSpotDialog(
            location: LatLng(52.2, 21.0),
            forestParcelId: '14-01-02-03',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify sentence case labels
      expect(find.text('Nazwa miejsca'), findsOneWidget);
      expect(find.text('Gatunek grzyba'), findsOneWidget);
      expect(find.text('Wielkość zbioru'), findsOneWidget);
      expect(find.text('Jednostka'), findsOneWidget);
      expect(find.text('Notatki i wskazówki (opcjonalnie)'), findsOneWidget);

      // Verify no ALL-CAPS old labels remain
      expect(find.text('NAZWA MIEJSCA'), findsNothing);
      expect(find.text('ZNALEZIONY GATUNEK GRZYBA'), findsNothing);
      expect(find.text('ILOŚĆ / ZBIÓR'), findsNothing);
      expect(find.text('JEDNOSTKA'), findsNothing);

      // Verify upgraded species selector trigger tile
      expect(find.text('Zmień'), findsOneWidget);
      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
    });

    testWidgets('opens upgraded species picker sheet and filters species by query', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const SaveSpotDialog(
            location: LatLng(52.2, 21.0),
            preselectedMushroomId: 'borowik_szlachetny',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Zmień' to open sheet
      await tester.tap(find.text('Zmień'));
      await tester.pumpAndSettle();

      expect(find.text('Wybierz gatunek grzyba'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);

      // Enter search query 'kurka'
      final searchField = find.widgetWithText(TextField, 'Szukaj gatunku (np. borowik, pieprznik)...');
      await tester.enterText(searchField, 'kurka');
      await tester.pumpAndSettle();

      // Kurka should be in the list, Borowik should not be in the list
      final listFinder = find.byType(ListView);
      expect(find.descendant(of: listFinder, matching: find.text('Pieprznik jadalny (Kurka)')), findsOneWidget);
      expect(find.descendant(of: listFinder, matching: find.text('Borowik szlachetny (Prawdziwek)')), findsNothing);

      // Select Kurka
      await tester.tap(find.descendant(of: listFinder, matching: find.text('Pieprznik jadalny (Kurka)')));
      await tester.pumpAndSettle();

      // Picker closes and main dialog displays Kurka
      expect(find.text('Wybierz gatunek grzyba'), findsNothing);
      expect(find.text('Pieprznik jadalny (Kurka)'), findsOneWidget);
    });

    testWidgets('quantity stepper and unit switcher update state correctly', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const SaveSpotDialog(
            location: LatLng(52.2, 21.0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial quantity is 1
      expect(find.text('1'), findsOneWidget);

      // Tap plus to increment by 0.5 kg
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('1.5'), findsOneWidget);

      // Tap minus to decrement back to 1.0 kg
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      // Switch unit to 'szt.'
      await tester.tap(find.text('szt.'));
      await tester.pumpAndSettle();

      // Unit switch defaults to 5 szt.
      expect(find.text('5'), findsOneWidget);

      // Increment in 'szt.' mode steps by 1
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('attaches and displays initial photo in SaveSpotDialog and allows removal', (tester) async {
      const fakeBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      await tester.pumpWidget(
        createWidgetUnderTest(
          const SaveSpotDialog(
            location: LatLng(52.2, 21.0),
            initialPhotoBase64: fakeBase64,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Zdjęcie dołączone'), findsOneWidget);
      expect(find.byTooltip('Usuń zdjęcie'), findsOneWidget);

      // Tap remove photo
      await tester.tap(find.byTooltip('Usuń zdjęcie'));
      await tester.pumpAndSettle();

      expect(find.text('Zdjęcie dołączone'), findsNothing);
      expect(find.text('Dodaj zdjęcie do znaleziska'), findsOneWidget);
    });
  });

  group('SpotDetailsSheet Widget Tests', () {
    testWidgets('renders authentic mushroom photo thumbnail, metadata and navigate button', (tester) async {
      bool navigated = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forestDark,
          home: Scaffold(
            body: SpotDetailsSheet(
              spot: testSpot1,
              onDelete: () {},
              onNavigate: () => navigated = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & botanical photo
      expect(find.text('Polana Borowikowa'), findsOneWidget);
      expect(find.byType(MushroomPhotoWidget), findsOneWidget);

      // Verify metadata rows
      expect(find.text('Data znaleziska'), findsOneWidget);
      expect(find.text('16.10.2026 14:30'), findsOneWidget);
      expect(find.text('Wydzielenie leśne BDL'), findsOneWidget);
      expect(find.text('14-01-02-03'), findsOneWidget);
      expect(find.text('Współrzędne GPS'), findsOneWidget);
      expect(find.text('52.2297, 21.0122'), findsOneWidget);
      expect(find.text('Pod starymi dębami na mchu'), findsOneWidget);

      // Tap "Pokaż na mapie"
      await tester.tap(find.text('Pokaż na mapie'));
      await tester.pumpAndSettle();
      expect(navigated, isTrue);
    });

    testWidgets('triggers delete callback when delete button is tapped', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forestDark,
          home: Scaffold(
            body: SpotDetailsSheet(
              spot: testSpot1,
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Usuń miejsce"
      await tester.tap(find.text('Usuń miejsce'));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });
  });
}
