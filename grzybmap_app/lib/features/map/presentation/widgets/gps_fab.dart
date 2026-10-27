import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating Action Button for locating the user on the map.
/// Styled as an ultra-high-end sapphire frosted glass reticle button,
/// positioned cleanly above the tactical bottom island.
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
      bottom: 104,
      right: 16,
      child: GestureDetector(
        onTap: isLocating
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed?.call();
              },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF0F1E2E),
                    Color(0xFF08121A),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.65),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 18,
                    offset: Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Color(0xFF0EA5E9),
                    blurRadius: 14,
                    spreadRadius: -2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: isLocating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF38BDF8),
                      ),
                    )
                  : const Icon(
                      Icons.my_location_rounded,
                      size: 26,
                      color: Color(0xFF38BDF8),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular dark frosted glass compass dial pointing North,
/// located directly above the GPS button.
class CompassDialWidget extends StatelessWidget {
  final VoidCallback onResetNorth;

  const CompassDialWidget({
    super.key,
    required this.onResetNorth,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 168,
      right: 20,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onResetNorth();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF0C140F).withValues(alpha: 0.88),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 14,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Compass Dial Ticks
                  CustomPaint(
                    size: const Size(44, 44),
                    painter: _CompassTicksPainter(),
                  ),
                  // North Letter
                  const Text(
                    'N',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompassTicksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    for (int i = 0; i < 8; i++) {
      if (i == 0) continue; // Skip North tick where letter N sits
      final angle = (i * 45) * 3.1415926535 / 180;
      final dx1 = center.dx + (radius - 4) * math.sin(angle);
      final dy1 = center.dy - (radius - 4) * math.cos(angle);
      final dx2 = center.dx + radius * math.sin(angle);
      final dy2 = center.dy - radius * math.cos(angle);
      canvas.drawLine(Offset(dx1, dy1), Offset(dx2, dy2), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
