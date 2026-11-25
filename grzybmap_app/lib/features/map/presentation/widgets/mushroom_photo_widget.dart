import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Resilient and aesthetic photo widget for mushroom species and user-attached photos.
///
/// Handles custom user photos (base64 or memory bytes) and asset loading gracefully
/// with beautiful botanical fallbacks, custom sizes, and danger/edibility borders.
class MushroomPhotoWidget extends StatelessWidget {
  final String? assetPath;
  final String? base64Data;
  final Uint8List? memoryBytes;
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
    this.base64Data,
    this.memoryBytes,
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

  Uint8List? _resolveBytes() {
    if (memoryBytes != null && memoryBytes!.isNotEmpty) {
      return memoryBytes;
    }
    if (base64Data != null && base64Data!.trim().isNotEmpty) {
      try {
        String clean = base64Data!.trim();
        if (clean.contains(',')) {
          clean = clean.split(',').last;
        }
        return base64Decode(clean);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppColors.borderLight;
    final w = width ?? size;
    final h = height ?? size;
    final bytes = _resolveBytes();

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
        child: bytes != null
            ? Image.memory(
                bytes,
                width: w,
                height: h,
                fit: fit,
                errorBuilder: (context, error, stackTrace) => _buildAssetOrFallback(w, h),
              )
            : _buildAssetOrFallback(w, h),
      ),
    );
  }

  Widget _buildAssetOrFallback(double w, double h) {
    if (assetPath != null && assetPath!.isNotEmpty) {
      return Image.asset(
        assetPath!,
        width: w,
        height: h,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(w, h),
      );
    }
    return _buildFallback(w, h);
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
