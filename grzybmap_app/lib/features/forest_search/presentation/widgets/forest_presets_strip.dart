import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models.dart';

class ForestPresetsStrip extends StatelessWidget {
  final void Function(ForestPreset preset) onSelectPreset;

  const ForestPresetsStrip({
    super.key,
    required this.onSelectPreset,
  });

  @override
  Widget build(BuildContext context) {
    const presets = ForestPreset.all;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preset = presets[index];
          return _PresetPill(
            preset: preset,
            onTap: () => onSelectPreset(preset),
          );
        },
      ),
    );
  }
}

class _PresetPill extends StatefulWidget {
  final ForestPreset preset;
  final VoidCallback onTap;

  const _PresetPill({
    required this.preset,
    required this.onTap,
  });

  @override
  State<_PresetPill> createState() => _PresetPillState();
}

class _PresetPillState extends State<_PresetPill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.9),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.preset.emoji,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 6),
              Text(
                widget.preset.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
