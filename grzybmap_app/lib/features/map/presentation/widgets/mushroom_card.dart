import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mushroom_radar/domain/models.dart';

/// Card widget representing a single mushroom species evaluated
/// by the mushroom radar match engine.
class MushroomCard extends StatelessWidget {
  final MushroomMatchResult result;

  const MushroomCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final m = result.mushroom;
    final hasLookalike = m.lookalike != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasLookalike && m.lookalike!.isLethal
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & Probability
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.namePl,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m.latin} • ${m.edibility}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${result.probabilityPercent}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: result.chanceColor,
                    ),
                  ),
                  Text(
                    result.chanceCategory,
                    style: TextStyle(
                      fontSize: 9,
                      color: result.chanceColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: result.probabilityPercent / 100.0,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(result.chanceColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),

          // Positive reasons (why this score)
          if (result.positiveReasons.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: result.positiveReasons
                  .map((r) => _ReasonChip(text: r, isPositive: true))
                  .toList(),
            ),
          ],

          // Negative reasons
          if (result.negativeReasons.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: result.negativeReasons
                  .map((r) => _ReasonChip(text: r, isPositive: false))
                  .toList(),
            ),
          ],

          // Tips for finding this mushroom
          if (m.tipsPl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.emeraldNeon.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.tipsPl,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // DANGER: Lookalike warning
          if (hasLookalike) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: m.lookalike!.isLethal
                    ? AppColors.danger.withValues(alpha: 0.1)
                    : AppColors.goldAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: m.lookalike!.isLethal
                      ? AppColors.danger.withValues(alpha: 0.3)
                      : AppColors.goldAmber.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        m.lookalike!.isLethal ? Icons.dangerous : Icons.warning_amber,
                        size: 14,
                        color: m.lookalike!.isLethal ? AppColors.danger : AppColors.goldAmber,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          m.lookalike!.isLethal
                              ? '⚠️ NIEBEZPIECZNY SOBOWTÓR!'
                              : '⚠️ Podobny gatunek:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: m.lookalike!.isLethal ? AppColors.danger : AppColors.goldAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${m.lookalike!.namePl} (${m.lookalike!.latin})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.lookalike!.warningPl,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPositive
            ? AppColors.emeraldNeon.withValues(alpha: 0.08)
            : AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${isPositive ? "✓" : "✗"} $text',
        style: TextStyle(
          fontSize: 10,
          color: isPositive ? AppColors.emeraldNeon : AppColors.danger,
        ),
      ),
    );
  }
}
