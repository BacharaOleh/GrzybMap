import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
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
            Text('📓', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
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
              ref.read(foragingJournalProvider.notifier).toggleLayerVisibility();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.isLayerVisible
                        ? '🙈 Miejscówki ukryte na mapie'
                        : '👁️ Miejscówki widoczne na mapie',
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
          // Stats Banner
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
                                  content: Text('🗑️ Usunięto miejscówkę z dziennika'),
                                  backgroundColor: AppColors.card,
                                  duration: Duration(seconds: 2),
                                ),
                              );
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
            icon: Icons.place_rounded,
            color: const Color(0xFF8B5CF6),
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          _StatColumn(
            label: 'Łączny zbiór',
            value: totalKg == totalKg.roundToDouble()
                ? totalKg.toInt().toString()
                : totalKg.toStringAsFixed(1),
            unit: 'kg szac.',
            icon: Icons.scale_rounded,
            color: AppColors.emeraldNeon,
          ),
          Container(width: 1, height: 40, color: AppColors.border),
          const _StatColumn(
            label: 'Prywatność',
            value: '100%',
            unit: 'Offline',
            icon: Icons.lock_outline_rounded,
            color: AppColors.amberWarn,
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

  const _StatColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textDim),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Wszystkie'),
              selected: selectedFilter == null,
              onSelected: (_) => ref
                  .read(foragingJournalProvider.notifier)
                  .setFilterMushroom(null),
              backgroundColor: AppColors.card,
              selectedColor: AppColors.emeraldDeep,
              labelStyle: TextStyle(
                color: selectedFilter == null ? Colors.white : AppColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          ...MushroomDatabase.allMushrooms.map((m) {
            final isSelected = selectedFilter == m.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(m.namePl),
                selected: isSelected,
                onSelected: (_) => ref
                    .read(foragingJournalProvider.notifier)
                    .setFilterMushroom(isSelected ? null : m.id),
                backgroundColor: AppColors.card,
                selectedColor: AppColors.emeraldDeep,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                side: const BorderSide(color: AppColors.border),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  final ForagingSpot spot;
  final VoidCallback onTap;

  const _SpotCard({
    required this.spot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Mushroom Icon Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🍄', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
                      const SizedBox(height: 4),
                      Text(
                        spot.formattedDate,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),

                // Quantity badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    spot.humanQuantity,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textDim,
                ),
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
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: const Text('📍', style: TextStyle(fontSize: 32)),
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
