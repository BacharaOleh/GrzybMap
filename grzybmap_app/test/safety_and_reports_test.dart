import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:grzybmap_app/features/forest_reports/domain/report_model.dart';
import 'package:grzybmap_app/features/safety/domain/sos_card_generator.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/models.dart';
import 'package:grzybmap_app/features/navigation/service/parking_service.dart';

void main() {
  group('SosCardGenerator Tests', () {
    const testLocation = LatLng(52.0528, 21.3785);

    const testParcel = ForestParcel(
      subareaId: '142a',
      address: '01-05-1-04-142 -a -00',
      inspectorate: 'Chojnów',
      latitude: 52.0528,
      longitude: 21.3785,
      primarySpecies: TreeSpecies(
        code: 'SO',
        namePl: 'Sosna zwyczajna',
        nameRu: 'Сосна',
        latin: 'Pinus sylvestris',
        icon: '🌲',
        sharePercent: 90,
      ),
      ageYears: 65,
      ageCategory: 'Drzewostan dojrzały',
      habitat: ForestHabitat(
        code: 'Bśw',
        namePl: 'Bór świeży',
        descPl: 'Umiarkowanie wilgotny',
        moisture: 'optimal',
      ),
      status: ForestStatus(
        code: 'GOSP',
        status: ForestLegalStatus.allowed,
        labelPl: 'Lasy Państwowe',
        color: Colors.green,
      ),
    );

    const testCarNav = ParkingNavigation(
      distanceMeters: 780.0,
      bearingDegrees: 215,
      humanDistance: '780 m',
      walkMinutes: 10,
      cardinalDirection: 'SW',
      arrowSymbol: '↙',
    );

    test('generateRescueText formats BDL address, coordinates, and car info', () {
      final card = SosCardGenerator.generateRescueText(
        location: testLocation,
        parcel: testParcel,
        carNavigation: testCarNav,
      );

      expect(card, contains('POMOC / MOJA POZYCJA W LESIE'));
      expect(card, contains('01-05-1-04-142 -a -00'));
      expect(card, contains('142a'));
      expect(card, contains('52.05280, 21.37850'));
      expect(card, contains('https://maps.google.com/?q=52.05280,21.37850'));
      expect(card, contains('780 m'));
      expect(card, contains('azymut 215°'));
    });

    test('generateSmsMessage creates compact text suitable for 112 SMS', () {
      final sms = SosCardGenerator.generateSmsMessage(
        location: testLocation,
        parcel: testParcel,
      );

      expect(sms, startsWith('POTRZEBUJE POMOCY W LESIE!'));
      expect(sms, contains('Wspolrzedne: 52.05280, 21.37850'));
      expect(sms, contains('Nadl: Chojnów'));
      expect(sms, contains('Oddz: 142a'));
      expect(sms.length, lessThan(160)); // Standard SMS size
    });
  });

  group('ForestReport Domain Model Tests', () {
    test('ForestReport serialization and deserialization roundtrip', () {
      final original = ForestReport(
        id: 'rep-unit-01',
        category: ForestReportCategory.fallenTree,
        latitude: 52.0512,
        longitude: 21.3820,
        nadlesnictwo: 'Chojnów',
        oddzial: '140',
        description: 'Powalony dąb blokuje szlak turystyczny',
        status: ForestReportStatus.inProgress,
        createdAt: DateTime(2026, 11, 23, 15, 30),
        confirmationsCount: 4,
      );

      final jsonMap = original.toJson();
      final reconstituted = ForestReport.fromJson(jsonMap);

      expect(reconstituted.id, equals(original.id));
      expect(reconstituted.category, equals(ForestReportCategory.fallenTree));
      expect(reconstituted.latitude, equals(52.0512));
      expect(reconstituted.longitude, equals(21.3820));
      expect(reconstituted.nadlesnictwo, equals('Chojnów'));
      expect(reconstituted.oddzial, equals('140'));
      expect(reconstituted.description, equals('Powalony dąb blokuje szlak turystyczny'));
      expect(reconstituted.status, equals(ForestReportStatus.inProgress));
      expect(reconstituted.confirmationsCount, equals(4));
    });

    test('ForestReportCategory fromString parses all variants with fallback', () {
      expect(ForestReportCategory.fromString('trash'), equals(ForestReportCategory.trash));
      expect(ForestReportCategory.fromString('fallen_tree'), equals(ForestReportCategory.fallenTree));
      expect(ForestReportCategory.fromString('fallentree'), equals(ForestReportCategory.fallenTree));
      expect(ForestReportCategory.fromString('fire_hazard'), equals(ForestReportCategory.fireHazard));
      expect(ForestReportCategory.fromString('vandalism'), equals(ForestReportCategory.vandalism));
      expect(ForestReportCategory.fromString('unknown_category'), equals(ForestReportCategory.trash));
    });

    test('ForestReportStatus labels and colors are properly defined', () {
      expect(ForestReportStatus.pending.labelPl, equals('Oczekuje'));
      expect(ForestReportStatus.inProgress.labelPl, equals('W realizacji (ZUL)'));
      expect(ForestReportStatus.resolved.labelPl, equals('Rozwiązane'));
      expect(ForestReportStatus.verified.labelPl, equals('Zweryfikowane'));
    });
  });
}
