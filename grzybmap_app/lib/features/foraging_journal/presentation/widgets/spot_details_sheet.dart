import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../map/presentation/widgets/mushroom_photo_widget.dart';
import '../../../mushroom_radar/data/mushroom_database.dart';
import '../../domain/models/foraging_spot.dart';

/// Bottom sheet displaying the details of a saved secret foraging spot.
class SpotDetailsSheet extends StatelessWidget {
  final ForagingSpot spot;
  final VoidCallback onDelete;
  final VoidCallback? onNavigate;

  const SpotDetailsSheet({
    super.key,
    required this.spot,
    required this.onDelete,
    this.onNavigate,
  });

  static Future<void> show({
    required BuildContext context,
    required ForagingSpot spot,
    required VoidCallback onDelete,
    VoidCallback? onNavigate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SpotDetailsSheet(
        spot: spot,
        onDelete: onDelete,
        onNavigate: onNavigate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mushroom = MushroomDatabase.allMushrooms.firstWhere(
      (m) => m.id == spot.mushroomId,
      orElse: () => MushroomDatabase.allMushrooms.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with authentic botanical photo thumbnail and title
            Row(
              children: [
                MushroomPhotoWidget(
                  assetPath: mushroom.photoAsset,
                  base64Data: spot.photoPath,
                  size: 48,
                  borderRadius: 12,
                  borderColor: spot.hasPhoto
                      ? AppColors.emeraldNeon
                      : AppColors.emeraldNeon.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.title,
                        style: AppTypography.titleLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: spot.mushroomName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.emeraldNeon,
                              ),
                            ),
                            const TextSpan(
                              text: ' • ',
                              style: TextStyle(color: AppColors.textDim),
                            ),
                            TextSpan(
                              text: mushroom.latin,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: AppColors.emeraldLight.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadii.pillRadius,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    spot.humanQuantity,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),

            if (spot.hasPhoto) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: AppRadii.cardRadius,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: AppRadii.cardRadius,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MushroomPhotoWidget(
                        assetPath: null,
                        base64Data: spot.photoPath,
                        width: double.infinity,
                        height: 150,
                        borderRadius: 16,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.emeraldNeon.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_camera_rounded, size: 12, color: AppColors.emeraldNeon),
                              SizedBox(width: 4),
                              Text(
                                'Twoje zdjęcie',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Details card with concentric radius
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: AppRadii.cardRadius,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Data znaleziska',
                    value: spot.formattedDate,
                    isTabular: true,
                  ),
                  if (spot.forestParcelId != null) ...[
                    const Divider(color: AppColors.borderLight, height: 16, thickness: 0.8),
                    _InfoRow(
                      icon: Icons.park_rounded,
                      label: 'Wydzielenie leśne BDL',
                      value: spot.forestParcelId!,
                      isTabular: true,
                    ),
                  ],
                  const Divider(color: AppColors.borderLight, height: 16, thickness: 0.8),
                  _InfoRow(
                    icon: Icons.my_location_rounded,
                    label: 'Współrzędne GPS',
                    value: '${spot.latitude.toStringAsFixed(4)}, ${spot.longitude.toStringAsFixed(4)}',
                    isTabular: true,
                  ),
                  if (spot.notes.isNotEmpty) ...[
                    const Divider(color: AppColors.borderLight, height: 16, thickness: 0.8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_rounded, size: 16, color: AppColors.textDim),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            spot.notes,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textDim,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons with tactile feedback
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        unawaited(HapticFeedback.mediumImpact());
                        Navigator.of(context).pop();
                        onDelete();
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      label: const Text('Usuń miejsce', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                if (onNavigate != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          unawaited(HapticFeedback.selectionClick());
                          Navigator.of(context).pop();
                          onNavigate!();
                        },
                        icon: const Icon(Icons.explore_rounded, size: 18),
                        label: const Text('Pokaż na mapie', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emeraldNeon,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isTabular;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isTabular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textDim),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textDim),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFeatures: isTabular ? const [FontFeature.tabularFigures()] : null,
          ),
        ),
      ],
    );
  }
}
