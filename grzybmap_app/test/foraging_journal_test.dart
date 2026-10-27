import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grzybmap_app/features/foraging_journal/domain/models/foraging_spot.dart';
import 'package:grzybmap_app/features/foraging_journal/data/foraging_journal_service.dart';
import 'package:grzybmap_app/features/foraging_journal/presentation/controllers/foraging_journal_controller.dart';
import 'package:grzybmap_app/features/mushroom_radar/data/mushroom_database.dart';
import 'package:grzybmap_app/features/mushroom_radar/service/parcel_radar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForagingSpot Model Tests', () {
    test('serializes to and from JSON correctly', () {
      final spot = ForagingSpot(
        id: 'spot-123',
        title: 'Borowikowa Polana',
        mushroomId: 'borowik_szlachetny',
        mushroomName: 'Borowik szlachetny',
        mushroomEmoji: '🍄',
        quantityAmount: 2.5,
        quantityUnit: 'kg',
        latitude: 52.1234,
        longitude: 21.5678,
        foundAt: DateTime(2026, 10, 16, 14, 30),
        notes: 'Stare dęby, dużo mchu',
        forestParcelId: '14-22-01-01',
      );

      final jsonString = spot.toJson();
      final restored = ForagingSpot.fromJson(jsonString);

      expect(restored.id, spot.id);
      expect(restored.title, spot.title);
      expect(restored.mushroomId, spot.mushroomId);
      expect(restored.mushroomName, spot.mushroomName);
      expect(restored.mushroomEmoji, '🍄');
      expect(restored.quantityAmount, 2.5);
      expect(restored.quantityUnit, 'kg');
      expect(restored.latitude, spot.latitude);
      expect(restored.longitude, spot.longitude);
      expect(restored.foundAt, spot.foundAt);
      expect(restored.notes, 'Stare dęby, dużo mchu');
      expect(restored.forestParcelId, '14-22-01-01');
      expect(restored.humanQuantity, '2.5 kg');
      expect(restored.formattedDate, '16.10.2026 14:30');
    });

    test('humanQuantity handles integer and decimal amounts', () {
      final decimalSpot = ForagingSpot(
        id: '1',
        title: 'Spot 1',
        mushroomId: 'kurka',
        mushroomName: 'Kurka',
        mushroomEmoji: '🍄',
        quantityAmount: 1.5,
        quantityUnit: 'kg',
        latitude: 52.0,
        longitude: 21.0,
        foundAt: DateTime.now(),
      );
      expect(decimalSpot.humanQuantity, '1.5 kg');

      final integerSpot = ForagingSpot(
        id: '2',
        title: 'Spot 2',
        mushroomId: 'kurka',
        mushroomName: 'Kurka',
        mushroomEmoji: '🍄',
        quantityAmount: 20.0,
        quantityUnit: 'szt.',
        latitude: 52.0,
        longitude: 21.0,
        foundAt: DateTime.now(),
      );
      expect(integerSpot.humanQuantity, '20 szt.');
    });
  });

  group('ForagingJournalService Local Storage Tests (100% Offline)', () {
    late SharedPreferences prefs;
    late ForagingJournalService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = ForagingJournalService(prefs);
    });

    test('saves spot and persists across instances', () async {
      final spot = ForagingSpot(
        id: 'spot-1',
        title: 'Sekretny Las Grzybowy',
        mushroomId: 'borowik_szlachetny',
        mushroomName: 'Borowik szlachetny',
        mushroomEmoji: '🍄',
        quantityAmount: 3.0,
        quantityUnit: 'kg',
        latitude: 52.5,
        longitude: 21.2,
        foundAt: DateTime.now(),
      );

      await service.saveSpot(spot);
      final spots = service.getSpots();
      expect(spots.length, 1);
      expect(spots.first.title, 'Sekretny Las Grzybowy');

      // Verify persistence by reading from a new service instance
      final service2 = ForagingJournalService(prefs);
      final restored = service2.getSpots();
      expect(restored.length, 1);
      expect(restored.first.id, 'spot-1');
      expect(restored.first.quantityAmount, 3.0);
    });

    test('deletes spot successfully', () async {
      final spot1 = ForagingSpot(
        id: 'spot-1',
        title: 'Spot 1',
        mushroomId: 'borowik_szlachetny',
        mushroomName: 'Borowik',
        mushroomEmoji: '🍄',
        quantityAmount: 1.0,
        quantityUnit: 'kg',
        latitude: 52.1,
        longitude: 21.1,
        foundAt: DateTime.now(),
      );
      final spot2 = ForagingSpot(
        id: 'spot-2',
        title: 'Spot 2',
        mushroomId: 'pieprznik_jadalny',
        mushroomName: 'Kurka',
        mushroomEmoji: '🍄',
        quantityAmount: 15.0,
        quantityUnit: 'szt.',
        latitude: 52.2,
        longitude: 21.2,
        foundAt: DateTime.now(),
      );

      await service.saveSpot(spot1);
      await service.saveSpot(spot2);
      expect(service.getSpots().length, 2);

      await service.deleteSpot('spot-1');
      final remaining = service.getSpots();
      expect(remaining.length, 1);
      expect(remaining.first.id, 'spot-2');
    });

    test('toggles layer visibility setting in preferences', () async {
      expect(service.isLayerVisible(), isTrue);

      await service.setLayerVisible(false);
      expect(service.isLayerVisible(), isFalse);

      final service2 = ForagingJournalService(prefs);
      expect(service2.isLayerVisible(), isFalse);
    });
  });

  group('ForagingJournalNotifier Riverpod State & Filtering Tests', () {
    late SharedPreferences prefs;
    late ForagingJournalService service;
    late ForagingJournalNotifier notifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = ForagingJournalService(prefs);
      notifier = ForagingJournalNotifier(service);
      await notifier.loadSpots();
    });

    test('calculates harvest statistics accurately', () async {
      await notifier.addSpot(
        ForagingSpot(
          id: 's1',
          title: 'Dębowy zagajnik',
          mushroomId: 'borowik_szlachetny',
          mushroomName: 'Borowik szlachetny',
          mushroomEmoji: '🍄',
          quantityAmount: 2.5,
          quantityUnit: 'kg',
          latitude: 52.1,
          longitude: 21.1,
          foundAt: DateTime.now(),
        ),
      );

      await notifier.addSpot(
        ForagingSpot(
          id: 's2',
          title: 'Młode brzózki',
          mushroomId: 'kozlarz_babka',
          mushroomName: 'Koźlarz babka',
          mushroomEmoji: '🍄',
          quantityAmount: 10.0,
          quantityUnit: 'szt.', // 10 szt * 0.05kg = 0.5kg
          latitude: 52.2,
          longitude: 21.2,
          foundAt: DateTime.now(),
        ),
      );

      expect(notifier.state.spots.length, 2);
      expect(notifier.state.totalSpotsCount, 2);
      expect(notifier.state.estimatedTotalKg, closeTo(3.0, 0.01));
    });

    test('filters spots by mushroom species', () async {
      await notifier.addSpot(
        ForagingSpot(
          id: 's1',
          title: 'Kurkowa polana',
          mushroomId: 'pieprznik_jadalny',
          mushroomName: 'Pieprznik jadalny',
          mushroomEmoji: '🍄',
          quantityAmount: 1.0,
          quantityUnit: 'kg',
          latitude: 52.1,
          longitude: 21.1,
          foundAt: DateTime.now(),
        ),
      );

      await notifier.addSpot(
        ForagingSpot(
          id: 's2',
          title: 'Borowiki przy ścieżce',
          mushroomId: 'borowik_szlachetny',
          mushroomName: 'Borowik szlachetny',
          mushroomEmoji: '🍄',
          quantityAmount: 2.0,
          quantityUnit: 'kg',
          latitude: 52.2,
          longitude: 21.2,
          foundAt: DateTime.now(),
        ),
      );

      // Filter by species
      notifier.setFilterMushroom('pieprznik_jadalny');
      expect(notifier.state.filteredSpots.length, 1);
      expect(notifier.state.filteredSpots.first.mushroomId, 'pieprznik_jadalny');

      // Clear filter
      notifier.setFilterMushroom(null);
      expect(notifier.state.filteredSpots.length, 2);
    });

    test('toggles layer visibility', () async {
      expect(notifier.state.isLayerVisible, isTrue);
      await notifier.toggleLayerVisibility();
      expect(notifier.state.isLayerVisible, isFalse);
      await notifier.toggleLayerVisibility();
      expect(notifier.state.isLayerVisible, isTrue);
    });
  });

  group('ParcelRadarService Target Mushroom Mode (5.1)', () {
    test('resolves known mushrooms and short names', () {
      const allMushrooms = MushroomDatabase.allMushrooms;
      expect(allMushrooms.any((m) => m.id == 'borowik_szlachetny'), isTrue);
      expect(allMushrooms.any((m) => m.id == 'pieprznik_jadalny'), isTrue);

      final shortBorowik = ParcelRadarService.toShortMushroomName('Borowik szlachetny');
      expect(shortBorowik, 'Borowik');

      final shortKurka = ParcelRadarService.toShortMushroomName('Pieprznik jadalny (Kurka)');
      expect(shortKurka, 'Kurka');
    });
  });
}
