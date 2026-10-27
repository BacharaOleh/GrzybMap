import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../map/presentation/controllers/map_screen_controller.dart';
import 'download_area_dialog.dart';

/// Modal bottom sheet for managing downloaded offline forest packages
/// and toggling forced offline simulation mode.
class OfflineAreasSheet extends ConsumerWidget {
  final LatLng currentCenter;
  final void Function(LatLng target)? onNavigateToArea;

  const OfflineAreasSheet({
    super.key,
    required this.currentCenter,
    this.onNavigateToArea,
  });

  static Future<void> show({
    required BuildContext context,
    required LatLng currentCenter,
    void Function(LatLng target)? onNavigateToArea,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfflineAreasSheet(
        currentCenter: currentCenter,
        onNavigateToArea: onNavigateToArea,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapScreenProvider);
    final notifier = ref.read(mapScreenProvider.notifier);
    final areas = mapState.downloadedAreas;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldDeep.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('📡', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tryb Offline (Głuchy Las)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pakiety leśne działające w 100% bez sieci 4G',
                          style: TextStyle(color: AppColors.textDim, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textDim, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Forced offline mode switch card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: mapState.isOfflineMode
                      ? AppColors.emeraldDeep.withValues(alpha: 0.15)
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: mapState.isOfflineMode
                        ? AppColors.emeraldLight.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                mapState.isOfflineMode
                                    ? 'Tryb offline aktywny'
                                    : 'Symuluj brak sieci (Tryb offline)',
                                style: TextStyle(
                                  color: mapState.isOfflineMode
                                      ? AppColors.emeraldLight
                                      : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (mapState.isOfflineMode) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.emeraldDeep,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'BEZ SIECI',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            mapState.isOfflineMode
                                ? 'Aplikacja korzysta wyłącznie z zapisanych w telefonie pakietów BDL.'
                                : 'Wymusza korzystanie z lokalnej pamięci (sprawdź działanie w lesie).',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: mapState.isOfflineMode,
                      thumbColor: const WidgetStatePropertyAll<Color>(AppColors.emeraldLight),
                      activeTrackColor: AppColors.emeraldDeep,
                      onChanged: (val) {
                        notifier.setOfflineMode(val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section label: Saved regions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Zapisane pakiety leśne',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${areas.length}',
                      style: const TextStyle(
                        color: AppColors.emeraldLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // List of saved areas
            Flexible(
              child: areas.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      shrinkWrap: true,
                      itemCount: areas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        final area = areas[index];
                        return _buildAreaCard(context, ref, area);
                      },
                    ),
            ),

            // Bottom download button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  DownloadAreaDialog.show(
                    context: context,
                    center: currentCenter,
                  );
                },
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Pobierz ten widok mapy (10 × 10 km)'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emeraldDeep,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text('🌲', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Brak pobranych pakietów leśnych',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pobierz kwadrat 10×10 km przed wyruszeniem w głąb puszczy, aby sprawdzać gatunki drzew i szanse na borowiki bez zasięgu telefonu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaCard(
    BuildContext context,
    WidgetRef ref,
    dynamic area,
  ) {
    final notifier = ref.read(mapScreenProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Delete button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.emeraldDeep.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('🌲', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  area.name as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textDim, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Usuń pakiet',
                onPressed: () {
                  notifier.deleteOfflineArea(area.id as String);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Badges row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadge(
                icon: Icons.layers_rounded,
                label: '${area.parcelsCount} wydzieleń',
                color: AppColors.emeraldLight,
              ),
              _buildBadge(
                icon: Icons.storage_rounded,
                label: area.formattedSize as String,
                color: Colors.white70,
              ),
              _buildBadge(
                icon: Icons.water_drop_rounded,
                label: '${(area.weatherRainMm as double).toStringAsFixed(1)} mm (14d)',
                color: const Color(0xFF60A5FA),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Date & Navigate button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Zapisano: ${area.formattedDate}',
                style: const TextStyle(color: AppColors.textDim, fontSize: 11),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  final target = LatLng(area.centerLat as double, area.centerLng as double);
                  onNavigateToArea?.call(target);
                },
                icon: const Icon(Icons.explore_rounded, size: 14, color: AppColors.emeraldLight),
                label: const Text(
                  'Pokaż na mapie',
                  style: TextStyle(
                    color: AppColors.emeraldLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
