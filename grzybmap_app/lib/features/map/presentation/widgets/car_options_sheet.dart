import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../navigation/service/parking_service.dart';

/// Modal bottom sheet presenting options and live telemetry for a saved car anchor.
class CarOptionsSheet extends StatelessWidget {
  final DateTime? carParkedTime;
  final ParkingNavigation? carNavigation;
  final bool isCarRouteActive;
  final VoidCallback onToggleCarRoute;
  final VoidCallback onCenterCar;
  final VoidCallback onClearCar;
  final VoidCallback onUpdateCarLocation;

  const CarOptionsSheet({
    super.key,
    required this.carParkedTime,
    required this.carNavigation,
    required this.isCarRouteActive,
    required this.onToggleCarRoute,
    required this.onCenterCar,
    required this.onClearCar,
    required this.onUpdateCarLocation,
  });

  static Future<void> show({
    required BuildContext context,
    required DateTime? carParkedTime,
    required ParkingNavigation? carNavigation,
    required bool isCarRouteActive,
    required VoidCallback onToggleCarRoute,
    required VoidCallback onCenterCar,
    required VoidCallback onClearCar,
    required VoidCallback onUpdateCarLocation,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CarOptionsSheet(
        carParkedTime: carParkedTime,
        carNavigation: carNavigation,
        isCarRouteActive: isCarRouteActive,
        onToggleCarRoute: onToggleCarRoute,
        onCenterCar: onCenterCar,
        onClearCar: onClearCar,
        onUpdateCarLocation: onUpdateCarLocation,
      ),
    );
  }

  String _formatCarElapsed() {
    if (carParkedTime == null) return 'przed chwilą';
    final elapsed = DateTime.now().difference(carParkedTime!);
    if (elapsed.inMinutes < 1) return 'przed chwilą';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min temu';
    final hours = elapsed.inHours;
    final mins = elapsed.inMinutes % 60;
    return '$hours godz. $mins min temu';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.amberWarn.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.amberWarn.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: AppColors.amberWarn,
                    size: 22,
                  ),
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
                        'Zapisano: ${_formatCarElapsed()}',
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
            if (carNavigation != null) ...[
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
                      value: carNavigation!.humanDistance,
                      icon: Icons.straighten_rounded,
                    ),
                    Container(width: 1, height: 32, color: AppColors.border),
                    _StatColumn(
                      label: 'KIERUNEK',
                      value:
                          '${carNavigation!.cardinalDirection} ${carNavigation!.arrowSymbol}',
                      icon: Icons.explore_rounded,
                    ),
                    Container(width: 1, height: 32, color: AppColors.border),
                    _StatColumn(
                      label: 'MARSZ PIESZO',
                      value: '~${carNavigation!.walkMinutes} min',
                      icon: Icons.directions_walk_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isCarRouteActive
                          ? AppColors.amberWarn
                          : Colors.white,
                      side: BorderSide(
                        color: isCarRouteActive
                            ? AppColors.amberWarn
                            : AppColors.border,
                        width: isCarRouteActive ? 1.5 : 1.0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onToggleCarRoute();
                    },
                    icon: Icon(
                      isCarRouteActive
                          ? Icons.visibility_off_outlined
                          : Icons.near_me_outlined,
                      size: 18,
                    ),
                    label: Text(
                      isCarRouteActive ? 'Ukryj linię' : 'Pokaż linię',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amberWarn,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onCenterCar();
                    },
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text(
                      'Pokaż na mapie',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textDim,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onUpdateCarLocation();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text(
                      'Zaktualizuj pozycję auta',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onClearCar();
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text(
                      'Usuń auto',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
        Icon(icon, size: 15, color: AppColors.amberWarn),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            color: AppColors.textDim,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
