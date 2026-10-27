import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Interactive map badge representing a forest parcel's mushroom potential.
/// Features a minimalist hollow mushroom silhouette that fills up vertically
/// as a gauge, accompanied by percentage. By default it is ultra-minimalist
/// showing only the gauge and score, with optional mushroom name and forest type
/// configurable via long-press.
class MushroomGaugeBadge extends StatelessWidget {
  final int probability; // 0..100
  final String mushroomName; // e.g. Borowik, Kurka, Podgrzybek
  final String speciesName; // e.g. So, Jd, Db, Brz
  final int ageYears;
  final bool showMushroomName;
  final bool showTreeSpecies;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MushroomGaugeBadge({
    super.key,
    required this.probability,
    required this.mushroomName,
    required this.speciesName,
    required this.ageYears,
    this.showMushroomName = false,
    this.showTreeSpecies = false,
    required this.onTap,
    this.onLongPress,
  });

  Color _getScoreColor() {
    if (probability >= 65) return AppColors.emeraldNeon;
    if (probability >= 35) return AppColors.amberWarn;
    return const Color(0xFF9CA3AF); // slate grey
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _getScoreColor();
    final fillRatio = (probability / 100.0).clamp(0.0, 1.0);
    final isTop = probability >= 65;

    final hasAdditionalText = showMushroomName || showTreeSpecies;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: hasAdditionalText ? 7.0 : 6.0,
          vertical: 3.5,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTop
                ? scoreColor.withValues(alpha: 0.85)
                : AppColors.border,
            width: isTop ? 1.4 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 2.5,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Custom Mushroom Vertical Gauge (Hardware-accelerated)
            CustomPaint(
              size: const Size(13, 17),
              painter: MushroomGaugePainter(
                fillPercent: fillRatio,
                fillColor: scoreColor,
                outlineColor: isTop ? Colors.white : scoreColor,
              ),
            ),
            const SizedBox(width: 4),

            // Probability Percentage
            Text(
              '$probability%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: scoreColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),

            // Optional: Mushroom Name
            if (showMushroomName) ...[
              const SizedBox(width: 4),
              _buildDot(),
              const SizedBox(width: 4),
              Text(
                mushroomName,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],

            // Optional: Tree Species & Age
            if (showTreeSpecies) ...[
              const SizedBox(width: 4),
              _buildDot(),
              const SizedBox(width: 4),
              Text(
                '$speciesName ${ageYears}l',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 2.5,
      height: 2.5,
      decoration: const BoxDecoration(
        color: AppColors.textDim,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// CustomPainter that renders a resolution-independent vector mushroom
/// with a vertical filling level inside its silhouette.
/// Uses a hardware-accelerated linear gradient without expensive clipPath stencil operations.
class MushroomGaugePainter extends CustomPainter {
  final double fillPercent; // 0.0 to 1.0
  final Color fillColor;
  final Color outlineColor;

  const MushroomGaugePainter({
    required this.fillPercent,
    required this.fillColor,
    required this.outlineColor,
  });

  Path _createMushroomPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // Cap geometry
    final capBottom = h * 0.58;
    final capWidth = w * 0.98;
    final capLeft = (w - capWidth) / 2;
    final capRight = capLeft + capWidth;

    // Start at bottom left of cap
    path.moveTo(capLeft, capBottom);

    // Dome curve to top center
    path.cubicTo(
      capLeft,
      h * 0.05,
      capRight,
      h * 0.05,
      capRight,
      capBottom,
    );

    // Stem geometry (connecting smoothly to cap bottom)
    final stemLeft = w * 0.34;
    final stemRight = w * 0.66;
    final stemBottom = h * 0.96;

    path.lineTo(stemRight, capBottom);
    path.cubicTo(
      stemRight + w * 0.06,
      h * 0.78,
      stemRight,
      stemBottom,
      w * 0.5,
      stemBottom,
    );
    path.cubicTo(
      stemLeft,
      stemBottom,
      stemLeft - w * 0.06,
      h * 0.78,
      stemLeft,
      capBottom,
    );
    path.close();

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final mushroomPath = _createMushroomPath(size);

    // 1. Draw track + gauge fill in a single pass with hardware-accelerated linear gradient (no clipPath!)
    final fillPaint = Paint()..style = PaintingStyle.fill;
    if (fillPercent <= 0.0) {
      fillPaint.color = Colors.white.withValues(alpha: 0.12);
    } else if (fillPercent >= 1.0) {
      fillPaint.color = fillColor;
    } else {
      fillPaint.shader = ui.Gradient.linear(
        Offset(0, size.height),
        Offset.zero,
        [
          fillColor,
          fillColor,
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.12),
        ],
        [0.0, fillPercent, fillPercent, 1.0],
      );
    }
    canvas.drawPath(mushroomPath, fillPaint);

    // 2. Outer vector outline
    final strokePaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(mushroomPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant MushroomGaugePainter oldDelegate) {
    return oldDelegate.fillPercent != fillPercent ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.outlineColor != outlineColor;
  }
}
