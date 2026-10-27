import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/features/map/presentation/widgets/mushroom_card.dart';
import 'package:grzybmap_app/features/map/presentation/widgets/parcel_bottom_sheet.dart';
import 'package:grzybmap_app/features/mushroom_radar/data/mushroom_database.dart';
import 'package:grzybmap_app/features/mushroom_radar/domain/models.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/models.dart';

void main() {
  group('UX Widgets Tests (U4, U7, U8)', () {
    testWidgets('U4: ForestDetailsSpoiler collapses technical address and expands details on tap', (tester) async {
      const parcel = ForestParcel(
        subareaId: '01-a',
        address: '17-01-1-03-360-a-00',
        inspectorate: 'Nadleśnictwo Celestynów',
        primarySpecies: TreeSpecies(
          code: 'SO',
          namePl: 'Sosna zwyczajna',
          nameRu: 'Сосна',
          latin: 'Pinus sylvestris',
          icon: '🌲',
        ),
        ageYears: 65,
        ageCategory: 'Drzewostan dojrzały (65 lat)',
        habitat: ForestHabitat(
          code: 'BŚW',
          namePl: 'Bór świeży',
          descPl: 'Gleby piaszczyste, mchy',
          moisture: 'optimal',
        ),
        status: ForestStatus(
          code: 'GOSP',
          status: ForestLegalStatus.allowed,
          labelPl: 'Las gospodarczy',
          color: Colors.green,
        ),
        areaHa: '1.45 ha',
        latitude: 52.0623,
        longitude: 21.3912,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ForestDetailsSpoiler(parcel: parcel),
            ),
          ),
        ),
      );

      // Verify header and compact state
      expect(find.text('Szczegóły leśne (BDL)'), findsOneWidget);
      expect(find.text('Rozwiń'), findsOneWidget);
      expect(find.text('Adres: 17-01-1-03-360-a-00'), findsOneWidget);

      // Before expansion, detailed labels should not be displayed
      expect(find.text('Wydzielenie'), findsNothing);
      expect(find.text('Nadleśnictwo'), findsNothing);

      // Tap to expand spoiler
      await tester.tap(find.byType(ForestDetailsSpoiler));
      await tester.pumpAndSettle();

      // Verify expanded state
      expect(find.text('Zwiń'), findsOneWidget);
      expect(find.text('Wydzielenie'), findsOneWidget);
      expect(find.text('01-a'), findsOneWidget);
      expect(find.text('Nadleśnictwo Celestynów'), findsOneWidget);
      expect(find.text('BŚW — Bór świeży'), findsOneWidget);
      expect(find.text('1.45 ha'), findsOneWidget);
      expect(find.text('52.06230°N, 21.39120°E'), findsOneWidget);

      // Test copying address to clipboard
      final copyAddressBtn = find.byTooltip('Kopiuj adres leśny');
      expect(copyAddressBtn, findsOneWidget);
      await tester.tap(copyAddressBtn);
      await tester.pump();

      expect(find.textContaining('skopiowano do schowka'), findsOneWidget);
    });

    testWidgets('U7 & U8: MushroomCard shows lookalike warning and expands harvesting tips', (tester) async {
      // Find Czubajka Kania (has lethal lookalike: Muchomor sromotnikowy)
      final kania = MushroomDatabase.allMushrooms.firstWhere(
        (m) => m.id == 'czubajka_kania',
      );

      final matchResult = MushroomMatchResult(
        mushroom: kania,
        probabilityPercent: 100,
        chanceCategory: 'Bardzo wysoki',
        chanceColor: const Color(0xFF10B981),
        positiveReasons: const ['Optymalne drzewo: Sosna', 'Wiek lasu: 65 lat'],
        negativeReasons: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MushroomCard(result: matchResult),
            ),
          ),
        ),
      );

      // Verify name, latin, edibility
      expect(find.text('Czubajka kania (Sowa)'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // U7: Verify prominent lookalike warning chip
      expect(find.textContaining('ŚMIERTELNIE TRUJĄCY SOBOWTÓR'), findsOneWidget);
      expect(find.textContaining('Muchomor sromotnikowy'), findsOneWidget);

      // Before expansion, tips header should not be visible
      expect(find.text('WSKAZÓWKI ZBIORU'), findsNothing);

      // U8: Tap on the card to expand details
      await tester.tap(find.byType(MushroomCard));
      await tester.pumpAndSettle();

      // Verify tips header and text are now visible
      expect(find.text('WSKAZÓWKI ZBIORU'), findsOneWidget);
      expect(find.text(kania.tipsPl), findsOneWidget);

      // Verify detailed danger alert box is visible
      expect(find.text('🚨 ZAGROŻENIE ŻYCIA — SOBOWTÓR'), findsOneWidget);
      expect(find.text(kania.lookalike!.warningPl), findsOneWidget);

      // Tap again to collapse
      await tester.ensureVisible(find.text('Zwiń szczegóły'));
      await tester.tap(find.text('Zwiń szczegóły'));
      await tester.pumpAndSettle();

      // Verified collapsed
      expect(find.text('WSKAZÓWKI ZBIORU'), findsNothing);
    });

    testWidgets('U7: MushroomCard handles mushroom without lookalike cleanly', (tester) async {
      final maslak = MushroomDatabase.allMushrooms.firstWhere(
        (m) => m.id == 'maslak_zwyczajny',
      );

      final matchResult = MushroomMatchResult(
        mushroom: maslak,
        probabilityPercent: 90,
        chanceCategory: 'Bardzo wysoki',
        chanceColor: const Color(0xFF10B981),
        positiveReasons: const ['Młoda sosna'],
        negativeReasons: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MushroomCard(result: matchResult),
            ),
          ),
        ),
      );

      // Should not have lethal or general lookalike warning
      expect(find.textContaining('ŚMIERTELNIE TRUJĄCY SOBOWTÓR'), findsNothing);
      expect(find.textContaining('Uwaga na podobny gatunek'), findsNothing);

      // Expand and verify tips
      await tester.tap(find.byType(MushroomCard));
      await tester.pumpAndSettle();

      expect(find.text('WSKAZÓWKI ZBIORU'), findsOneWidget);
      expect(find.text(maslak.tipsPl), findsOneWidget);
      expect(find.textContaining('ZAGROŻENIE ŻYCIA'), findsNothing);
    });
  });
}
