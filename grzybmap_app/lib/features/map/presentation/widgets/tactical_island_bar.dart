import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter, FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

/// Floating glassmorphic dock at the bottom of the map screen (Thumb Zone).
/// Houses the 5 core tactical features:
/// 1. 🍄 Radary (mushroom filter, probability threshold, rain heatmap)
/// 2. 🚗 Auto (instant 1-tap car anchoring or distance/bearing readout)
/// 3. 📍+ Miejsca (secret spots journal + instant 1-tap find recording)
/// 4. 💾 Offline (downloaded 10x10 km packs manager & offline indicator)
/// 5. 🗺️ Warstwy (fast map layer cycling)
class TacticalIslandBar extends StatelessWidget {
  final bool isRadarsActive;
  final String? targetMushroomName;
  final VoidCallback onToggleRadars;
  final VoidCallback? onLongPressRadars;

  final int journalSpotsCount;
  final VoidCallback onOpenJournal;
  final VoidCallback onQuickAddSpot;

  final int offlineAreasCount;
  final bool isOfflineMode;
  final VoidCallback onOpenOffline;

  final String activeLayerLabel;
  final VoidCallback onCycleLayer;

  const TacticalIslandBar({
    super.key,
    required this.isRadarsActive,
    this.targetMushroomName,
    required this.onToggleRadars,
    this.onLongPressRadars,
    required this.journalSpotsCount,
    required this.onOpenJournal,
    required this.onQuickAddSpot,
    required this.offlineAreasCount,
    required this.isOfflineMode,
    required this.onOpenOffline,
    required this.activeLayerLabel,
    required this.onCycleLayer,
  });

  @override
  Widget build(BuildContext context) {

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 78,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0C140F).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.emeraldDeep.withValues(alpha: 0.20),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 1. Radary Tile Card
                  Expanded(
                    child: _TacticalTileCard(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onToggleRadars();
                      },
                      onLongPress: onLongPressRadars != null
                          ? () {
                              HapticFeedback.mediumImpact();
                              onLongPressRadars!();
                            }
                          : null,
                      isActive: isRadarsActive || targetMushroomName != null,
                      activeBorderColor: AppColors.emeraldLight.withValues(alpha: 0.5),
                      topBadge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldNeon,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emeraldNeon.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          targetMushroomName != null ? 'ON' : '94%',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      icon: const MushroomVectorIcon(size: 21),
                      label: targetMushroomName ?? 'Radary',
                      labelColor: targetMushroomName != null
                          ? AppColors.emeraldNeon
                          : Colors.white,
                    ),
                  ),

                  const SizedBox(width: 6),

                  // 2. Miejsca Tile Card (Hero Centerpiece)
                  Expanded(
                    child: _TacticalTileCard(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onOpenJournal();
                      },
                      onLongPress: () {
                        HapticFeedback.heavyImpact();
                        onQuickAddSpot();
                      },
                      isHero: true,
                      isActive: true,
                      cardColor: const Color(0xFF0F2618),
                      activeBorderColor: AppColors.emeraldNeon,
                      topBadge: journalSpotsCount > 0
                          ? Text(
                              '($journalSpotsCount)',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emeraldNeon,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            )
                          : null,
                      icon: const Icon(
                        Icons.add_rounded,
                        size: 27,
                        color: AppColors.emeraldNeon,
                      ),
                      label: 'Miejsca',
                      labelColor: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 6),

                  // 4. Offline Tile Card
                  Expanded(
                    child: _TacticalTileCard(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onOpenOffline();
                      },
                      isActive: isOfflineMode || offlineAreasCount > 0,
                      activeBorderColor: AppColors.emeraldLight.withValues(alpha: 0.4),
                      topBadge: (offlineAreasCount > 0 || isOfflineMode)
                          ? Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.emeraldNeon,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.emeraldNeon,
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            )
                          : null,
                      icon: Icon(
                        Icons.save_rounded,
                        size: 20,
                        color: isOfflineMode
                            ? AppColors.emeraldNeon
                            : (offlineAreasCount > 0 ? Colors.white : AppColors.textDim),
                      ),
                      label: isOfflineMode ? 'OFFLINE' : 'Offline',
                      labelColor: isOfflineMode
                          ? AppColors.emeraldNeon
                          : (offlineAreasCount > 0 ? Colors.white : AppColors.textDim),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // 5. Warstwy Tile Card
                  Expanded(
                    child: _TacticalTileCard(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onCycleLayer();
                      },
                      icon: const Icon(
                        Icons.layers_rounded,
                        size: 20,
                        color: Colors.white70,
                      ),
                      label: activeLayerLabel,
                      labelColor: Colors.white,
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

/// Standalone tactile tile card representing one module in the dock.
class _TacticalTileCard extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget icon;
  final String label;
  final Color labelColor;
  final Widget? topBadge;
  final bool isHero;
  final bool isActive;
  final Color? cardColor;
  final Color? activeBorderColor;

  const _TacticalTileCard({
    required this.onTap,
    this.onLongPress,
    required this.icon,
    required this.label,
    this.labelColor = Colors.white,
    this.topBadge,
    this.isHero = false,
    this.isActive = false,
    this.cardColor,
    this.activeBorderColor,
  });

  @override
  State<_TacticalTileCard> createState() => _TacticalTileCardState();
}

