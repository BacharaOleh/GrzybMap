import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../navigation/service/parking_service.dart';

/// Minimalist Car Anchor FAB situated right above the GPS FAB.
/// Allows instant 1-tap car anchoring, shows distance, and toggles the
/// navigation line only on demand so the map stays clean.
class CarAnchorFab extends StatelessWidget {
  final LatLng? carLocation;
  final ParkingNavigation? navigation;
  final bool isRouteActive;
  final DateTime? parkedTime;
  final VoidCallback onSaveCar;
  final VoidCallback onToggleRoute;
  final VoidCallback onCenterCar;
  final VoidCallback onClearCar;

  const CarAnchorFab({
    super.key,
    required this.carLocation,
    required this.navigation,
    required this.isRouteActive,
    required this.parkedTime,
    required this.onSaveCar,
    required this.onToggleRoute,
    required this.onCenterCar,
    required this.onClearCar,
  });

  String _formatElapsed() {
    if (parkedTime == null) return 'przed chwilą';
    final elapsed = DateTime.now().difference(parkedTime!);
    if (elapsed.inMinutes < 1) return 'przed chwilą';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min temu';
    final hours = elapsed.inHours;
    final mins = elapsed.inMinutes % 60;
    return '$hours godz. $mins min temu';
  }

  void _showCarOptionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pill handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.amberWarn.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.amberWarn.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🚗', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Zaparkowane auto',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Zapisano: ${_formatElapsed()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Navigation stats if available
              if (navigation != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        label: 'ODLEGŁOŚĆ',
                        value: navigation!.humanDistance,
                        icon: Icons.straighten_rounded,
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      _StatColumn(
                        label: 'KIERUNEK',
                        value: '${navigation!.cardinalDirection} ${navigation!.arrowSymbol}',
                        icon: Icons.explore_rounded,
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      _StatColumn(
                        label: 'MARSZ PIESZO',
                        value: '~${navigation!.walkMinutes} min',
                        icon: Icons.directions_walk_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onToggleRoute();
                      },
                      icon: Icon(
                        isRouteActive
                            ? Icons.visibility_off_rounded
                            : Icons.route_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isRouteActive ? 'Ukryj linię' : 'Pokaż linię',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRouteActive
                            ? AppColors.card
                            : AppColors.amberWarn,
                        foregroundColor: isRouteActive
                            ? Colors.white
                            : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onCenterCar();
                    },
                    tooltip: 'Wycentruj na aucie',
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onClearCar();
                    },
                    tooltip: 'Usuń auto',
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.15),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // STATE A: No car saved yet -> minimalist circular button matching GPS FAB
    if (carLocation == null) {
      return FloatingActionButton.small(
        heroTag: 'carAnchorBtn',
        backgroundColor: AppColors.surface.withValues(alpha: 0.95),
        elevation: 3,
        tooltip: 'Zapisz auto tutaj',
        onPressed: () {
          HapticFeedback.lightImpact();
          onSaveCar();
        },
        child: const Icon(
          Icons.directions_car_outlined,
          size: 20,
          color: AppColors.amberWarn,
        ),
      );
    }

    // STATE B: Car is saved -> sleek capsule pill showing distance
    // Tapping it toggles the route line ON/OFF directly
    // Long pressing it opens options (center, delete, stats)
    final distanceLabel = navigation?.humanDistance ?? 'Auto';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          HapticFeedback.selectionClick();
          onToggleRoute();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showCarOptionsSheet(context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isRouteActive
                ? AppColors.surfaceElevated.withValues(alpha: 0.96)
                : AppColors.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isRouteActive
                  ? AppColors.amberWarn
                  : AppColors.amberWarn.withValues(alpha: 0.45),
              width: isRouteActive ? 1.6 : 1.1,
            ),
            boxShadow: [
              const BoxShadow(
                color: Colors.black38,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
              if (isRouteActive)
                BoxShadow(
                  color: AppColors.amberWarn.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🚗 Icon wrapper
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isRouteActive
                      ? AppColors.amberWarn.withValues(alpha: 0.25)
                      : AppColors.amberWarn.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  isRouteActive ? '🧭' : '🚗',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 7),

              // Distance text with Tabular Figures
              Text(
                distanceLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isRouteActive ? AppColors.amberWarn : Colors.white,
                  letterSpacing: -0.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 5),

              // Route toggle indicator icon
              Icon(
                isRouteActive
                    ? Icons.route_rounded
                    : Icons.alt_route_rounded,
                size: 15,
                color: isRouteActive
                    ? AppColors.amberWarn
                    : AppColors.textDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.amberWarn),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textDim,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
