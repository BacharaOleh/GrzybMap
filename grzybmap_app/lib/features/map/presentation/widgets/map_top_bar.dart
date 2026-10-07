import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Top bar with brand indicator and base map layer switcher button.
class MapTopBar extends StatelessWidget {
  final String activeLayerLabel;
  final VoidCallback onCycleLayer;
  final VoidCallback? onOpenAbout;

  const MapTopBar({
    super.key,
    required this.activeLayerLabel,
    required this.onCycleLayer,
    this.onOpenAbout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Brand Pill (tappable to view About / Rules screen)
            GestureDetector(
              onTap: onOpenAbout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Text('🍄', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text(
                      'GrzybMap PL',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.info_outline, size: 14, color: AppColors.textDim),
                  ],
                ),
              ),
            ),

            // Layer Switcher Button with current layer label
            GestureDetector(
              onTap: onCycleLayer,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.layers_outlined,
                      size: 16,
                      color: AppColors.emeraldNeon,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      activeLayerLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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
}
