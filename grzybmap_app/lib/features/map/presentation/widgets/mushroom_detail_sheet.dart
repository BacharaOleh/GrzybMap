import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mushroom_radar/domain/models.dart';
import '../../../parcel_inspector/data/bdl_parser.dart';
import 'mushroom_photo_widget.dart';

/// Modal bottom sheet presenting a comprehensive botanical and foraging dossier
/// for a mushroom species, featuring authentic photos, lookalike comparisons,
/// biotope requirements, and live match scoring for the selected forest parcel.
class MushroomDetailSheet extends StatelessWidget {
  final Mushroom mushroom;
  final MushroomMatchResult? matchResult;
  final ValueChanged<String>? onSetTargetMushroom;

  const MushroomDetailSheet({
    super.key,
    required this.mushroom,
    this.matchResult,
    this.onSetTargetMushroom,
  });

  /// Opens the detailed mushroom sheet.
  static Future<void> show(
    BuildContext context, {
    required Mushroom mushroom,
    MushroomMatchResult? matchResult,
    ValueChanged<String>? onSetTargetMushroom,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MushroomDetailSheet(
        mushroom: mushroom,
        matchResult: matchResult,
        onSetTargetMushroom: onSetTargetMushroom,
      ),
    );
  }

  static String _formatSeason(List<int> months) {
    if (months.isEmpty) return 'Brak danych';
    const monthNames = [
      '', 'Sty', 'Lut', 'Mar', 'Kwi', 'Maj', 'Cze',
      'Lip', 'Sie', 'Wrz', 'Paź', 'Lis', 'Gru'
    ];
    if (months.length == 1) return monthNames[months.first];
    final sorted = List<int>.from(months)..sort();
    return '${monthNames[sorted.first]} – ${monthNames[sorted.last]}';
  }

  static String _resolveTreeName(String code) {
    final clean = code.trim().toUpperCase();
    final dictEntry = BdlParser.speciesDict[clean];
    if (dictEntry != null) {
      final icon = dictEntry['icon'] ?? '🌲';
      final pl = dictEntry['pl'] ?? clean;
      return '$icon $pl ($clean)';
    }
    return '🌲 Drzewo ($clean)';
  }

