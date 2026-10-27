import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Resilient and aesthetic photo widget for mushroom species and their lookalikes.
///
/// Handles asset loading gracefully with beautiful botanical fallbacks,
/// custom sizes, and danger/edibility borders.
class MushroomPhotoWidget extends StatelessWidget {
  final String? assetPath;
  final String fallbackEmoji;
  final double size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final BoxShadow? glowShadow;

  const MushroomPhotoWidget({
    super.key,
    required this.assetPath,
    this.fallbackEmoji = '🍄',
    this.size = 48.0,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 12.0,
    this.borderColor,
    this.borderWidth = 1.0,
    this.glowShadow,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppColors.borderLight;
    final w = width ?? size;
    final h = height ?? size;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFF131D16),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
        boxShadow: glowShadow != null ? [glowShadow!] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - borderWidth),
        child: assetPath != null && assetPath!.isNotEmpty
            ? Image.asset(
                assetPath!,
                width: w,
                height: h,
                fit: fit,
                errorBuilder: (context, error, stackTrace) => _buildFallback(w, h),
              )
            : _buildFallback(w, h),
      ),
    );
  }

  Widget _buildFallback(double w, double h) {
    final minDim = w.isFinite && h.isFinite ? (w < h ? w : h) : 48.0;
    return Container(
      color: const Color(0xFF142018),
      child: Center(
        child: Icon(
          Icons.spa_rounded,
          color: AppColors.emeraldLight.withValues(alpha: 0.5),
          size: minDim * 0.45,
        ),
      ),
    );
  }
}
