import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/map_screen_controller.dart';
import '../../../mushroom_radar/data/mushroom_database.dart';
import '../../../mushroom_radar/domain/models.dart';
import 'mushroom_gauge_badge.dart';
import 'mushroom_photo_widget.dart';
import 'mushroom_search_sheet.dart';

/// Metadata model for each radar setting option with detailed mycological
/// explanations and practical in-field tips hidden behind an info button.
class _RadarOptionMeta {
  final String id;
  final String icon;
  final String title;
  final String shortTag;
  final String detailedExplanation;
  final String whyItMatters;
  final String exampleDisplay;
  final Color accentColor;

  const _RadarOptionMeta({
    required this.id,
    required this.icon,
    required this.title,
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
      shortTag: 'Dane BDL',
      detailedExplanation:
          'Wyświetla oficjalny skrót dominującego gatunku drzewa oraz wiek drzewostanu pobrany z Banku Danych o Lasach (BDL).',
      whyItMatters:
          'Klucz do sukcesu: prawdziwki i borowiki preferują starodrzew sosnowy i dębowy (50-90 lat), natomiast maślaki rosną w młodnikach sosnowych (do 20 lat).',
      exampleDisplay: 'Plakietka wyświetla: „🌲 So 65l” (Sosna 65 lat) lub „Db 80l” (Dąb 80 lat).',
      accentColor: Color(0xFF34D399),
    ),
    _RadarOptionMeta(
      id: 'low_probability',
      icon: '🔍',
      title: 'Miejsca o niskiej szansie (< 50%)',
      shortTag: 'Czułość radaru',
      detailedExplanation:
          'Odkrywa na mapie sektory leśne, gdzie szansa na zbiór wynosi poniżej 50%. Domyślnie filtr jest wyłączony, aby mapa była czytelna i skupiona na najlepszych miejscówkach.',
      whyItMatters:
          'Przydatne podczas suszy lub poza szczytem sezonu, kiedy zależy Ci na zbadaniu absolutnie każdego zakątka lasu, nawet z mniejszym potencjałem.',
      exampleDisplay: 'Pokazuje dodatkowe żółte i szare plakietki z prawdopodobieństwem 20% - 49%.',
      accentColor: AppColors.goldAmber,
    ),
    _RadarOptionMeta(
      id: 'rain_heatmap',
      icon: '🌧️',
      title: 'Mapa opadów (14 dni)',
      shortTag: 'Warstwa Open-Meteo',
      detailedExplanation:
          'Nakłada na mapę termiczną warstwę sumarycznych opadów deszczu z ostatnich dwóch tygodni, pobieraną z modelu satelitarnego Open-Meteo.',
      whyItMatters:
          'Grzyby potrzebują 15-25 mm skumulowanego deszczu oraz 2-5 dni ciepła po opadzie, aby rozwinęła się grzybnia. Warstwa precyzyjnie wskazuje, gdzie dokładnie spadł deszcz.',
      exampleDisplay: 'Fioletowe i niebieskie strefy oznaczają lasy z obfitym nawodnieniem gleby.',
      accentColor: AppColors.skyBlue,
    ),
    _RadarOptionMeta(
      id: 'live_clouds',
      icon: '📡',
      title: 'Chmury deszczowe na żywo',
      shortTag: 'Radar dopplerowski',
      detailedExplanation:
          'Wyświetla dynamiczną warstwę radarową chmur i opadów w czasie rzeczywistym z sieci radarów RainViewer.',
      whyItMatters:
          'Bezpieczeństwo w terenie: pozwala sprawdzić, czy w stronę Twojego rejonu nie zbliża się gwałtowna burza lub ulewa.',
      exampleDisplay: 'Płynna animacja przemieszczania się komórek burzowych nad Polską.',
      accentColor: Color(0xFF818CF8),
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

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.emeraldNeon.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text('⚙️', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Widok Plakietek Radaru',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Text(
                            'Dostosuj szczegółowość i cel radaru na mapie',
                            style: TextStyle(fontSize: 11, color: AppColors.textDim),
                          ),
                        ],
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
            ),

