import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/map_screen_controller.dart';
import '../../../mushroom_radar/data/mushroom_database.dart';
import 'mushroom_gauge_badge.dart';

/// Minimalist bottom sheet for toggling mushroom radar label details:
/// tree species and featured mushroom name.
class RadarSettingsSheet extends ConsumerWidget {
  const RadarSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const RadarSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showMushroom = ref.watch(
      mapScreenProvider.select((s) => s.showRadarMushroomName),
    );
    final showTree = ref.watch(
      mapScreenProvider.select((s) => s.showRadarTreeSpecies),
    );
    final showLowProbability = ref.watch(
      mapScreenProvider.select((s) => s.showLowProbabilityRadars),
    );
    final targetMushroomId = ref.watch(
      mapScreenProvider.select((s) => s.targetMushroomId),
    );
    final showRainRadar = ref.watch(
      mapScreenProvider.select((s) => s.showRainRadarLayer),
    );
    final showLiveClouds = ref.watch(
      mapScreenProvider.select((s) => s.showLiveRadarCloudLayer),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('⚙️', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text(
                      'Widok Plakietek Radaru',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textDim),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Dostosuj szczegółowość znaczków na mapie pod swój styl wędrówki.',
              style: TextStyle(fontSize: 12, color: AppColors.textDim),
            ),
            const SizedBox(height: 16),

            // Live Preview Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  const Text(
                    'PODGLĄD NA ŻYWO NA MAPIE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDim,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  MushroomGaugeBadge(
                    probability: 85,
                    mushroomName: 'Borowik',
                    speciesName: 'So',
                    ageYears: 65,
                    showMushroomName: showMushroom,
                    showTreeSpecies: showTree,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Target Mushroom Selection (5.1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: targetMushroomId != null
                      ? AppColors.emeraldNeon.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('🎯', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text(
                        'Cel poszukiwań (Radary pod gatunek)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: targetMushroomId,
                        isExpanded: true,
                        dropdownColor: AppColors.surfaceElevated,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.emeraldNeon),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Row(
                              children: [
                                Text('✨', style: TextStyle(fontSize: 14)),
                                SizedBox(width: 8),
                                Text(
                                  'Wszystkie gatunki (Tryb ogólny)',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          ...MushroomDatabase.allMushrooms.map((m) {
                            return DropdownMenuItem<String?>(
                              value: m.id,
                              child: Row(
                                children: [
                                  const Text('🍄', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      m.namePl,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          ref.read(mapScreenProvider.notifier).setTargetMushroom(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Toggle 1: Mushroom name
            _buildOptionTile(
              icon: '🍄',
              title: 'Nazwa grzyba',
              subtitle: 'Pokazuje dominujący gatunek (np. Borowik, Kurka)',
              value: showMushroom,
              onChanged: (_) =>
                  ref.read(mapScreenProvider.notifier).toggleRadarMushroomName(),
            ),
            const SizedBox(height: 10),

            // Toggle 2: Tree species & age
            _buildOptionTile(
              icon: '🌲',
              title: 'Gatunek i wiek lasu',
              subtitle: 'Pokazuje skrót drzewostanu (np. So 65l, Db 80l)',
              value: showTree,
              onChanged: (_) =>
                  ref.read(mapScreenProvider.notifier).toggleRadarTreeSpecies(),
            ),
            const SizedBox(height: 10),

            // Toggle 3: Low probability (< 50%)
            _buildOptionTile(
              icon: '🔍',
              title: 'Miejsca o niskiej szansie (< 50%)',
              subtitle: 'Domyślnie wyłączone, aby pokazywać tylko dobre punkty',
              value: showLowProbability,
              onChanged: (_) =>
                  ref.read(mapScreenProvider.notifier).toggleLowProbabilityRadars(),
            ),
            const SizedBox(height: 10),

            // Toggle 4: 14-day Cumulative Rain Heatmap (Open-Meteo)
            _buildOptionTile(
              icon: '🌧️',
              title: 'Mapa deszczu (14 dni)',
              subtitle: 'Suma opadów z 2 tygodni (uwzględnia deszcz sprzed 2 dni i dziś)',
              value: showRainRadar,
              onChanged: (_) =>
                  ref.read(mapScreenProvider.notifier).toggleRainRadarLayer(),
            ),
            const SizedBox(height: 10),

            // Toggle 5: Real-time Radar Clouds (RainViewer)
            _buildOptionTile(
              icon: '📡',
              title: 'Chmury deszczowe na żywo',
              subtitle: 'Radar chmur i opadów padających dokładnie w tej chwili',
              value: showLiveClouds,
              onChanged: (_) =>
                  ref.read(mapScreenProvider.notifier).toggleLiveRadarClouds(),
            ),
            const SizedBox(height: 18),

            // Done button
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldDeep,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.emeraldNeon, width: 0.8),
                ),
              ),
              child: const Text(
                'Gotowe',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? AppColors.emeraldNeon.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.emeraldNeon.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.emeraldNeon,
            activeTrackColor: AppColors.emeraldDeep,
          ),
        ],
      ),
    );
  }
}
