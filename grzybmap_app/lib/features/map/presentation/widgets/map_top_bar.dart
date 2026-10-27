import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../forest_search/domain/models.dart';
import '../../../forest_search/presentation/widgets/forest_search_bar.dart';

/// Clean, floating top bar for the map screen.
/// Features the brand info button and Nominatim/BDL forestry search capsule.
/// Underneath the search bar is completely clean and empty by default.
class MapTopBar extends StatelessWidget {
  final VoidCallback? onOpenAbout;
  final bool isOfflineMode;
  final VoidCallback? onOpenOfflineAreas;
  final void Function(ForestSearchResult place) onSelectPlace;

  const MapTopBar({
    super.key,
    this.onOpenAbout,
    this.isOfflineMode = false,
    this.onOpenOfflineAreas,
    required this.onSelectPlace,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Full-width search bar without distracting app badge
            ForestSearchBar(
              onSelectPlace: onSelectPlace,
            ),

            // Optional: Offline Mode status badge if active
            if (isOfflineMode) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onOpenOfflineAreas,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F291E).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                AppColors.emeraldLight.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emeraldDeep.withValues(alpha: 0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.emeraldLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Tryb offline • Dane z pamięci telefonu (BDL)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Text(
                            'Zarządzaj ➔',
                            style: TextStyle(
                              color: AppColors.emeraldLight,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