class _TacticalTileCardState extends State<_TacticalTileCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBg = widget.cardColor ?? const Color(0xFF131F17);
    final borderColor = widget.isHero
        ? AppColors.emeraldNeon
        : (widget.isActive && widget.activeBorderColor != null
            ? widget.activeBorderColor!
            : Colors.white.withValues(alpha: 0.08));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: _isPressed ? effectiveBg.withValues(alpha: 0.7) : effectiveBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: widget.isHero ? 1.5 : 1.0,
            ),
            boxShadow: widget.isHero
                ? [
                    BoxShadow(
                      color: AppColors.emeraldNeon.withValues(alpha: 0.25),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Centered Icon + Labels
              Positioned.fill(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          widget.icon,
                          const SizedBox(height: 2),
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: widget.labelColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Optional Top Badge
              if (widget.topBadge != null)
                Positioned(
                  top: 5,
                  right: 5,
                  child: widget.topBadge!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom Vector Painter for modern mushroom icon (Zero Emojis).
class MushroomVectorIcon extends StatelessWidget {
  final double size;
  final Color capColor;
  final Color stemColor;

  const MushroomVectorIcon({
    super.key,
    this.size = 22,
    this.capColor = const Color(0xFFC084FC),
    this.stemColor = const Color(0xFFF3E8FF),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MushroomIconPainter(
        capColor: capColor,
        stemColor: stemColor,
      ),
    );
  }
}

class _MushroomIconPainter extends CustomPainter {
  final Color capColor;
  final Color stemColor;

  _MushroomIconPainter({
    required this.capColor,
    required this.stemColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final capPaint = Paint()
      ..color = capColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final stemPaint = Paint()
      ..color = stemColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Stem: rounded pillar
    final stemRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.72),
        width: size.width * 0.34,
        height: size.height * 0.44,
      ),
      Radius.circular(size.width * 0.14),
    );
    canvas.drawRRect(stemRect, stemPaint);

    // Cap: rounded dome
    final capPath = ui.Path();
    capPath.moveTo(size.width * 0.12, size.height * 0.56);
    capPath.cubicTo(
      size.width * 0.10, size.height * 0.18,
      size.width * 0.90, size.height * 0.18,
      size.width * 0.88, size.height * 0.56,
    );
    capPath.close();
    canvas.drawPath(capPath, capPaint);

    // Subtle white dot on cap
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawCircle(
      Offset(size.width * 0.36, size.height * 0.36),
      size.width * 0.07,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
