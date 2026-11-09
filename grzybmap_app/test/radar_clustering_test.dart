import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:grzybmap_app/features/mushroom_radar/domain/parcel_radar.dart';
import 'package:grzybmap_app/features/mushroom_radar/service/parcel_radar_service.dart';

void main() {
  group('ParcelRadarService Clustering & Non-Maximum Suppression Tests', () {
    test('Returns empty list when input is empty', () {
      final result = ParcelRadarService.clusterAndThinRadars(
        items: const [],
        zoom: 15.0,
      );
      expect(result, isEmpty);
    });

    test('Filters out items below minProbability threshold', () {
      final items = [
        const ParcelRadarItem(
          id: '1',
          centroid: LatLng(52.20, 20.80),
          speciesName: 'Sosna',
          speciesShort: 'So',
          ageYears: 60,
          areaHa: 5.0,
          probabilityPercent: 40,
          topMushroomName: 'Maślak',
        ),
        const ParcelRadarItem(
          id: '2',
          centroid: LatLng(52.25, 20.85),
          speciesName: 'Sosna',
          speciesShort: 'So',
          ageYears: 70,
          areaHa: 6.0,
          probabilityPercent: 75,
          topMushroomName: 'Borowik',
        ),
      ];

      final result = ParcelRadarService.clusterAndThinRadars(
        items: items,
        zoom: 15.0,
        minProbability: 60,
      );

      expect(result.length, 1);
      expect(result.first.id, '2');
      expect(result.first.probabilityPercent, 75);
    });

    test('Groups densely packed adjacent parcels into representative cluster with nearbyCount', () {
      // 5 adjacent sub-parcels separated by ~30 meters (0.0003 deg)
      final denseParcels = List.generate(5, (i) {
        return ParcelRadarItem(
          id: 'parcel_$i',
          centroid: LatLng(52.2000 + (i * 0.0003), 20.8000 + (i * 0.0003)),
          speciesName: 'Sosna',
          speciesShort: 'So',
          ageYears: 65,
          areaHa: i == 2 ? 10.0 : 2.0, // parcel 2 has largest area
          probabilityPercent: i == 2 ? 98 : 88,
          topMushroomName: 'Borowik',
        );
      });

      final result = ParcelRadarService.clusterAndThinRadars(
        items: denseParcels,
        zoom: 15.0,
        minPixelDistance: 75.0,
      );

      // Must collapse all 5 overlapping parcels into 1 single representative
      expect(result.length, 1);
      expect(result.first.id, 'parcel_2'); // picked the 98% 10ha parcel
      expect(result.first.nearbyCount, 4); // 4 other parcels clustered nearby
      expect(result.first.isHero, isTrue);
    });

    test('Respects maxLimit and keeps well-separated parcels', () {
      // 10 parcels separated by 0.05 deg (~5 km apart)
      final dispersedParcels = List.generate(10, (i) {
        return ParcelRadarItem(
          id: 'far_$i',
          centroid: LatLng(52.0 + (i * 0.05), 20.0 + (i * 0.05)),
          speciesName: 'Dąb',
          speciesShort: 'Db',
          ageYears: 80,
          areaHa: 4.0,
          probabilityPercent: 70 + i,
          topMushroomName: 'Borowik',
        );
      });

      final result = ParcelRadarService.clusterAndThinRadars(
        items: dispersedParcels,
        zoom: 15.0,
        maxLimit: 5,
      );

      expect(result.length, 5);
      // Ensure sorted by prominence (highest probability first)
      expect(result.first.probabilityPercent, 79);
    });

    test('RadarDensityMode helpers provide consistent limits and distances across zoom levels', () {
      expect(RadarDensityMode.minimal.getMaxLimit(14.0), 6);
      expect(RadarDensityMode.minimal.getMaxLimit(15.0), 10);
      expect(RadarDensityMode.minimal.getMaxLimit(16.5), 14);

      expect(RadarDensityMode.balanced.getMaxLimit(14.0), 10);
      expect(RadarDensityMode.balanced.getMaxLimit(15.0), 18);
      expect(RadarDensityMode.balanced.getMaxLimit(16.5), 25);

      expect(RadarDensityMode.all.getMaxLimit(15.0), 75);

      expect(RadarDensityMode.minimal.minPixelDistance, greaterThan(RadarDensityMode.balanced.minPixelDistance));
      expect(RadarDensityMode.balanced.minPixelDistance, greaterThan(RadarDensityMode.all.minPixelDistance));
    });

    test('RadarDensityMode.minimal produces fewer clusters than balanced on dense data', () {
      final denseParcels = List.generate(20, (i) {
        return ParcelRadarItem(
          id: 'p_$i',
          centroid: LatLng(52.200 + (i * 0.001), 20.800 + (i * 0.001)),
          speciesName: 'Sosna',
          speciesShort: 'So',
          ageYears: 65,
          areaHa: 4.0,
          probabilityPercent: 70 + (i % 25),
          topMushroomName: 'Borowik',
        );
      });

      final minimalResult = ParcelRadarService.clusterAndThinRadars(
        items: denseParcels,
        zoom: 15.0,
        maxLimit: RadarDensityMode.minimal.getMaxLimit(15.0),
        minPixelDistance: RadarDensityMode.minimal.minPixelDistance,
      );

      final balancedResult = ParcelRadarService.clusterAndThinRadars(
        items: denseParcels,
        zoom: 15.0,
        maxLimit: RadarDensityMode.balanced.getMaxLimit(15.0),
        minPixelDistance: RadarDensityMode.balanced.minPixelDistance,
      );

      expect(minimalResult.length, lessThanOrEqualTo(balancedResult.length));
    });
  });
}

