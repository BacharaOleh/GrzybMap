import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mushroom_radar/domain/models.dart';
import 'mushroom_photo_widget.dart';

/// Card widget representing a single mushroom species evaluated
/// by the mushroom radar match engine.
///
/// Supports interactive expansion to display harvesting tips (U8),
/// biotope description, full scoring factors, and prominent warnings
/// for toxic lookalikes (U7).
class MushroomCard extends StatefulWidget {
  final MushroomMatchResult result;
  final bool initiallyExpanded;

  const MushroomCard({
    super.key,
    required this.result,
    this.initiallyExpanded = false,
  });

  @override
  State<MushroomCard> createState() => _MushroomCardState();
}

class _MushroomCardState extends State<MushroomCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final m = result.mushroom;
    final lookalike = m.lookalike;
    final hasLethalLookalike = lookalike != null && lookalike.isLethal;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasLethalLookalike
              ? AppColors.danger.withValues(alpha: 0.45)
              : (lookalike != null
                  ? AppColors.goldAmber.withValues(alpha: 0.35)
                  : AppColors.borderLight),
          width: hasLethalLookalike ? 1.5 : 1.0,
        ),
        boxShadow: hasLethalLookalike
            ? [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _toggleExpanded,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name, Latin, Edibility, Badge & Probability
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MushroomPhotoWidget(
                      assetPath: m.photoAsset,
                      size: 48,
                      borderRadius: 12,
                      borderColor: m.edibilityColor.withValues(alpha: 0.45),
                      borderWidth: 1.5,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  m.namePl,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                m.latin,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textDim,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: m.edibilityColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  m.edibility,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: m.edibilityColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (m.badge.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '🎖️ ${m.badge}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.goldAmber,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${result.probabilityPercent}%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: result.chanceColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: result.chanceColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            result.chanceCategory,
                            style: TextStyle(
                              fontSize: 9,
                              color: result.chanceColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Match Probability Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.probabilityPercent / 100.0,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(result.chanceColor),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 10),

                // --- U7: PROMINENT LOOKALIKE BADGE (COMPACT / SUMMARY) ---
                if (lookalike != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: lookalike.isLethal
                          ? AppColors.danger.withValues(alpha: 0.14)
                          : AppColors.goldAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: lookalike.isLethal
                            ? AppColors.danger.withValues(alpha: 0.5)
                            : AppColors.goldAmber.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          lookalike.isLethal
                              ? Icons.dangerous_rounded
                              : Icons.warning_amber_rounded,
                          size: 16,
                          color: lookalike.isLethal
                              ? AppColors.danger
                              : AppColors.goldAmber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lookalike.isLethal
                                ? 'ŚMIERTELNIE TRUJĄCY SOBOWTÓR: ${lookalike.namePl}'
                                : 'Uwaga na podobny gatunek: ${lookalike.namePl}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: lookalike.isLethal
                                  ? AppColors.danger
                                  : AppColors.goldAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Quick scoring chips (Summary mode: top 2-3 positive reasons)
                if (!_isExpanded && result.positiveReasons.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: result.positiveReasons
                        .take(2)
                        .map((r) => _ReasonChip(text: r, isPositive: true))
                        .toList(),
                  ),
                ],

                // --- EXPANDED DETAILS (U8 TIPS + BIOTOPE + DETAILED WARNING) ---
                if (_isExpanded) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // All Positive reasons
                        if (result.positiveReasons.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: result.positiveReasons
                                .map((r) => _ReasonChip(text: r, isPositive: true))
                                .toList(),
                          ),
                        ],

                        // All Negative reasons
                        if (result.negativeReasons.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: result.negativeReasons
                                .map((r) => _ReasonChip(text: r, isPositive: false))
                                .toList(),
                          ),
                        ],

                        // U8: Harvesting tips
                        if (m.tipsPl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldNeon.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.emeraldNeon.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text('💡', style: TextStyle(fontSize: 13)),
                                    SizedBox(width: 6),
                                    Text(
                                      'WSKAZÓWKI ZBIORU',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.emeraldNeon,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m.tipsPl,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMain,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Biotope & Mycorrhiza description
                        if (m.descriptionPl.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text('🌲', style: TextStyle(fontSize: 13)),
                                    SizedBox(width: 6),
                                    Text(
                                      'SIEDLISKO I MIKORYZA',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMuted,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m.descriptionPl,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // U7: Full In-Depth Lookalike Warning & Side-by-Side Comparison Box
                        if (lookalike != null) ...[
                          const SizedBox(height: 10),
                          _LookalikeComparisonSection(
                            mushroom: m,
                            lookalike: lookalike,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Expand / Collapse Footer button
                const SizedBox(height: 8),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Zwiń szczegóły' : 'Wskazówki i szczegóły',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emeraldNeon,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: AppColors.emeraldNeon,
                      ),
                    ],
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

class _ReasonChip extends StatelessWidget {
  final String text;
  final bool isPositive;

  const _ReasonChip({
    required this.text,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: isPositive
            ? AppColors.emeraldNeon.withValues(alpha: 0.08)
            : AppColors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPositive
              ? AppColors.emeraldNeon.withValues(alpha: 0.25)
              : AppColors.danger.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        '${isPositive ? "✓" : "✗"} $text',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isPositive ? AppColors.emeraldNeon : AppColors.danger,
        ),
      ),
    );
  }
}

class _LookalikeComparisonSection extends StatelessWidget {
  final Mushroom mushroom;
  final MushroomLookalike lookalike;

  const _LookalikeComparisonSection({
    required this.mushroom,
    required this.lookalike,
  });

  @override
  Widget build(BuildContext context) {
    final isLethal = lookalike.isLethal;
    final primaryColor = isLethal ? AppColors.danger : AppColors.goldAmber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLethal
            ? AppColors.danger.withValues(alpha: 0.12)
            : AppColors.goldAmber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: isLethal ? 0.7 : 0.4),
          width: isLethal ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            children: [
              Icon(
                isLethal ? Icons.dangerous_rounded : Icons.warning_amber_rounded,
                size: 18,
                color: primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isLethal
                      ? '🚨 ZAGROŻENIE ŻYCIA — SOBOWTÓR'
                      : '⚠️ PORÓWNAJ Z SOBOWTÓREM (GATUNEK NIEJADALNY)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Side-by-Side Photo Comparison
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Edible Mushroom Side
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.emeraldNeon.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldNeon.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'JADALNY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emeraldNeon,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      MushroomPhotoWidget(
                        assetPath: mushroom.photoAsset,
                        size: 90,
                        borderRadius: 8,
                        borderColor: AppColors.emeraldNeon.withValues(alpha: 0.6),
                        borderWidth: 1.5,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mushroom.namePl,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Lookalike Side
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isLethal ? 'ŚMIERTELNY' : 'TRUJĄCY / NIEJADALNY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      MushroomPhotoWidget(
                        assetPath: lookalike.photoAsset,
                        fallbackEmoji: '☠️',
                        size: 90,
                        borderRadius: 8,
                        borderColor: primaryColor.withValues(alpha: 0.7),
                        borderWidth: 1.5,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        lookalike.namePl,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Key Anatomical Checklist Table
          if (lookalike.features.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'KLUCZOWE RÓŻNICE ANATOMICZNE:',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Colors.white70,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            ...lookalike.features.map((f) => _FeatureRow(feature: f)),
          ],

          // Warning description
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: primaryColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lookalike.warningPl,
                    style: TextStyle(
                      fontSize: 11,
                      color: isLethal ? const Color(0xFFFCA5A5) : AppColors.textMain,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final LookalikeFeature feature;

  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF161F18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: feature.isCritical
              ? AppColors.danger.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🔍 ${feature.featureName}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (feature.isCritical) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'KRYTYCZNE',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✓ ', style: TextStyle(color: AppColors.emeraldNeon, fontSize: 11, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  feature.edibleCharacteristic,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.emeraldNeon, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✗ ', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  feature.lookalikeCharacteristic,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFFFCA5A5), height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
