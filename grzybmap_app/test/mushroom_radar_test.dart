import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/core/theme/app_theme.dart';
import 'package:grzybmap_app/features/map/presentation/controllers/map_screen_controller.dart';
import 'package:grzybmap_app/features/map/presentation/widgets/mushroom_gauge_badge.dart';
import 'package:grzybmap_app/features/mushroom_radar/domain/parcel_radar.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('MushroomGaugeBadge & ParcelRadar Tests', () {
    test('ParcelRadarItem model stores and computes fields correctly', () {
      const item = ParcelRadarItem(
        id: '52.0500_21.3800',
        centroid: LatLng(52.050, 21.380),
        speciesName: 'Sosna',
        speciesShort: 'So',
        ageYears: 85,
        areaHa: 4.25,
        probabilityPercent: 78,
        topMushroomName: 'Borowik',
      );

      expect(item.id, '52.0500_21.3800');
      expect(item.speciesName, 'Sosna');
      expect(item.speciesShort, 'So');
      expect(item.ageYears, 85);
      expect(item.probabilityPercent, 78);
      expect(item.probability, 78);
      expect(item.topMushroomName, 'Borowik');
    });

    testWidgets('MushroomGaugeBadge default renders ultra-minimal gauge and percentage only', (tester) async {
      bool tapped = false;
      bool longPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushroomGaugeBadge(
              probability: 82,
              mushroomName: 'Borowik',
              speciesName: 'So',
              ageYears: 75,
              onTap: () {
                tapped = true;
              },
              onLongPress: () {
                longPressed = true;
              },
            ),
          ),
        ),
      );

      // Verify minimal label: only percentage is visible by default
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('Borowik'), findsNothing);
      expect(find.text('So 75l'), findsNothing);

      // Verify custom painter is present
      expect(find.byType(CustomPaint), findsWidgets);

      // Tap and verify callback
      await tester.tap(find.byType(MushroomGaugeBadge));
      expect(tapped, isTrue);

      // Long press and verify callback
      await tester.longPress(find.byType(MushroomGaugeBadge));
      expect(longPressed, isTrue);
    });

    testWidgets('MushroomGaugeBadge conditionally renders mushroom name and tree species when enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushroomGaugeBadge(
              probability: 85,
              mushroomName: 'Borowik',
              speciesName: 'So',
              ageYears: 65,
              showMushroomName: true,
              showTreeSpecies: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('85%'), findsOneWidget);
      expect(find.text('Borowik'), findsOneWidget);
      expect(find.text('So 65l'), findsOneWidget);
    });

    testWidgets('MushroomGaugeBadge displays correct color theme for high/medium/low probability', (tester) async {
      // 1. High probability (>= 65%) -> emeraldNeon
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushroomGaugeBadge(
              probability: 90,
              mushroomName: 'Borowik',
              speciesName: 'Db',
              ageYears: 120,
              onTap: () {},
            ),
          ),
        ),
      );
      final highText = tester.widget<Text>(find.text('90%'));
      expect(highText.style?.color, AppColors.emeraldNeon);

      // 2. Medium probability (35%..64%) -> amberWarn
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushroomGaugeBadge(
              probability: 50,
              mushroomName: 'Kurka',
              speciesName: 'Brz',
              ageYears: 40,
              onTap: () {},
            ),
          ),
        ),
      );
      final medText = tester.widget<Text>(find.text('50%'));
      expect(medText.style?.color, AppColors.amberWarn);

      // 3. Low probability (< 35%) -> grey
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushroomGaugeBadge(
              probability: 20,
              mushroomName: 'Borowik',
              speciesName: 'Jd',
              ageYears: 121,
              onTap: () {},
            ),
          ),
        ),
      );
      final lowText = tester.widget<Text>(find.text('20%'));
      expect(lowText.style?.color, const Color(0xFF9CA3AF));
    });

    test('MapScreenState filters out points < 50% by default and shows them when enabled', () {
      const highItem = ParcelRadarItem(
        id: '1',
        centroid: LatLng(52.0, 21.0),
        speciesName: 'Sosna',
        speciesShort: 'So',
        ageYears: 80,
        areaHa: 2.0,
        probabilityPercent: 75,
        topMushroomName: 'Borowik',
      );
      const lowItem = ParcelRadarItem(
        id: '2',
        centroid: LatLng(52.1, 21.1),
        speciesName: 'Sosna',
        speciesShort: 'So',
        ageYears: 20,
        areaHa: 1.0,
        probabilityPercent: 42,
        topMushroomName: 'Maślak',
      );

      const defaultState = MapScreenState(
        selectedMonth: 10,
        parcelRadars: [highItem, lowItem],
        showParcelRadars: true,
        showLowProbabilityRadars: false,
      );

      // By default: only items with >= 50% chance are visible
      expect(defaultState.visibleParcelRadars.length, 1);
      expect(defaultState.visibleParcelRadars.first.id, '1');

      // When low probability enabled: both are visible
      final enabledState = defaultState.copyWith(showLowProbabilityRadars: true);
      expect(enabledState.visibleParcelRadars.length, 2);
    });
  });
}