  @override
  Widget build(BuildContext context) {
    final m = mushroom;
    final lookalike = m.lookalike;
    final hasLethalLookalike = lookalike != null && lookalike.isLethal;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
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
            // Top drag handle
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

            // Header Row: Names + Close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.namePl,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${m.latin} • ${m.nameRu}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textDim),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.borderLight, height: 10),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Primary Botanical Photo
                    Stack(
                      children: [
                        MushroomPhotoWidget(
                          assetPath: m.photoAsset,
                          fallbackEmoji: m.badge,
                          width: double.infinity,
                          height: 200,
                          borderRadius: 18,
                          borderColor: hasLethalLookalike
                              ? AppColors.danger.withValues(alpha: 0.6)
                              : m.edibilityColor.withValues(alpha: 0.4),
                          borderWidth: 1.5,
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('📷', style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 4),
                                Text(
                                  m.badge.isNotEmpty ? m.badge : 'Atlas botaniczny',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: m.edibilityColor,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: m.edibilityColor.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(
                              m.edibility,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Live Match Banner for this Forest Parcel
                    if (matchResult != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: matchResult!.chanceColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: matchResult!.chanceColor.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: matchResult!.chanceColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${matchResult!.probabilityPercent}%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Szansa w tym wydzieleniu: ${matchResult!.chanceCategory}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: matchResult!.chanceColor,
                                    ),
                                  ),
                                  if (matchResult!.positiveReasons.isNotEmpty)
                                    Text(
                                      matchResult!.positiveReasons.take(2).join(' • '),
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textMain,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Quick Specs Bar (Season, Rain, Forest Age)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSpecItem(
                              icon: '🗓️',
                              label: 'SEZON',
                              value: _formatSeason(m.seasonMonths),
                            ),
                          ),
                          Container(width: 1, height: 28, color: AppColors.borderLight),
                          Expanded(
                            child: _buildSpecItem(
                              icon: '💧',
                              label: 'OPADY 14D',
                              value: 'min ${m.minRainfall14d.toStringAsFixed(0)} mm',
                            ),
                          ),
                          Container(width: 1, height: 28, color: AppColors.borderLight),
                          Expanded(
                            child: _buildSpecItem(
                              icon: '🌲',
                              label: 'WIEK LASU',
                              value: '${m.preferredAge.idealMin}-${m.preferredAge.idealMax} lat',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Detailed Botanical Description
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('📖', style: TextStyle(fontSize: 15)),
                              SizedBox(width: 6),
                              Text(
                                'OPIS I BIOLOGIA GATUNKU',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            m.descriptionPl,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMain,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Mycologist Tips (Where to look)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.emeraldNeon.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('🌲', style: TextStyle(fontSize: 15)),
                              SizedBox(width: 6),
                              Text(
                                'WSKAZÓWKI GRZYBIARZA (GDZIE SZUKAĆ?)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.emeraldNeon,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            m.tipsPl,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMain,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Mycorrhizal Trees
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('🌳', style: TextStyle(fontSize: 15)),
                              SizedBox(width: 6),
                              Text(
                                'DRZEWA MIKORYZOWE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: m.preferredTrees.map((code) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  _resolveTreeName(code),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Toxic Lookalike Safety Section
                    if (lookalike != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: lookalike.isLethal
                              ? const Color(0xFF261014)
                              : const Color(0xFF241A10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: lookalike.isLethal
                                ? AppColors.danger
                                : AppColors.goldAmber,
                            width: 1.4,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  lookalike.isLethal
                                      ? Icons.dangerous_rounded
                                      : Icons.warning_amber_rounded,
                                  color: lookalike.isLethal
                                      ? AppColors.danger
                                      : AppColors.goldAmber,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lookalike.isLethal
                                        ? 'ŚMIERTELNIE TRUJĄCY SOBOWTÓR'
                                        : 'UWAGA NA PODOBNY GATUNEK',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: lookalike.isLethal
                                          ? AppColors.danger
                                          : AppColors.goldAmber,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Side by side or lookalike photo
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MushroomPhotoWidget(
                                  assetPath: lookalike.photoAsset,
                                  size: 64,
                                  borderRadius: 12,
                                  borderColor: lookalike.isLethal
                                      ? AppColors.danger
                                      : AppColors.goldAmber,
                                  borderWidth: 1.5,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lookalike.namePl,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        lookalike.latin,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.textDim,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lookalike.warningPl,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.white70,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Comparison features
                            if (lookalike.features.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Divider(color: Colors.white12, height: 1),
                              const SizedBox(height: 8),
                              ...lookalike.features.map((f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${f.featureName}: ',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${f.edibleCharacteristic} (ZAMIAST: ${f.lookalikeCharacteristic})',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: f.isCritical ? AppColors.danger : AppColors.goldAmber,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10261A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.emeraldLight.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.emeraldNeon, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Bezpieczny gatunek — brak śmiertelnie trujących sobowtórów w Polsce.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.emeraldNeon,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Actions (Set as radar target & Close)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
              child: Row(
                children: [
                  if (onSetTargetMushroom != null)
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onSetTargetMushroom!(m.id);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🎯 Ustawiono cel radaru: ${m.namePl}'),
                              backgroundColor: AppColors.emeraldDeep,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emeraldDeep,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.emeraldNeon, width: 0.9),
                          ),
                        ),
                        icon: const Icon(Icons.radar_rounded, size: 18),
                        label: const Text(
                          'Ustaw jako cel radaru',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  if (onSetTargetMushroom != null) const SizedBox(width: 10),
                  Expanded(
                    flex: onSetTargetMushroom != null ? 2 : 1,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.borderLight),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Zamknij', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem({
    required String icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textDim,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
