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

class _MutableCluster {
  final ParcelRadarItem representative;
  int count;

  _MutableCluster({required this.representative, required this.count});
}

class ParcelRadarService {
  final Dio _dio;
  final Map<String, List<ParcelRadarItem>> _lruCache = {};

  ParcelRadarService({Dio? dio}) : _dio = dio ?? Dio();

  void clearCache() {
    _lruCache.clear();
  }

  /// Spatial Grid & Non-Maximum Suppression (NMS) algorithm.
  /// Eliminates badge overlap and visual clutter by grouping parcels that are too close
  /// on screen into a single high-priority representative marker with nearby count.
  static List<ParcelRadarItem> clusterAndThinRadars({
    required List<ParcelRadarItem> items,
    required double zoom,
    int minProbability = 50,
    int maxLimit = 20,
    double minPixelDistance = 75.0,
  }) {
    if (items.isEmpty) return const [];

    // 1. Filter by minimum probability threshold
    final filtered =
        items.where((it) => it.probabilityPercent >= minProbability).toList();
    if (filtered.isEmpty) return const [];

    // 2. Sort by prominence score:
    // Stand area (ha) combined with probability ensures large productive forests
    // are favored over tiny roadside ditch fragments.
    filtered.sort((a, b) {
      final areaBonusA = min(a.areaHa, 20.0) * 0.75;
      final areaBonusB = min(b.areaHa, 20.0) * 0.75;
      final scoreA = a.probabilityPercent + areaBonusA;
      final scoreB = b.probabilityPercent + areaBonusB;
      return scoreB.compareTo(scoreA);
    });

    // 3. Dynamic degree threshold based on zoom level:
    // In Web Mercator at Poland's latitude (52 deg), 1 pixel is ~ (360 / (256 * 2^zoom)) deg lon.
    final degPerPixelLon = 360.0 / (256.0 * pow(2.0, zoom));
    final degPerPixelLat = degPerPixelLon * 0.615; // cos(52°) ≈ 0.615

    final minLonDistance = degPerPixelLon * minPixelDistance;
    final minLatDistance = degPerPixelLat * (minPixelDistance * 0.55);

    final accepted = <_MutableCluster>[];

    for (final item in filtered) {
      _MutableCluster? nearbyCluster;

      for (final cl in accepted) {
        final dLat =
            (item.centroid.latitude - cl.representative.centroid.latitude).abs();
        final dLon =
            (item.centroid.longitude - cl.representative.centroid.longitude).abs();

        if (dLat < minLatDistance && dLon < minLonDistance) {
          nearbyCluster = cl;
          break;
        }
      }

      if (nearbyCluster != null) {
        nearbyCluster.count++;
      } else {
        if (accepted.length < maxLimit) {
          accepted.add(_MutableCluster(representative: item, count: 0));
        }
      }
    }

    // 4. Determine Hero badges vs Micro-pips:
    // Top 5 or those with clusters are Hero badges; remainder are clean micro-pips
    final result = <ParcelRadarItem>[];
    for (int i = 0; i < accepted.length; i++) {
      final cl = accepted[i];
      final isHero =
          i < 6 || cl.count > 0 || cl.representative.probabilityPercent >= 90;
      result.add(
        cl.representative.copyWith(
          nearbyCount: cl.count,
          isHero: isHero,
        ),
      );
    }

    return result;
  }

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
    double zoom = 15.0,
    int minProbability = 50,
    int maxLimit = 20,
    double minPixelDistance = 75.0,
    CancelToken? cancelToken,
  }) async {
    try {
      final cacheKey =
          '${minLat.toStringAsFixed(3)}_${minLng.toStringAsFixed(3)}_${maxLat.toStringAsFixed(3)}_${maxLng.toStringAsFixed(3)}_m${selectedMonth}_t${targetMushroomId ?? "all"}';

      if (_lruCache.containsKey(cacheKey)) {
        return clusterAndThinRadars(
          items: _lruCache[cacheKey]!,
          zoom: zoom,
          minProbability: minProbability,
          maxLimit: maxLimit,
          minPixelDistance: minPixelDistance,
        );
      }

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

      // Save to LRU memory cache
      if (_lruCache.length > 25) {
        _lruCache.remove(_lruCache.keys.first);
      }
      _lruCache[cacheKey] = items;

      return clusterAndThinRadars(
        items: items,
        zoom: zoom,
        minProbability: minProbability,
        maxLimit: maxLimit,
        minPixelDistance: minPixelDistance,
      );
    } catch (e) {
      debugPrint('[ParcelRadarService] Error fetching radars: $e');
      return [];
    }
  }
}
