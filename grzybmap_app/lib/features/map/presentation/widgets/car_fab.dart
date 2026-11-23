import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../navigation/service/parking_service.dart';

/// Floating Action Button for recording and navigating to parked car location.
/// Positioned right above the GPS button with high-contrast amber/yellow tactical styling.
class CarFab extends StatelessWidget {
  final LatLng? carLocation;
  final ParkingNavigation? carNavigation;
  final VoidCallback onSaveCar;
  final VoidCallback onOpenCarOptions;

  const CarFab({
    super.key,
    required this.carLocation,
    required this.carNavigation,
    required this.onSaveCar,
    required this.onOpenCarOptions,
  });

  @override
  Widget build(BuildContext context) {
    final hasCar = carLocation != null;

    return Positioned(
      bottom: 168,
      right: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // If car is parked and distance is computed, show compact tactical readout pill
          if (hasCar && carNavigation != null) ...[
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onOpenCarOptions();
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1A11).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.amberWarn.withValues(alpha: 0.65),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amberWarn.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${carNavigation!.humanDistance} ${carNavigation!.arrowSymbol}',
                          style: const TextStyle(
                            color: AppColors.amberWarn,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Circle Car Button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (hasCar) {
                onOpenCarOptions();
              } else {
                onSaveCar();
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: hasCar
                        ? const Color(0xFF1E1A11).withValues(alpha: 0.94)
                        : const Color(0xFF121B15).withValues(alpha: 0.90),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasCar
                          ? AppColors.amberWarn
                          : AppColors.amberWarn.withValues(alpha: 0.50),
                      width: hasCar ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                      if (hasCar)
                        BoxShadow(
                          color: AppColors.amberWarn.withValues(alpha: 0.30),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: AppColors.amberWarn,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
