import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/map_screen_controller.dart';
import '../../../mushroom_radar/data/mushroom_database.dart';
import '../../../mushroom_radar/domain/models.dart';
import '../../../mushroom_radar/domain/parcel_radar.dart';
import 'mushroom_gauge_badge.dart';
import 'mushroom_photo_widget.dart';
import 'mushroom_search_sheet.dart';

/// Metadata model for each radar setting option with detailed mycological
/// explanations and practical in-field tips hidden behind an info button.
class _RadarOptionMeta {
  final String id;
  final String icon;
  final String title;
  final String subtitle;
  final String shortTag;
  final String detailedExplanation;
  final String whyItMatters;
  final String exampleDisplay;
  final Color accentColor;

  const _RadarOptionMeta({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.shortTag,
    required this.detailedExplanation,
    required this.whyItMatters,
    required this.exampleDisplay,
    required this.accentColor,
  });
}

/// Aesthetic bottom sheet for configuring mushroom radar badges,
/// targeting specific mushroom species with live search, and toggling weather layers.
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

  static const List<_RadarOptionMeta> _options = [
    _RadarOptionMeta(
      id: 'mushroom_name',
      icon: '🍄',
      title: 'Nazwa grzyba',
      subtitle: 'Pokaż dominujący gatunek na plakietce',
      shortTag: 'Plakietka radaru',
      detailedExplanation:
          'Wyświetla nazwę najbardziej dopasowanego gatunku grzyba (np. Borowik, Pieprznik, Podgrzybek) bezpośrednio na plakietce radaru.',
      whyItMatters:
          'Nie musisz klikać w każdy sektor z osobna. Od razu na mapie widzisz, jakiego konkretnie gatunku możesz się spodziewać w danym fragmencie lasu.',
      exampleDisplay: 'Plakietka wyświetla: „🍄 Borowik 85%” zamiast samego procentu.',
      accentColor: AppColors.emeraldNeon,
    ),
    _RadarOptionMeta(
      id: 'tree_species',
      icon: '🌲',
      title: 'Gatunek i wiek lasu',
      subtitle: 'Skrót drzewostanu BDL (np. So 65l)',
      shortTag: 'Dane BDL',
      detailedExplanation:
          'Wyświetla oficjalny skrót dominującego gatunku drzewa oraz wiek drzewostanu pobrany z Banku Danych o Lasach (BDL).',
      whyItMatters:
          'Klucz do sukcesu: prawdziwki i borowiki preferują starodrzew sosnowy i dębowy (50-90 lat), natomiast maślaki rosną w młodnikach sosnowych (do 20 lat).',
      exampleDisplay: 'Plakietka wyświetla: „🌲 So 65l” (Sosna 65 lat) lub „Db 80l” (Dąb 80 lat).',
      accentColor: AppColors.emeraldNeon,
    ),
    _RadarOptionMeta(
      id: 'low_probability',
      icon: '🔍',
      title: 'Miejsca o niskiej szansie (< 50%)',
      subtitle: 'Pokaż słabsze sektory do dokładnej eksploracji',
      shortTag: 'Czułość radaru',
      detailedExplanation:
          'Odkrywa na mapie sektory leśne, gdzie szansa na zbiór wynosi poniżej 50%. Domyślnie filtr jest wyłączony, aby mapa była czytelna i skupiona na najlepszych miejscówkach.',
      whyItMatters:
          'Przydatne podczas suszy lub poza szczytem sezonu, kiedy zależy Ci na zbadaniu absolutnie każdego zakątka lasu, nawet z mniejszym potencjałem.',
      exampleDisplay: 'Pokazuje dodatkowe żółte i szare plakietki z prawdopodobieństwem 20% - 49%.',
      accentColor: AppColors.emeraldNeon,
    ),
    _RadarOptionMeta(
      id: 'rain_heatmap',
      icon: '🌧️',
      title: 'Mapa opadów (14 dni)',
      subtitle: 'Suma opadów z dwóch tygodni (Open-Meteo)',
      shortTag: 'Warstwa Open-Meteo',
      detailedExplanation:
          'Nakłada na mapę termiczną warstwę sumarycznych opadów deszczu z ostatnich dwóch tygodni, pobieraną z modelu satelitarnego Open-Meteo.',
      whyItMatters:
          'Grzyby potrzebują 15-25 mm skumulowanego deszczu oraz 2-5 dni ciepła po opadzie, aby rozwinęła się grzybnia. Warstwa precyzyjnie wskazuje, gdzie dokładnie spadł deszcz.',
      exampleDisplay: 'Fioletowe i niebieskie strefy oznaczają lasy z obfitym nawodnieniem gleby.',
      accentColor: AppColors.emeraldNeon,
    ),
    _RadarOptionMeta(
      id: 'live_clouds',
      icon: '📡',
      title: 'Chmury deszczowe na żywo',
      subtitle: 'Radar dopplerowski opadów w czasie rzeczywistym',
      shortTag: 'Radar dopplerowski',
      detailedExplanation:
          'Wyświetla dynamiczną warstwę radarową chmur i opadów w czasie rzeczywistym z sieci radarów RainViewer.',
      whyItMatters:
          'Bezpieczeństwo w terenie: pozwala sprawdzić, czy w stronę Twojego rejonu nie zbliża się gwałtowna burza lub ulewa.',
      exampleDisplay: 'Płynna animacja przemieszczania się komórek burzowych nad Polską.',
      accentColor: AppColors.emeraldNeon,
    ),
  ];

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
    final densityMode = ref.watch(
      mapScreenProvider.select((s) => s.radarDensityMode),
    );
    final minProbability = ref.watch(
      mapScreenProvider.select((s) => s.radarMinProbability),
    );

    final optionValues = [
      showMushroom,
      showTree,
      showLowProbability,
      showRainRadar,
      showLiveClouds,
    ];
    final optionCallbacks = [
      (bool v) => ref.read(mapScreenProvider.notifier).toggleRadarMushroomName(),
      (bool v) => ref.read(mapScreenProvider.notifier).toggleRadarTreeSpecies(),
      (bool v) => ref.read(mapScreenProvider.notifier).toggleLowProbabilityRadars(),
      (bool v) => ref.read(mapScreenProvider.notifier).toggleRainRadarLayer(),
      (bool v) => ref.read(mapScreenProvider.notifier).toggleLiveRadarClouds(),
    ];

    Mushroom? selectedMushroom;
    if (targetMushroomId != null) {
      for (final m in MushroomDatabase.allMushrooms) {
        if (m.id == targetMushroomId) {
          selectedMushroom = m;
          break;
        }
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header (Clean, minimal, no emoji salad)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Widok Plakietek Radaru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.1,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Dostosuj szczegółowość i cel radaru na mapie',
                        style: TextStyle(fontSize: 11, color: AppColors.textDim),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showTargetMushroomHelp(context),
                        tooltip: 'Jak działa radar?',
                        icon: const Icon(
                          Icons.help_outline_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Zamknij',
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppColors.textDim,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.borderLight, height: 16),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Live Preview Stage (Ambient HUD showcase)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C140F),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: AppColors.emeraldNeon,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.emeraldNeon,
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'PODGLĄD ZNACZNIKA NA MAPIE',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.emeraldNeon,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: MushroomGaugeBadge(
                              probability: 85,
                              mushroomName: selectedMushroom?.namePl.split(' ').first ?? 'Borowik',
                              speciesName: 'So',
                              ageYears: 65,
                              showMushroomName: showMushroom,
                              showTreeSpecies: showTree,
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tak będą wyglądać znaczniki w Twoim rejonie lasu',
                            style: TextStyle(fontSize: 10.5, color: AppColors.textDim),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 1: Target Mushroom (Sleek Native Picker Tile)
                    _buildTargetMushroomTile(
                      context,
                      ref,
                      selectedMushroom,
                      targetMushroomId,
                    ),
                    const SizedBox(height: 12),

                    // Section 2: Density Mode & Probability Threshold (Spatial NMS Controls)
                    _buildDensityAndThresholdSection(
                      context,
                      ref,
                      densityMode,
                      minProbability,
                    ),
                    const SizedBox(height: 12),

                    // Section 3: Grouped Inset Settings Container (Apple/Linear-style)
                    _buildGroupedSettings(
                      context,
                      optionValues,
                      optionCallbacks,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Done Button
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldDeep,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: AppColors.emeraldNeon.withValues(alpha: 0.55),
                      width: 1.0,
                    ),
                  ),
                ),
                child: const Text(
                  'Gotowe',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sleek Native Picker Tile for Target Mushroom (1 level of nesting, zero clutter).
  Widget _buildTargetMushroomTile(
    BuildContext context,
    WidgetRef ref,
    Mushroom? mushroom,
    String? currentId,
  ) {
    final hasTarget = mushroom != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasTarget
              ? AppColors.emeraldNeon.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final selectedId = await MushroomSearchSheet.show(
              context,
              currentTargetId: currentId,
            );
            if (selectedId != null) {
              if (selectedId == '__ALL__') {
                ref.read(mapScreenProvider.notifier).setTargetMushroom(null);
              } else {
                ref.read(mapScreenProvider.notifier).setTargetMushroom(selectedId);
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                if (hasTarget)
                  MushroomPhotoWidget(
                    assetPath: mushroom.photoAsset,
                    fallbackEmoji: mushroom.badge,
                    size: 38,
                    borderRadius: 10,
                    borderColor: AppColors.emeraldNeon.withValues(alpha: 0.5),
                  )
                else
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldNeon.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.emeraldNeon.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🎯', style: TextStyle(fontSize: 18)),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cel poszukiwań radaru',
                        style: TextStyle(
                          color: AppColors.textDim,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasTarget
                            ? mushroom.namePl
                            : 'Wszystkie gatunki (Tryb ogólny)',
                        style: TextStyle(
                          color: hasTarget ? AppColors.emeraldNeon : Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasTarget)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textDim),
                    tooltip: 'Resetuj cel',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      ref.read(mapScreenProvider.notifier).setTargetMushroom(null);
                    },
                  ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Unified Grouped Inset Container for all radar toggles (Apple/Linear-style).
  Widget _buildGroupedSettings(
    BuildContext context,
    List<bool> values,
    List<ValueChanged<bool>> callbacks,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < _options.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.8,
                indent: 58,
                endIndent: 14,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            _buildOptionItem(
              context: context,
              meta: _options[i],
              value: values[i],
              onToggle: callbacks[i],
            ),
          ],
        ],
      ),
    );
  }

  /// Clean, laconic option row without noisy individual borders or (i) buttons.
  Widget _buildOptionItem({
    required BuildContext context,
    required _RadarOptionMeta meta,
    required bool value,
    required ValueChanged<bool> onToggle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onToggle(!value),
        onLongPress: () => _showOptionInfoSheet(context, meta, value, onToggle),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Refined Leading Icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: value
                      ? AppColors.emeraldNeon.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: value
                        ? AppColors.emeraldNeon.withValues(alpha: 0.25)
                        : Colors.transparent,
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(meta.icon, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 12),

              // Title + Subtitle Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      meta.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDim,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Switch (Unified Emerald Neon)
              Switch.adaptive(
                value: value,
                onChanged: onToggle,
                activeThumbColor: AppColors.emeraldNeon,
                activeTrackColor: AppColors.emeraldNeon.withValues(alpha: 0.3),
                inactiveThumbColor: AppColors.textDim,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Interactive section for spatial density clustering mode and minimum probability threshold.
  Widget _buildDensityAndThresholdSection(
    BuildContext context,
    WidgetRef ref,
    RadarDensityMode currentDensity,
    int currentMinProb,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.emeraldNeon.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: AppColors.emeraldNeon.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: AppColors.emeraldNeon,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gęstość i czytelność radaru',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 1.5),
                    Text(
                      'Klastrowanie przestrzenne zapobiega nakładaniu się plakietek',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),

          // Subsection: Density Mode
          const Text(
            'LICZBA ZNACZNIKÓW NA EKRANIE',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textDim,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              for (final mode in RadarDensityMode.values) ...[
                Expanded(
                  child: _buildDensityModeButton(
                    label: mode.shortLabel,
                    badge: mode == RadarDensityMode.minimal
                        ? 'TOP 10'
                        : (mode == RadarDensityMode.balanced ? 'TOP 20' : 'Wszystkie'),
                    isSelected: currentDensity == mode,
                    onTap: () {
                      ref.read(mapScreenProvider.notifier).setRadarDensityMode(mode);
                    },
                  ),
                ),
                if (mode != RadarDensityMode.values.last) const SizedBox(width: 6),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // Subsection: Probability Threshold
          const Text(
            'MINIMALNY PRÓG SZANSY',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textDim,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              for (final prob in const [50, 70, 85]) ...[
                Expanded(
                  child: _buildProbThresholdButton(
                    percentage: prob,
                    tag: prob == 50 ? 'Zalecany' : (prob == 70 ? 'Pewne' : 'Elitarne'),
                    isSelected: currentMinProb == prob,
                    onTap: () {
                      ref.read(mapScreenProvider.notifier).setRadarMinProbability(prob);
                    },
                  ),
                ),
                if (prob != 85) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDensityModeButton({
    required String label,
    required String badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.emeraldNeon.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.emeraldNeon.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.emeraldNeon : Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              badge,
              style: TextStyle(
                fontSize: 9.5,
                color: isSelected ? AppColors.emeraldNeon.withValues(alpha: 0.8) : AppColors.textDim,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProbThresholdButton({
    required int percentage,
    required String tag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeColor = percentage >= 85
        ? AppColors.goldAmber
        : (percentage >= 70 ? AppColors.emeraldNeon : const Color(0xFF38BDF8));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Text(
              '≥ $percentage%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tag,
              style: TextStyle(
                fontSize: 9.5,
                color: isSelected ? activeColor.withValues(alpha: 0.8) : AppColors.textDim,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the rich modal info sheet explaining the feature in detail.
  void _showOptionInfoSheet(
    BuildContext context,
    _RadarOptionMeta meta,
    bool currentValue,
    ValueChanged<bool> onToggle,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: meta.accentColor.withValues(alpha: 0.4)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 30,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag Handle
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

                    // Icon & Title Header
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: meta.accentColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: meta.accentColor.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: meta.accentColor.withValues(alpha: 0.25),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(meta.icon, style: const TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meta.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: meta.accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  meta.shortTag,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: meta.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textDim),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Detailed Explanation Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.help_outline_rounded, size: 15, color: AppColors.textMuted),
                              SizedBox(width: 6),
                              Text(
                                'CO TO OZNACZA?',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            meta.detailedExplanation,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMain,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Text('👀', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    meta.exampleDisplay,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Foraging Pro-Tip Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.emeraldNeon.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('🌲', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 6),
                              Text(
                                'WSKAZÓWKA LEŚNA',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.emeraldNeon,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            meta.whyItMatters,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              onToggle(!currentValue);
                              Navigator.of(sheetContext).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: meta.accentColor,
                              side: BorderSide(color: meta.accentColor.withValues(alpha: 0.6)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              currentValue ? 'Wyłącz opcję' : 'Włącz opcję',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emeraldDeep,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Rozumiem',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Info helper for the Target Mushroom feature.
  void _showTargetMushroomHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.emeraldNeon.withValues(alpha: 0.4)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Row(
                  children: [
                    Text('🎯', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 10),
                    Text(
                      'Jak działa cel poszukiwań?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gdy wybierzesz konkretnego grzyba (np. Borowik szlachetny lub Kurka), algorytm radaru przestaje oceniać ogólny mikoklimat lasu, a zaczyna rygorystycznie badać wymagania wyłącznie tego gatunku:\n\n'
                  '• Wymagane gatunki drzew (mikoryza sosnowa, świerkowa, dębowa)\n'
                  '• Optymalny wiek lasu (np. starodrzew 60-95 lat dla borowika)\n'
                  '• Wymagana suma opadów deszczu z ostatnich 14 dni\n'
                  '• Sezonowość i tolerancja na przymrozki',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMain, height: 1.45),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldDeep,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Rozumiem', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
