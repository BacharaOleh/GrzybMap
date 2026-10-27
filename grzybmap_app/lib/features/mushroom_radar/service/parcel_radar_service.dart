import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../parcel_inspector/data/bdl_parser.dart';
import '../../parcel_inspector/domain/models.dart';
import '../../weather/domain/models.dart';
import '../domain/models.dart';
import '../domain/parcel_radar.dart';
import 'match_engine.dart';

class ParcelRadarService {
  final Dio _dio;

  ParcelRadarService({Dio? dio}) : _dio = dio ?? Dio();

  static const Set<String> popularPrizedIds = {
    'borowik_szlachetny',
    'borowik_sosnowy',
    'podgrzybek_brunatny',
    'pieprznik_jadalny',
    'kozlarz_czerwony',
    'kozlarz_babka',
    'mleczaj_rydz',
    'maslak_zwyczajny',
    'maslak_ziarnisty',
    'czubajka_kania',
    'podgrzybek_zajaczek',
  };

  static String toShortMushroomName(String namePl) {
    if (namePl.contains('Borowik')) return 'Borowik';
    if (namePl.contains('Podgrzybek')) return 'Podgrzybek';
    if (namePl.contains('Kurka') || namePl.contains('Pieprznik')) return 'Kurka';
    if (namePl.contains('Krawiec')) return 'Krawiec';
    if (namePl.contains('Koźlarz')) return 'Koźlarz';
    if (namePl.contains('Rydz')) return 'Rydz';
    if (namePl.contains('Maślak')) return 'Maślak';
    if (namePl.contains('Kania')) return 'Kania';
    if (namePl.contains('Opieńka')) return 'Opieńka';
    return namePl.split(' ').first;
  }

  static String toShortTreeName(String treePl) {
    if (treePl.startsWith('Sosna')) return 'So';
    if (treePl.startsWith('Jodła')) return 'Jd';
    if (treePl.startsWith('Dąb')) return 'Db';
    if (treePl.startsWith('Buk')) return 'Bk';
    if (treePl.startsWith('Brzoza')) return 'Brz';
    if (treePl.startsWith('Świerk')) return 'Św';
    if (treePl.startsWith('Modrzew')) return 'Md';
    if (treePl.startsWith('Olsza')) return 'Ol';
    if (treePl.startsWith('Grab')) return 'Gb';
    if (treePl.startsWith('Osika')) return 'Os';
    return treePl.length > 3 ? treePl.substring(0, 3) : treePl;
  }

  static double lonToX(double lon) => lon * 20037508.34 / 180.0;
  static double latToY(double lat) {
    final clamped = lat.clamp(-85.05112878, 85.05112878);
    final y = log(tan((90.0 + clamped) * pi / 360.0)) / (pi / 180.0);
    return y * 20037508.34 / 180.0;
  }

  static double xToLon(double x) => x * 180.0 / 20037508.34;
  static double yToLat(double y) {
    final lat = y * 180.0 / 20037508.34;
    return 180.0 / pi * (2.0 * atan(exp(lat * pi / 180.0)) - pi / 2.0);
  }

