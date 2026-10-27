import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../service/parking_service.dart';

/// Floating compass HUD pill displaying distance, bearing, and walk time to parked car.
class CarCompassHud extends StatefulWidget {
  final LatLng carLocation;
  final ParkingNavigation? navigation;
  final DateTime? parkedTime;
  final VoidCallback onTapCenterCar;
  final VoidCallback onTapClearCar;

  const CarCompassHud({
    super.key,
    required this.carLocation,
    required this.navigation,
    this.parkedTime,
    required this.onTapCenterCar,
    required this.onTapClearCar,
  });

  @override
  State<CarCompassHud> createState() => _CarCompassHudState();
}

class _CarCompassHudState extends State<CarCompassHud> {
  bool _isPressed = false;

  String _formatElapsed() {
    if (widget.parkedTime == null) return '';
    final diff = DateTime.now().difference(widget.parkedTime!);
    if (diff.inMinutes < 1) return 'przed chwilą';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min temu';
    return '${diff.inHours}h ${diff.inMinutes % 60}m temu';
  }

  void _showCarDetailsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 25,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.amberWarn.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.amberWarn.withValues(alpha: 0.5)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🚗', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 14),
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
              if (widget.navigation != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
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
                        value: widget.navigation!.humanDistance,
                        icon: Icons.straighten_rounded,
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      _StatColumn(
                        label: 'KIERUNEK',
                        value: '${widget.navigation!.cardinalDirection} ${widget.navigation!.arrowSymbol}',
                        icon: Icons.explore_rounded,
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      _StatColumn(
                        label: 'MARSZ PIESZO',
                        value: '~${widget.navigation!.walkMinutes} min',
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
                        widget.onTapCenterCar();
                      },
                      icon: const Icon(Icons.my_location_rounded, size: 16),
                      label: const Text('Pokaż na mapie'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldDeep,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      widget.onTapClearCar();
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Usuń'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.15),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                      ),
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
    final nav = widget.navigation;
    final String label;
    if (nav != null) {
      label = 'Auto: ${nav.humanDistance} • ${nav.cardinalDirection} ${nav.arrowSymbol}';
    } else {
      label = 'Auto zapisane na mapie';
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _showCarDetailsSheet(context);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.amberWarn.withValues(alpha: 0.7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: AppColors.amberWarn.withValues(alpha: 0.15),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Button-in-button icon wrapper
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.amberWarn.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.amberWarn.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text('🚗', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),

              // Title with Tabular Figures
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.textDim,
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