            const Divider(color: AppColors.borderLight, height: 16),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Live Preview Card (Tactical HUD)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1A13),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.emeraldNeon.withValues(alpha: 0.25),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emeraldNeon.withValues(alpha: 0.05),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.emeraldNeon,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.emeraldNeon,
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'PODGLĄD NA ŻYWO NA MAPIE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.emeraldNeon,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
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
                          const SizedBox(height: 6),
                          const Text(
                            'Tak będą wyglądać znaczniki w Twoim rejonie lasu',
                            style: TextStyle(fontSize: 10.5, color: AppColors.textDim),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 1: Target Mushroom (With Search)
                    _buildTargetMushroomCard(
                      context,
                      ref,
                      selectedMushroom,
                      targetMushroomId,
                    ),
                    const SizedBox(height: 12),

                    // Section 2: Clean Laconic Option Toggles
                    _buildOptionRow(
                      context: context,
                      meta: _options[0], // Mushroom name
                      value: showMushroom,
                      onToggle: (val) => ref
                          .read(mapScreenProvider.notifier)
                          .toggleRadarMushroomName(),
                    ),
                    const SizedBox(height: 8),

                    _buildOptionRow(
                      context: context,
                      meta: _options[1], // Tree species & age
                      value: showTree,
                      onToggle: (val) => ref
                          .read(mapScreenProvider.notifier)
                          .toggleRadarTreeSpecies(),
                    ),
                    const SizedBox(height: 8),

                    _buildOptionRow(
                      context: context,
                      meta: _options[2], // Low probability
                      value: showLowProbability,
                      onToggle: (val) => ref
                          .read(mapScreenProvider.notifier)
                          .toggleLowProbabilityRadars(),
                    ),
                    const SizedBox(height: 8),

                    _buildOptionRow(
                      context: context,
                      meta: _options[3], // Rain heatmap
                      value: showRainRadar,
                      onToggle: (val) => ref
                          .read(mapScreenProvider.notifier)
                          .toggleRainRadarLayer(),
                    ),
                    const SizedBox(height: 8),

                    _buildOptionRow(
                      context: context,
                      meta: _options[4], // Live radar clouds
                      value: showLiveClouds,
                      onToggle: (val) => ref
                          .read(mapScreenProvider.notifier)
                          .toggleLiveRadarClouds(),
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
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 4,
                  shadowColor: AppColors.emeraldDeep.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.emeraldNeon, width: 0.9),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Zastosuj i zamknij',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Target mushroom card with clear search trigger and active target display.
  Widget _buildTargetMushroomCard(
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
              ? AppColors.emeraldNeon.withValues(alpha: 0.5)
              : AppColors.border,
          width: hasTarget ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of card
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('🎯', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 8),
                    Text(
                      'Cel poszukiwań radaru',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                _buildInfoIconButton(
                  context: context,
                  onTap: () => _showTargetMushroomHelp(context),
                  tooltip: 'O celu poszukiwań',
                ),
              ],
            ),
          ),

          // Interactive Selector Card
          InkWell(
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
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  if (hasTarget)
                    MushroomPhotoWidget(
                      assetPath: mushroom.photoAsset,
                      fallbackEmoji: mushroom.badge,
                      size: 38,
                      borderRadius: 10,
                      borderColor: AppColors.emeraldNeon.withValues(alpha: 0.6),
                    )
                  else
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.goldAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.goldAmber.withValues(alpha: 0.3)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('✨', style: TextStyle(fontSize: 18)),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasTarget
                              ? mushroom.namePl
                              : 'Wszystkie gatunki (Tryb ogólny)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasTarget
                              ? '${mushroom.latin} • 🌲 ${mushroom.preferredTrees.join(", ")}'
                              : 'Kliknij, aby wyszukać i wybrać konkretnego grzyba',
                          style: const TextStyle(
                            color: AppColors.textDim,
                            fontSize: 10.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (hasTarget)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                      tooltip: 'Wróć do wszystkich gatunków',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        ref.read(mapScreenProvider.notifier).setTargetMushroom(null);
                      },
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldNeon.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emeraldNeon.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded, size: 14, color: AppColors.emeraldNeon),
                        SizedBox(width: 4),
                        Text(
                          'Szukaj',
                          style: TextStyle(
                            color: AppColors.emeraldNeon,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact, laconic option row without noisy subtitles.
  /// Subtitle explanations are hidden behind the aesthetic info button [ ℹ️ ].
  Widget _buildOptionRow({
    required BuildContext context,
    required _RadarOptionMeta meta,
    required bool value,
    required ValueChanged<bool> onToggle,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: value
            ? AppColors.surface.withValues(alpha: 0.95)
            : AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? meta.accentColor.withValues(alpha: 0.4)
              : AppColors.borderLight,
          width: value ? 1.0 : 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => onToggle(!value),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: value
                        ? meta.accentColor.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: value
                          ? meta.accentColor.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(meta.icon, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),

                // Title
                Expanded(
                  child: Text(
                    meta.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Info Icon Button (Pops up rich explanation dialog)
                _buildInfoIconButton(
                  context: context,
                  onTap: () => _showOptionInfoSheet(context, meta, value, onToggle),
                  tooltip: 'Szczegóły opcji ${meta.title}',
                ),
                const SizedBox(width: 4),

                // Modern Switch
                Switch.adaptive(
                  value: value,
                  onChanged: onToggle,
                  activeThumbColor: meta.accentColor,
                  activeTrackColor: meta.accentColor.withValues(alpha: 0.25),
                  inactiveThumbColor: AppColors.textDim,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Aesthetic info icon button [ ℹ️ ] with smooth touch target.
  Widget _buildInfoIconButton({
    required BuildContext context,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: AppColors.textMuted,
          ),
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
