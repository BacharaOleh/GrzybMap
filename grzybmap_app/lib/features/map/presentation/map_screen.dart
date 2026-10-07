import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import 'controllers/map_screen_controller.dart';
import 'widgets/gps_fab.dart';
import 'widgets/map_top_bar.dart';
import 'widgets/onboarding_overlay.dart';
import 'widgets/parcel_bottom_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  Future<void> _onTapMap(LatLng point) async {
    int currentZoom = 15;
    try {
      currentZoom = _mapController.camera.zoom.toInt();
    } catch (_) {
      currentZoom = 15;
    }

    final success = await ref
        .read(mapScreenProvider.notifier)
        .inspectPoint(point, currentZoom);

    if (!mounted) return;

    if (success) {
      final state = ref.read(mapScreenProvider);
      ParcelBottomSheet.show(
        context: context,
        parcel: state.activeParcel,
        weather: state.activeWeather,
        mushroomMatches: state.mushroomMatches,
        currentMonth: state.selectedMonth,
        onSaveCarLocation: () {
          ref.read(mapScreenProvider.notifier).saveCarLocation();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚗 Pozycja auta została zapisana!'),
              backgroundColor: AppColors.emeraldDeep,
            ),
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Błąd połączenia z BDL: spróbuj ponownie'),
          backgroundColor: AppColors.card,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapScreenProvider);

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
            ),
            children: [
              // Base Layer
              TileLayer(
                urlTemplate: state.currentTileUrl,
                userAgentPackageName: 'com.grzybmap.poland',
                maxNativeZoom: state.activeBaseLayer == 'topo' ? 17 : 18,
                maxZoom: 19,
              ),

              // BDL WMS Layer (Wydzielenia)
              if (state.bdlLayerVisible)
                TileLayer(
                  wmsOptions: WMSTileLayerOptions(
                    baseUrl: kIsWeb
                        ? '/api/bdl?'
                        : 'https://mapserver.bdl.lasy.gov.pl/ArcGIS/services/WMS_BDL/MapServer/WMSServer?',
                    layers: const ['1'],
                    transparent: true,
                    format: 'image/png',
                    version: '1.1.1',
                    crs: const Epsg3857(),
                  ),
                  userAgentPackageName: 'com.grzybmap.poland',
                  minZoom: 12,
                  maxZoom: 19,
                ),

              // User location marker with high-visibility halo
              if (state.userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: state.userLocation!,
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
              if (state.clickedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: state.clickedPoint!,
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
            ],
          ),

          // Loading indicator overlay during inspection
          if (state.isLoadingInspection)
            Positioned(
              top: 80,
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
            ),

          // Onboarding overlay
          if (state.showOnboarding &&
              state.clickedPoint == null &&
              !state.isLoadingInspection)
            OnboardingOverlay(
              onDismiss: () =>
                  ref.read(mapScreenProvider.notifier).dismissOnboarding(),
            ),

          // Top Header Controls
          MapTopBar(
            activeLayerLabel: state.activeLayerLabel,
            onCycleLayer: () =>
                ref.read(mapScreenProvider.notifier).cycleBaseLayer(),
            onOpenAbout: () => Navigator.of(context).pushNamed(AppRoutes.about),
          ),

          // GPS "My Location" FAB
          GpsFab(
            isLocating: state.isLocating,
            hasLocation: state.userLocation != null,
            onPressed: () async {
              final loc =
                  await ref.read(mapScreenProvider.notifier).locateUser();
              if (!context.mounted) return;
              if (loc != null) {
                _mapController.move(loc, 15.0);
                final source = ref.read(mapScreenProvider).locationSourceDescription ?? 'GPS';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📍 Zlokalizowano! Źródło: $source'),
                    backgroundColor: AppColors.emeraldDeep,
                    duration: const Duration(seconds: 3),
                  ),
                );
              } else {
                final errMsg = ref.read(mapScreenProvider).locationErrorMessage;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errMsg ?? 'Nie udało się pobrać pozycji GPS.'),
                    backgroundColor: AppColors.card,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
