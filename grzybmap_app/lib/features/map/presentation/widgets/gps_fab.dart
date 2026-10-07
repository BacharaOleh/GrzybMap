import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Floating Action Button for locating the user on the map.
class GpsFab extends StatelessWidget {
  final bool isLocating;
  final bool hasLocation;
  final VoidCallback? onPressed;

  const GpsFab({
    super.key,
    required this.isLocating,
    required this.hasLocation,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 16,
      child: FloatingActionButton.small(
        heroTag: 'gpsBtn',
        backgroundColor: AppColors.surface.withValues(alpha: 0.95),
        onPressed: isLocating ? null : onPressed,
        child: isLocating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.skyBlue,
                ),
              )
            : Icon(
                hasLocation ? Icons.my_location : Icons.location_searching,
                size: 20,
                color: AppColors.skyBlue,
              ),
      ),
    );
  }
}
