import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grzybmap_app/features/parcel_inspector/data/bdl_parser.dart';
import 'package:grzybmap_app/features/parcel_inspector/domain/models.dart';

void main() {
  group('BdlParser: Tree Species & Dictionaries (P1)', () {
    test('Resolves standard Polish forestry species codes', () {
      final so = BdlParser.getSpeciesInfo('SO');
      expect(so['pl'], 'Sosna zwyczajna');
      expect(so['icon'], '🌲');

      final db = BdlParser.getSpeciesInfo('DB');
      expect(db['pl'], 'Dąb szypułkowy');
      expect(db['icon'], '🌳');

      final bk = BdlParser.getSpeciesInfo('BK');
      expect(bk['pl'], 'Buk zwyczajny');

      final sw = BdlParser.getSpeciesInfo('ŚW');
      expect(sw['pl'], 'Świerk pospolity');
    });

    test('Resolves sub-code prefix species (e.g. SO.C, DB.C)', () {
      final soC = BdlParser.getSpeciesInfo('SO.C');
      expect(soC['pl'], 'Sosna czarna');

      final dbC = BdlParser.getSpeciesInfo('DB.C');
      expect(dbC['pl'], 'Dąb czerwony');
    });

    test('Provides fallback for unknown species codes without throwing', () {
      final unknown = BdlParser.getSpeciesInfo('XYZ');
      expect(unknown['pl'], contains('XYZ'));
      expect(unknown['icon'], '🌳');
    });
  });

  group('BdlParser: Habitat / Siedlisko Dictionaries (P2)', () {
    test('Resolves typical lowland forest habitats', () {
      final bsw = BdlParser.getHabitatInfo('BŚW');
      expect(bsw['pl'], 'Bór świeży');
      expect(bsw['moisture'], 'optimal');

      final lmsw = BdlParser.getHabitatInfo('LMŚW');
      expect(lmsw['pl'], 'Las mieszany świeży');
      expect(lmsw['moisture'], 'optimal');

      final ol = BdlParser.getHabitatInfo('OL');
      expect(ol['pl'], contains('Ols'));
      expect(ol['moisture'], 'bog');
    });

    test('Resolves mountain habitats (P2 expansion)', () {
      final lgsw = BdlParser.getHabitatInfo('LGŚW');
      expect(lgsw['pl'], contains('Las górski'));

      final bmgsw = BdlParser.getHabitatInfo('BMGŚW');
      expect(bmgsw['pl'], contains('Bór mieszany górski'));
    });

    test('Provides fallback for unknown habitat code', () {
      final unknown = BdlParser.getHabitatInfo('UNKNOWN_HABITAT');
      expect(unknown['pl'], contains('UNKNOWN_HABITAT'));
    });
  });

  group('BdlParser: HTML Parsing of BDL WMS Responses (P3)', () {
    test('Correctly parses full multi-species forest parcel from valid BDL HTML', () {
      const sampleHtml = '''
        <html>
          <body>
            <h5>Wydzielenia PGL LP</h5>
            <table>
              <tr>
                <th>subarea_id</th>
                <th>species_cd_d</th>
                <th>species_age</th>
                <th>part_cd</th>
                <th>site_type_cd</th>
                <th>forest_func_cd</th>
                <th>adress_forest</th>
                <th>sub_area</th>
              </tr>
              <tr>
                <td>17-01-1-03-360-a-00</td>
                <td>SO</td>
                <td>68</td>
                <td>7</td>
                <td>BŚW</td>
                <td>GOSP</td>
                <td>17-01-1-03-360-a-00</td>
                <td>4.52 ha</td>
              </tr>
              <tr>
                <td>17-01-1-03-360-a-00</td>
                <td>DB</td>
                <td>50</td>
                <td>3</td>
                <td>BŚW</td>
                <td>GOSP</td>
                <td>17-01-1-03-360-a-00</td>
                <td>4.52 ha</td>
              </tr>
            </table>
            <h5>Nadleśnictwa</h5>
            <table>
              <tr><th>inspectorate_name</th></tr>
              <tr><td>Nadleśnictwo Celestynów</td></tr>
            </table>
          </body>
        </html>
      ''';

      final parcel = BdlParser.parseHtml(
        htmlString: sampleHtml,
        lat: 52.05,
        lng: 21.38,
      );

      expect(parcel, isNotNull);
      expect(parcel!.primarySpecies.code, 'SO');
      expect(parcel.primarySpecies.namePl, 'Sosna zwyczajna');
      expect(parcel.primarySpecies.sharePercent, 70);

      // Check secondary species (P3)
      expect(parcel.secondarySpecies.length, 1);
      expect(parcel.secondarySpecies.first.code, 'DB');
      expect(parcel.secondarySpecies.first.sharePercent, 30);
      expect(parcel.compositionSummary, contains('Sosna zwyczajna (70%)'));
      expect(parcel.compositionSummary, contains('Dąb szypułkowy (30%)'));

      // Check age and age category
      expect(parcel.ageYears, 68);
      expect(parcel.ageCategory, 'Dojrzały bór / las (50-90 lat)');

      // Check habitat & inspectorate
      expect(parcel.habitat.code, 'BŚW');
      expect(parcel.habitat.namePl, 'Bór świeży');
      expect(parcel.inspectorate, 'Nadleśnictwo Celestynów');

      // Legal status
      expect(parcel.status.status, ForestLegalStatus.allowed);
      expect(parcel.status.code, 'GOSP');
    });

    test('Correctly identifies nature reserve (REZ) with forbidden status', () {
      const reserveHtml = '''
        <table>
          <tr>
            <th>subarea_id</th>
            <th>species_cd_d</th>
            <th>species_age</th>
            <th>part_cd</th>
            <th>site_type_cd</th>
            <th>forest_func_cd</th>
            <th>adress_forest</th>
          </tr>
          <tr>
            <td>01-a</td>
            <td>BK</td>
            <td>110</td>
            <td>10</td>
            <td>LŚW</td>
            <td>REZ</td>
            <td>01-01-01-a</td>
          </tr>
        </table>
      ''';

      final parcel = BdlParser.parseHtml(
        htmlString: reserveHtml,
        lat: 49.50,
        lng: 20.00,
      );

      expect(parcel, isNotNull);
      expect(parcel!.status.status, ForestLegalStatus.forbidden);
      expect(parcel.status.labelPl, contains('ZAKAZ'));
      expect(parcel.status.color, const Color(0xFFEF4444));
      expect(parcel.ageYears, 110);
      expect(parcel.ageCategory, 'Starodrzew (>90 lat)');
    });

    test('Returns null for empty or non-forest HTML without crashing', () {
      expect(
        BdlParser.parseHtml(htmlString: '', lat: 52.0, lng: 21.0),
        isNull,
      );

      expect(
        BdlParser.parseHtml(htmlString: '<html><body>Empty body</body></html>', lat: 52.0, lng: 21.0),
        isNull,
      );

      expect(
        BdlParser.parseHtml(htmlString: '<table><tr><th>col</th></tr></table>', lat: 52.0, lng: 21.0),
        isNull,
      );
    });
  });
}
