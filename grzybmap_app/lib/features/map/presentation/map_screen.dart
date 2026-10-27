import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import 'controllers/map_screen_controller.dart';
import '../../forest_search/presentation/controllers/forest_search_controller.dart';
import 'widgets/gps_fab.dart';
import 'widgets/map_top_bar.dart';
import 'widgets/tactical_island_bar.dart';
import 'widgets/mushroom_gauge_badge.dart';
import 'widgets/onboarding_overlay.dart';
import 'widgets/parcel_bottom_sheet.dart';
import 'widgets/radar_settings_sheet.dart';
import '../../foraging_journal/presentation/controllers/foraging_journal_controller.dart';
import '../../foraging_journal/presentation/widgets/save_spot_dialog.dart';
import '../../foraging_journal/presentation/widgets/spot_details_sheet.dart';
import '../../mushroom_radar/data/mushroom_database.dart';
import '../../mushroom_radar/service/parcel_radar_service.dart';
import '../../weather/domain/regional_rainfall.dart';
import '../../offline_mode/presentation/widgets/download_area_dialog.dart';
import '../../offline_mode/presentation/widgets/offline_areas_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  Timer? _debounceRadarTimer;

  @override
  void dispose() {
    _debounceRadarTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _debounceRadarTimer?.cancel();
    // Smooth interaction: while user is actively dragging/gesturing, debounce slightly longer
    // to avoid UI jank from network calls and marker re-layouts mid-gesture.
    final duration = hasGesture
        ? const Duration(milliseconds: 500)
        : const Duration(milliseconds: 250);
    _debounceRadarTimer = Timer(duration, () {
      if (!mounted) return;
      ref.read(mapScreenProvider.notifier).updateVisibleRadars(
            camera.visibleBounds,
            camera.zoom,
          );
    });
  }

  void _onLongPressMap(LatLng point) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.border),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Akcja dla wybranego punktu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Wybierz co chcesz zapisać w tej lokalizacji na mapie:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textDim),
              ),
              const SizedBox(height: 18),
              // Option 1: Save Mushroom Secret Spot
              ListTile(
                onTap: () {
                  Navigator.of(ctx).pop();
                  SaveSpotDialog.show(
                    context: context,
                    location: point,
                  );
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                tileColor: AppColors.card,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('📍', style: TextStyle(fontSize: 20)),
                ),
                title: const Text(
                  'Zapisz sekretne miejsce (Dziennik)',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Zapisz gatunek i zbiór w prywatnym dzienniku offline',
                  style: TextStyle(color: AppColors.textDim, fontSize: 11),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textDim),
              ),
              const SizedBox(height: 10),
              // Option 2: Save Car Parking
              ListTile(
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(mapScreenProvider.notifier).saveCarLocation(point: point);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🚗 Pozycja auta została zapisana!'),
                      backgroundColor: AppColors.emeraldDeep,
                    ),
                  );
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                tileColor: AppColors.card,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.amberWarn.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🚗', style: TextStyle(fontSize: 20)),
                ),
                title: const Text(
                  'Zapisz zaparkowane auto',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Aktywuje kompas i linię bezpiecznego powrotu',
                  style: TextStyle(color: AppColors.textDim, fontSize: 11),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textDim),
              ),
              const SizedBox(height: 10),
              // Option 3: Download Offline Forest Area (10×10 km)
              ListTile(
                onTap: () {
                  Navigator.of(ctx).pop();
                  DownloadAreaDialog.show(
                    context: context,
                    center: point,
                  );
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                tileColor: AppColors.card,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.emeraldDeep.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('💾', style: TextStyle(fontSize: 20)),
                ),
                title: const Text(
                  'Pobierz rejon offline (10×10 km)',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Zapisuje taksację BDL i opady 14d do pamięci urządzenia',
                  style: TextStyle(color: AppColors.textDim, fontSize: 11),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textDim),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTapMap(LatLng point) async {
    if (ref.read(forestSearchProvider).isOpen) {
      ref.read(forestSearchProvider.notifier).closeSearch();
    }

    int currentZoom = 15;
    try {
      currentZoom = _mapController.camera.zoom.toInt();
    } catch (_) {
      currentZoom = 15;
    }

    final result = await ref
        .read(mapScreenProvider.notifier)
        .inspectPoint(point, currentZoom);

    if (!mounted) return;

    switch (result) {
      case InspectionSuccess():
        final state = ref.read(mapScreenProvider);
        unawaited(
          ParcelBottomSheet.show(
            context: context,
            parcel: state.activeParcel,
            weather: state.activeWeather,
            mushroomMatches: state.mushroomMatches,
            currentMonth: state.selectedMonth,
            isOfflineCached: state.isOfflineData,
            onSaveSecretSpot: () {
              SaveSpotDialog.show(
                context: context,
                location: point,
                forestParcelId: state.activeParcel?.subareaId,
                preselectedMushroomId: state.mushroomMatches.isNotEmpty
                    ? state.mushroomMatches.first.mushroom.id
                    : null,
              );
            },
            onSaveCarLocation: () {
              ref.read(mapScreenProvider.notifier).saveCarLocation();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚗 Pozycja auta została zapisana!'),
                  backgroundColor: AppColors.emeraldDeep,
                ),
              );
            },
          ),
        );
      case InspectionError(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.card,
            duration: const Duration(seconds: 4),
          ),
        );
      case InspectionCancelled():
        // Silently discard: superseded by newer user click
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Granular watchers isolate FlutterMap canvas from unrelated state changes
    final currentTileUrl =
        ref.watch(mapScreenProvider.select((s) => s.currentTileUrl));
    final activeBaseLayer =
        ref.watch(mapScreenProvider.select((s) => s.activeBaseLayer));
    final bdlLayerVisible =
        ref.watch(mapScreenProvider.select((s) => s.bdlLayerVisible));
    final userLocation =
        ref.watch(mapScreenProvider.select((s) => s.userLocation));
    final clickedPoint =
        ref.watch(mapScreenProvider.select((s) => s.clickedPoint));
    final carLocation =
        ref.watch(mapScreenProvider.select((s) => s.carLocation));
    final showCarRoute =
        ref.watch(mapScreenProvider.select((s) => s.showCarRoute));
    final parcelRadars =
        ref.watch(mapScreenProvider.select((s) => s.visibleParcelRadars));
    final showParcelRadars =
        ref.watch(mapScreenProvider.select((s) => s.showParcelRadars));
    final showRadarMushroomName =
        ref.watch(mapScreenProvider.select((s) => s.showRadarMushroomName));
    final showRadarTreeSpecies =
        ref.watch(mapScreenProvider.select((s) => s.showRadarTreeSpecies));
    final showRainRadar =
        ref.watch(mapScreenProvider.select((s) => s.showRainRadarLayer));
    final rainRadarTemplate =
        ref.watch(mapScreenProvider.select((s) => s.rainRadarUrlTemplate));
    final regionalRainfall =
        ref.watch(mapScreenProvider.select((s) => s.regionalRainfall));
    final showLiveRadarClouds =
        ref.watch(mapScreenProvider.select((s) => s.showLiveRadarCloudLayer));
    final journalSpots =
        ref.watch(foragingJournalProvider.select((s) => s.spots));
    final isJournalVisible =
        ref.watch(foragingJournalProvider.select((s) => s.isLayerVisible));

    final radarMarkerWidth = (showRadarMushroomName && showRadarTreeSpecies)
        ? 145.0
        : (showRadarMushroomName || showRadarTreeSpecies)
            ? 100.0
            : 60.0;

    return Scaffold(
      body: Stack(
        children: [
          // FlutterMap Canvas
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(52.050, 21.380),
              initialZoom: 15.0,
              minZoom: 6.0,
              maxZoom: 19.0,
              onTap: (_, latlng) => _onTapMap(latlng),
              onLongPress: (_, latlng) => _onLongPressMap(latlng),
              onPositionChanged: (camera, hasGesture) =>
                  _onPositionChanged(camera, hasGesture),
              onMapReady: () {
                final camera = _mapController.camera;
                ref.read(mapScreenProvider.notifier).updateVisibleRadars(
                      camera.visibleBounds,
                      camera.zoom,
                    );
              },
            ),
            children: [
              // Base Layer
              TileLayer(
                urlTemplate: currentTileUrl,
                userAgentPackageName: 'com.grzybmap.poland',
                maxNativeZoom: activeBaseLayer == 'topo' ? 17 : 18,
                maxZoom: 19,
              ),

              // 14-Day Cumulative Rainfall Heatmap Halos (Open-Meteo multi-region)
              if (showRainRadar && regionalRainfall.isNotEmpty)
                MarkerLayer(
                  markers: regionalRainfall.map((RegionalRainfallPoint pt) {
                    return Marker(
                      point: LatLng(pt.latitude, pt.longitude),
                      width: 190,
                      height: 190,
                      alignment: Alignment.center,
                      child: IgnorePointer(
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                pt.heatColor.withValues(alpha: 0.36),
                                pt.heatColor.withValues(alpha: 0.16),
                                pt.heatColor.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),

              // 14-Day Regional Rainfall Badges with exact mm readings
              if (showRainRadar && regionalRainfall.isNotEmpty)
                MarkerLayer(
                  markers: regionalRainfall.map((RegionalRainfallPoint pt) {
                    return Marker(
                      point: LatLng(pt.latitude, pt.longitude),
                      width: 84,
                      height: 28,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '🌧️ ${pt.regionName ?? 'Rejon'}: ${pt.formattedMm} deszczu za 14 dni\n${pt.categoryLabel}',
                              ),
                              backgroundColor: AppColors.card,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated.withValues(alpha: 0.90),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: pt.heatColor.withValues(alpha: 0.8),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: pt.heatColor.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                pt.rainfall14DaysMm >= 22.0 ? '💧' : '☁️',
                                style: const TextStyle(fontSize: 10),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                pt.formattedMm,
                                style: TextStyle(
                                  color: pt.heatColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),

              // Real-Time Radar Clouds Layer (RainViewer Live)
              if (showLiveRadarClouds)
                TileLayer(
                  urlTemplate: rainRadarTemplate ??
                      'https://tilecache.rainviewer.com/v2/radar/4c23604d0d44/256/{z}/{x}/{y}/2/1_1.png',
                  userAgentPackageName: 'com.grzybmap.poland',
                  minZoom: 4,
                  maxNativeZoom: 7,
                  maxZoom: 19,
                  tileBuilder: (context, tileWidget, tile) => Opacity(
                    opacity: 0.65,
                    child: tileWidget,
                  ),
                ),

              // BDL Clean Layer (Clean vector boundaries without baked text labels)
              if (bdlLayerVisible)
                TileLayer(
                  wmsOptions: WMSTileLayerOptions(
                    baseUrl: kIsWeb
                        ? '/api/bdl-tiles?'
                        : ApiConstants.bdlCleanExportUrl,
                    layers: const ['5'],
                    transparent: true,
                    format: 'image/png',
                    version: '1.1.1',
                    crs: const Epsg3857(),
                  ),
                  userAgentPackageName: 'com.grzybmap.poland',
                  minZoom: 12,
                  maxZoom: 19,
                ),

              // Bearing Polyline from user to parked car (only when user requested navigation)
              if (showCarRoute && userLocation != null && carLocation != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [userLocation, carLocation],
                      color: AppColors.amberWarn,
                      strokeWidth: 3.0,
                      borderColor: Colors.black.withValues(alpha: 0.5),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

              // Mushroom Radar Badges for forest parcels (interactive gauges)
              if (showParcelRadars && parcelRadars.isNotEmpty)
                MarkerLayer(
                  markers: parcelRadars.map((item) {
                    return Marker(
                      point: item.centroid,
                      width: radarMarkerWidth,
                      height: 30,
                      alignment: Alignment.center,
                      child: RepaintBoundary(
                        child: MushroomGaugeBadge(
                          probability: item.probability,
                          mushroomName: item.topMushroomName,
                          speciesName: item.speciesShort,
                          ageYears: item.ageYears,
                          showMushroomName: showRadarMushroomName,
                          showTreeSpecies: showRadarTreeSpecies,
                          onTap: () => _onTapMap(item.centroid),
                          onLongPress: () => RadarSettingsSheet.show(context),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),

              // User location marker with high-visibility halo
              if (userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLocation,
                      width: 36,
                      height: 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.skyBlue.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.skyBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.skyBlue,
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              // Pin Marker for clicked point
              if (clickedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: clickedPoint,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.emeraldNeon,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.emeraldNeon,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              // Car location marker with amber pill tag & halo matching mockup
              if (carLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: carLocation,
                      width: 160,
                      height: 58,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () {
                          ref.read(mapScreenProvider.notifier).toggleCarRoute();
                          final isActive = ref.read(mapScreenProvider).showCarRoute;
                          if (isActive && ref.read(mapScreenProvider).userLocation == null) {
                            ref.read(mapScreenProvider.notifier).locateUser();
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isActive
                                    ? '🧭 Nawigacja: linia do auta włączona'
                                    : 'Ukryto linię nawigacji',
                              ),
                              backgroundColor: AppColors.card,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Floating Amber Pill Tag: "🚗 Auto (520m NW)"
                            Consumer(
                              builder: (context, ref, _) {
                                final nav = ref.watch(
                                  mapScreenProvider.select((s) => s.carNavigation),
                                );
                                final label = nav != null
                                    ? 'Auto (${nav.humanDistance} ${nav.cardinalDirection})'
                                    : 'Auto';
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1A11).withValues(alpha: 0.94),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.amberWarn,
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.amberWarn.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.directions_car_rounded,
                                        size: 13,
                                        color: AppColors.amberWarn,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          color: AppColors.amberWarn,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 2),
                            // Car Glyphs Halo on the road
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.amberWarn,
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.amberWarn.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.directions_car_filled_rounded,
                                size: 15,
                                color: AppColors.amberWarn,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              // Secret Foraging Spots Marker Layer (Purple Pill Tags matching mockup)
              if (isJournalVisible && journalSpots.isNotEmpty)
                MarkerLayer(
                  markers: journalSpots.map((spot) {
                    final isKurki = spot.mushroomName.toLowerCase().contains('kurk') ||
                        spot.mushroomName.toLowerCase().contains('pieprznik');
                    final pillColor = isKurki
                        ? const Color(0xFFEAB308)
                        : const Color(0xFFA855F7);
                    final bgColor = isKurki
                        ? const Color(0xFF261D0A).withValues(alpha: 0.94)
                        : const Color(0xFF1E0C2D).withValues(alpha: 0.94);

                    return Marker(
                      point: LatLng(spot.latitude, spot.longitude),
                      width: 140,
                      height: 52,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () {
                          SpotDetailsSheet.show(
                            context: context,
                            spot: spot,
                            onDelete: () {
                              ref
                                  .read(foragingJournalProvider.notifier)
                                  .deleteSpot(spot.id);
                            },
                            onNavigate: () {
                              _mapController.move(
                                LatLng(spot.latitude, spot.longitude),
                                16.0,
                              );
                            },
                          );
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Pill Tag: "[🍄 6x Borowik]" or "[🍄 Kurki]"
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: pillColor,
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: pillColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MushroomVectorIcon(
                                    size: 14,
                                    capColor: pillColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      spot.quantityAmount > 0
                                          ? '${spot.humanQuantity} ${spot.mushroomName}'
                                          : spot.mushroomName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Downward pointer
                            CustomPaint(
                              size: const Size(8, 5),
                              painter: _DownPointerPainter(color: pillColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
            ],
          ),

          // Loading indicator overlay during inspection (isolated build scope)
          Consumer(
            builder: (context, ref, _) {
              final isLoading = ref.watch(
                mapScreenProvider.select((s) => s.isLoadingInspection),
              );
              if (!isLoading) return const SizedBox.shrink();

              return Positioned(
                top: 145,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.emeraldNeon,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Odczyt danych leśnych...',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Onboarding overlay (isolated build scope)
          Consumer(
            builder: (context, ref, _) {
              final showOnboarding = ref.watch(
                mapScreenProvider.select(
                  (s) =>
                      s.showOnboarding &&
                      s.clickedPoint == null &&
                      !s.isLoadingInspection,
                ),
              );
              if (!showOnboarding) return const SizedBox.shrink();

              return OnboardingOverlay(
                onDismiss: () =>
                    ref.read(mapScreenProvider.notifier).dismissOnboarding(),
              );
            },
          ),

          // Dismiss barrier when search dropdown is open (tap anywhere outside to close search)
          Consumer(
            builder: (context, ref, _) {
              final isSearchOpen = ref.watch(
                forestSearchProvider.select((s) => s.isOpen),
              );
              if (!isSearchOpen) return const SizedBox.shrink();

              return Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    ref.read(forestSearchProvider.notifier).closeSearch();
                  },
                ),
              );
            },
          ),

          // Top Header Controls (isolated build scope)
          Consumer(
            builder: (context, ref, _) {
              final isOfflineMode = ref.watch(
                mapScreenProvider.select((s) => s.isOfflineMode),
              );

              return MapTopBar(
                onOpenAbout: () =>
                    Navigator.of(context).pushNamed(AppRoutes.about),
                isOfflineMode: isOfflineMode,
                onOpenOfflineAreas: () => OfflineAreasSheet.show(
                  context: context,
                  currentCenter: _mapController.camera.center,
                  onNavigateToArea: (target) {
                    _mapController.move(target, 14.2);
                    _onTapMap(target);
                  },
                ),
                onSelectPlace: (place) {
                  _mapController.move(place.latLng, 14.5);
                  _onTapMap(place.latLng);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🌲 Nawigacja do: ${place.shortName}'),
                      backgroundColor: AppColors.emeraldDeep,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            },
          ),

          // Compass Dial Widget pointing North (mockup parity)
          CompassDialWidget(
            onResetNorth: () {
              _mapController.rotate(0);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🧭 Zorientowano mapę na Północ (0°)'),
                  backgroundColor: AppColors.emeraldDeep,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),

          // GPS "My Location" FAB (isolated build scope)
          Consumer(
            builder: (context, ref, _) {
              final isLocating = ref.watch(
                mapScreenProvider.select((s) => s.isLocating),
              );
              final hasLocation = ref.watch(
                mapScreenProvider.select((s) => s.userLocation != null),
              );

              return GpsFab(
                isLocating: isLocating,
                hasLocation: hasLocation,
                onPressed: () async {
                  final loc =
                      await ref.read(mapScreenProvider.notifier).locateUser();
                  if (!context.mounted) return;
                  if (loc != null) {
                    _mapController.move(loc, 15.0);
                    final source = ref
                            .read(mapScreenProvider)
                            .locationSourceDescription ??
                        'GPS';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('📍 Zlokalizowano! Źródło: $source'),
                        backgroundColor: AppColors.emeraldDeep,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } else {
                    final errMsg =
                        ref.read(mapScreenProvider).locationErrorMessage;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          errMsg ?? 'Nie udało się pobrać pozycji GPS.',
                        ),
                        backgroundColor: AppColors.card,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
              );
            },
          ),

          // Rain Radar Floating Legend / Status Badge
          Consumer(
            builder: (context, ref, _) {
              final isRainActive = ref.watch(
                mapScreenProvider.select((s) => s.showRainRadarLayer),
              );
              final isLiveActive = ref.watch(
                mapScreenProvider.select((s) => s.showLiveRadarCloudLayer),
              );
              if (!isRainActive && !isLiveActive) return const SizedBox.shrink();

              return Positioned(
                bottom: 86,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🌧️', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            isRainActive
                                ? 'Suma deszczu za 14 dni'
                                : 'Radar chmur na żywo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isRainActive
                            ? '🟦 >35 mm  🟩 22–35 mm  🟨 12–22 mm'
                            : '🟦 Lekki  🟨 Umiarkowany  🟥 Ulewa',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Bottom Tactical Island Bar (Consolidated 5-module HUD)
          Consumer(
            builder: (context, ref, _) {
              final activeLayerLabel = ref.watch(
                mapScreenProvider.select((s) => s.activeLayerLabel),
              );
              final isRadarsActive = ref.watch(
                mapScreenProvider.select((s) => s.showParcelRadars),
              );
              final targetMushroomId = ref.watch(
                mapScreenProvider.select((s) => s.targetMushroomId),
              );
              final journalSpots = ref.watch(
                foragingJournalProvider.select((s) => s.spots),
              );
              final isOfflineMode = ref.watch(
                mapScreenProvider.select((s) => s.isOfflineMode),
              );
              final downloadedAreas = ref.watch(
                mapScreenProvider.select((s) => s.downloadedAreas),
              );
              final carLoc = ref.watch(
                mapScreenProvider.select((s) => s.carLocation),
              );
              final nav = ref.watch(
                mapScreenProvider.select((s) => s.carNavigation),
              );
              final isRouteActive = ref.watch(
                mapScreenProvider.select((s) => s.showCarRoute),
              );
              final parkedTime = ref.watch(
                mapScreenProvider.select((s) => s.carParkedTime),
              );

              final targetMushroom = targetMushroomId != null
                  ? MushroomDatabase.allMushrooms.firstWhere(
                      (m) => m.id == targetMushroomId,
                      orElse: () => MushroomDatabase.allMushrooms.first,
                    )
                  : null;

              final targetShortName = targetMushroom != null
                  ? ParcelRadarService.toShortMushroomName(targetMushroom.namePl)
                  : null;

              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: TacticalIslandBar(
                  isRadarsActive: isRadarsActive,
                  targetMushroomName: targetShortName,
                  onToggleRadars: () => RadarSettingsSheet.show(context),
                  onLongPressRadars: () {
                    ref.read(mapScreenProvider.notifier).setTargetMushroom(null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🎯 Zresetowano filtr grzyba (Wszystkie gatunki)'),
                        backgroundColor: AppColors.emeraldDeep,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  carLocation: carLoc,
                  carNavigation: nav,
                  isCarRouteActive: isRouteActive,
                  carParkedTime: parkedTime,
                  onSaveCar: () async {
                    var userLoc = ref.read(mapScreenProvider).userLocation;
                    userLoc ??= await ref.read(mapScreenProvider.notifier).locateUser();
                    final target = userLoc ?? _mapController.camera.center;
                    ref.read(mapScreenProvider.notifier).saveCarLocation(point: target);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          userLoc != null
                              ? '🚗 Zapisano auto w Twojej pozycji!'
                              : '🚗 Zapisano auto w centrum mapy (Włącz GPS dla dystansu)',
                        ),
                        backgroundColor: AppColors.emeraldDeep,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  onToggleCarRoute: () {
                    ref.read(mapScreenProvider.notifier).toggleCarRoute();
                    final isActive = ref.read(mapScreenProvider).showCarRoute;
                    if (isActive && ref.read(mapScreenProvider).userLocation == null) {
                      ref.read(mapScreenProvider.notifier).locateUser();
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isActive
                              ? '🧭 Nawigacja: linia powrotu do auta włączona'
                              : 'Ukryto linię nawigacji',
                        ),
                        backgroundColor: AppColors.card,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  onCenterCar: () {
                    if (carLoc != null) {
                      _mapController.move(carLoc, 16.0);
                    }
                  },
                  onClearCar: () {
                    ref.read(mapScreenProvider.notifier).clearCarLocation();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🚗 Usunięto znacznik auta.'),
                        backgroundColor: AppColors.card,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  journalSpotsCount: journalSpots.length,
                  onOpenJournal: () =>
                      Navigator.of(context).pushNamed(AppRoutes.journal),
                  onQuickAddSpot: () async {
                    var userLoc = ref.read(mapScreenProvider).userLocation;
                    userLoc ??= await ref.read(mapScreenProvider.notifier).locateUser();
                    final target = userLoc ?? _mapController.camera.center;
                    if (!context.mounted) return;
                    unawaited(
                      SaveSpotDialog.show(
                        context: context,
                        location: target,
                      ),
                    );
                  },
                  offlineAreasCount: downloadedAreas.length,
                  isOfflineMode: isOfflineMode,
                  onOpenOffline: () => OfflineAreasSheet.show(
                    context: context,
                    currentCenter: _mapController.camera.center,
                    onNavigateToArea: (target) {
                      _mapController.move(target, 14.2);
                      _onTapMap(target);
                    },
                  ),
                  activeLayerLabel: activeLayerLabel,
                  onCycleLayer: () =>
                      ref.read(mapScreenProvider.notifier).cycleBaseLayer(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DownPointerPainter extends CustomPainter {
  final Color color;

  _DownPointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