  /// Fetches forest parcels in the bounding box and calculates edible mushroom potential.
  /// Strictly prioritizes top popular culinary mushrooms (Borowik, Kurka, Podgrzybek, etc.)
  /// and properly parses the tree stand share (`part_cd`).
  Future<List<ParcelRadarItem>> fetchVisibleRadars({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required WeatherRainfall? weather,
    required int selectedMonth,
    String? targetMushroomId,
    CancelToken? cancelToken,
  }) async {
    try {
      final minX = lonToX(minLng);
      final minY = latToY(minLat);
      final maxX = lonToX(maxLng);
      final maxY = latToY(maxLat);

      const queryUrl = kIsWeb
          ? '/api/bdl-query'
          : 'https://mapserver.bdl.lasy.gov.pl/ArcGIS/rest/services/WMS_BDL/MapServer/5/query';

      final response = await _dio.get<dynamic>(
        queryUrl,
        queryParameters: {
          'geometry': '$minX,$minY,$maxX,$maxY',
          'geometryType': 'esriGeometryEnvelope',
          'inSR': '3857',
          'spatialRel': 'esriSpatialRelIntersects',
          'outFields': 'subarea_id,adress_forest,site_type_cd,species_cd_d,species_age,sub_area,part_cd',
          'returnGeometry': 'true',
          'f': 'json',
        },
        cancelToken: cancelToken,
        options: Options(
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final data = response.data is Map ? response.data as Map : const <String, dynamic>{};
      final features = data['features'] as List? ?? [];
      final items = <ParcelRadarItem>[];
      final seenParcels = <String>{};

      for (final feat in features) {
        if (feat is! Map) continue;
        final attrs = feat['attributes'] as Map? ?? {};
        final geom = feat['geometry'] as Map? ?? {};
        final rings = geom['rings'] as List? ?? [];

        final rawSpecies = (attrs['species_cd_d'] ?? attrs['species_cd'] ?? '').toString().trim();
        final rawHabitat = (attrs['site_type_cd'] ?? '').toString().trim();
        final age = int.tryParse(attrs['species_age']?.toString() ?? '') ?? 0;
        final subareaId = (attrs['subarea_id'] ?? '').toString();
        final address = (attrs['adress_forest'] ?? '').toString().trim();
        final area = double.tryParse(attrs['sub_area']?.toString() ?? '') ?? 0.0;

        // Skip non-forest or invalid species
        if (rawSpecies.isEmpty || rawSpecies == 'BEZ DRZEW') continue;
        final effectiveAge = age > 0 ? age : 5;

        // Deduplicate parcels
        final addressKey = address.isNotEmpty ? address : subareaId;
        if (addressKey.isNotEmpty && seenParcels.contains(addressKey)) continue;
        if (addressKey.isNotEmpty) seenParcels.add(addressKey);

        // Calculate polygon centroid from largest ring
        if (rings.isEmpty || rings[0] is! List) continue;
        List<dynamic> largestRing = rings[0] as List<dynamic>;
        for (final r in rings) {
          if (r is List<dynamic> && r.length > largestRing.length) {
            largestRing = r;
          }
        }
        if (largestRing.isEmpty) continue;

        double sumLat = 0;
        double sumLon = 0;
        int validCount = 0;

        for (final pt in largestRing) {
          if (pt is List && pt.length >= 2) {
            final x = (pt[0] as num).toDouble();
            final y = (pt[1] as num).toDouble();
            sumLon += xToLon(x);
            sumLat += yToLat(y);
            validCount++;
          }
        }

        if (validCount == 0) continue;
        final centroid = LatLng(sumLat / validCount, sumLon / validCount);

        // Parse tree species share percent (part_cd: 1..10, where 10 = 100%, 3 = 30%)
        final rawPart = attrs['part_cd']?.toString().trim();
        int sharePercent = 100;
        if (rawPart != null && rawPart.isNotEmpty) {
          final parsed = int.tryParse(rawPart) ?? 10;
          sharePercent = parsed <= 10 ? parsed * 10 : parsed;
        }

        // Resolve TreeSpecies & Habitat info
        final speciesInfo = BdlParser.getSpeciesInfo(rawSpecies);
        final primarySpecies = TreeSpecies(
          code: rawSpecies,
          namePl: speciesInfo['pl'] ?? rawSpecies,
          nameRu: speciesInfo['ru'] ?? '',
          latin: speciesInfo['latin'] ?? '',
          icon: speciesInfo['icon'] ?? '🌲',
          sharePercent: sharePercent,
        );

        final habitatInfo = BdlParser.getHabitatInfo(rawHabitat);
        final habitat = ForestHabitat(
          code: rawHabitat,
          namePl: habitatInfo['pl'] ?? rawHabitat,
          descPl: habitatInfo['desc'] ?? '',
          moisture: habitatInfo['moisture'] ?? 'optimal',
        );

        final parcel = ForestParcel(
          subareaId: subareaId,
          address: address,
          inspectorate: '',
          primarySpecies: primarySpecies,
          ageYears: effectiveAge,
          ageCategory: '$effectiveAge lat',
          habitat: habitat,
          status: const ForestStatus(
            code: 'GOSP',
            status: ForestLegalStatus.allowed,
            labelPl: 'Las gospodarczy',
            color: Colors.green,
          ),
          areaHa: '${area.toStringAsFixed(2)} ha',
          latitude: centroid.latitude,
          longitude: centroid.longitude,
        );

        // Score this parcel against all mushrooms
        final matches = MatchEngine.evaluateMushrooms(
          parcel: parcel,
          weather: weather,
          selectedMonth: selectedMonth,
        );

        final MushroomMatchResult? best;
        if (targetMushroomId != null && targetMushroomId.isNotEmpty) {
          // Specific Mushroom Target Radar mode (5.1)
          final targeted = matches.where((m) => m.mushroom.id == targetMushroomId);
          best = targeted.isNotEmpty ? targeted.first : null;
        } else {
          // General radar mode:
          // 1. Prized popular mushrooms (Borowik, Kurka, Podgrzybek, Koźlarz, Rydz, Maślak, Kania)
          final prizedMatches = matches.where((m) => popularPrizedIds.contains(m.mushroom.id)).toList();
          final bestPrized = prizedMatches.isNotEmpty ? prizedMatches.first : null;

          // 2. Secondary edible mushrooms (e.g. Mleczaj jodłowy, Opieńka)
          final otherEdible = matches.where(
            (m) =>
                !popularPrizedIds.contains(m.mushroom.id) &&
                !m.mushroom.edibility.toLowerCase().contains('trujący') &&
                !m.mushroom.edibility.toLowerCase().contains('śmiertelnie'),
          ).toList();
          final bestOther = otherEdible.isNotEmpty ? otherEdible.first : null;

          best = bestPrized ?? bestOther;
        }

        if (best != null) {
          final shortTree = primarySpecies.namePl.split(' ').first;
          final shortMushroom = toShortMushroomName(best.mushroom.namePl);
          final abbrevTree = toShortTreeName(primarySpecies.namePl);

          items.add(
            ParcelRadarItem(
              id: '${centroid.latitude.toStringAsFixed(4)}_${centroid.longitude.toStringAsFixed(4)}',
              centroid: centroid,
              speciesName: shortTree,
              speciesShort: abbrevTree,
              ageYears: effectiveAge,
              areaHa: area,
              probabilityPercent: best.probabilityPercent,
              topMushroomName: shortMushroom,
            ),
          );
        }
      }

      // Return top visible forest parcels with balanced viewport density (60-80 top spots)
      // to keep map dragging silky smooth at 60-120 FPS without cluttering.
      const maxViewportRadars = 75;
      if (items.length > maxViewportRadars) {
        items.sort((a, b) => b.probabilityPercent.compareTo(a.probabilityPercent));
        return items.take(maxViewportRadars).toList(growable: false);
      }
      return items;
    } catch (e) {
      debugPrint('[ParcelRadarService] Error fetching radars: $e');
      return [];
    }
  }
}
