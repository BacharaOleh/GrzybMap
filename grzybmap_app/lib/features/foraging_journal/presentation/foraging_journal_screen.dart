import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../map/presentation/widgets/mushroom_photo_widget.dart';
import '../../mushroom_radar/data/mushroom_database.dart';
import '../domain/models/foraging_spot.dart';
import 'controllers/foraging_journal_controller.dart';
import 'widgets/spot_details_sheet.dart';

/// Full screen view of the user's private foraging journal history.
class ForagingJournalScreen extends ConsumerWidget {
  const ForagingJournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foragingJournalProvider);
    final spots = state.filteredSpots;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.auto_stories_rounded, color: AppColors.emeraldNeon, size: 20),
            SizedBox(width: 10),
            Text(
              'Dziennik Zbiorów',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          // Eye toggle to show/hide spots on map
          IconButton(
            tooltip: state.isLayerVisible ? 'Ukryj na mapie' : 'Pokaż na mapie',
            icon: Icon(
              state.isLayerVisible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: state.isLayerVisible ? AppColors.emeraldNeon : AppColors.textDim,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(foragingJournalProvider.notifier).toggleLayerVisibility();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.isLayerVisible
                        ? 'Miejscówki ukryte na mapie'
                        : 'Miejscówki widoczne na mapie',
                  ),
                  backgroundColor: AppColors.card,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Stats Banner with tabular figures & neutral dividers
          _JournalStatsHeader(
            totalCount: state.totalSpotsCount,
            totalKg: state.estimatedTotalKg,
          ),

          // Mushroom Filter Chips
          if (state.spots.isNotEmpty) _SpeciesFilterBar(),

          // Spots List
          Expanded(
            child: spots.isEmpty
                ? const _EmptyJournalView()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: spots.length,
                    itemBuilder: (context, index) {
                      final spot = spots[index];
                      return _SpotCard(
                        spot: spot,
                        onShowOnMap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop(spot);
                        },
                        onTap: () {
                          SpotDetailsSheet.show(
                            context: context,
                            spot: spot,
                            onDelete: () {
                              ref
                                  .read(foragingJournalProvider.notifier)
                                  .deleteSpot(spot.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Usunięto miejscówkę z dziennika'),
                                  backgroundColor: AppColors.card,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            onNavigate: () {
                              Navigator.of(context).pop(spot);
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _JournalStatsHeader extends StatelessWidget {
  final int totalCount;
  final double totalKg;

  const _JournalStatsHeader({
    required this.totalCount,
    required this.totalKg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(
            label: 'Miejscówki',
            value: totalCount.toString(),
            unit: 'zapisanych',
            icon: Icons.bookmark_added_rounded,
            color: AppColors.textMain,
            accentColor: AppColors.emeraldNeon,
          ),
          Container(width: 1, height: 32, color: AppColors.borderLight),
          _StatColumn(
            label: 'Łączny zbiór',
            value: totalKg == totalKg.roundToDouble()
                ? totalKg.toInt().toString()
                : totalKg.toStringAsFixed(1),
            unit: 'kg szac.',
            icon: Icons.scale_rounded,
            color: AppColors.emeraldNeon,
            accentColor: AppColors.emeraldNeon,
          ),
          Container(width: 1, height: 32, color: AppColors.borderLight),
          const _StatColumn(
            label: 'Prywatność',
            value: '100%',
            unit: 'Offline',
            icon: Icons.shield_outlined,
            color: AppColors.skyBlue,
            accentColor: AppColors.skyBlue,
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final Color? accentColor;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: accentColor ?? color),
            const SizedBox(width: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          unit,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: AppTypography.microLabel,
        ),
      ],
    );
  }
}

class _SpeciesFilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(
      foragingJournalProvider.select((s) => s.filterMushroomId),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FilterPill(
              label: 'Wszystkie',
              isSelected: selectedFilter == null,
              onTap: () {
                HapticFeedback.selectionClick();
                ref
                    .read(foragingJournalProvider.notifier)
                    .setFilterMushroom(null);
              },
            ),
          ),
          ...MushroomDatabase.allMushrooms.map((m) {
            final isSelected = selectedFilter == m.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterPill(
                label: m.namePl,
                isSelected: isSelected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(foragingJournalProvider.notifier)
                      .setFilterMushroom(isSelected ? null : m.id);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.emeraldNeon.withValues(alpha: 0.16)
            : const Color(0x0FFFFFFF),
        borderRadius: AppRadii.pillRadius,
        border: Border.all(
          color: isSelected ? AppColors.emeraldNeon : AppColors.borderLight,
          width: 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.emeraldNeon.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.pillRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.emeraldNeon,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  final ForagingSpot spot;
  final VoidCallback onTap;
  final VoidCallback? onShowOnMap;

  const _SpotCard({
    required this.spot,
    required this.onTap,
    this.onShowOnMap,
  });

  @override
  Widget build(BuildContext context) {
    final mushroom = MushroomDatabase.allMushrooms.firstWhere(
      (m) => m.id == spot.mushroomId,
      orElse: () => MushroomDatabase.allMushrooms.first,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Botanical Photo Thumbnail or custom user photo with concentric radius
                MushroomPhotoWidget(
                  assetPath: mushroom.photoAsset,
                  base64Data: spot.photoPath,
                  size: 46,
                  borderRadius: AppRadii.inner,
                  borderColor: spot.hasPhoto
                      ? AppColors.emeraldNeon.withValues(alpha: 0.6)
                      : AppColors.borderLight,
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.title,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        spot.mushroomName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.emeraldNeon,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            spot.formattedDate,
                            style: AppTypography.microLabel.copyWith(
                              color: AppColors.textDim,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (spot.hasPhoto) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.photo_camera_rounded,
                              size: 11,
                              color: AppColors.emeraldNeon,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Weight Pill with tabular figures
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.pillRadius,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    spot.humanQuantity,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (onShowOnMap != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.explore_rounded,
                      color: AppColors.emeraldNeon,
                      size: 20,
                    ),
                    tooltip: 'Pokaż na mapie',
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    onPressed: onShowOnMap,
                  ),
                ] else ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppColors.textDim,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyJournalView extends StatelessWidget {
  const _EmptyJournalView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderLight),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.bookmark_border_rounded,
                size: 34,
                color: AppColors.emeraldNeon.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Brak zapisanych miejscówek',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gdy znajdziesz udany zbiór w lesie, kliknij "Zapisz to miejsce" w karcie wycinania lub przytrzymaj palec na mapie, aby zapisać punkt!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textDim, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
