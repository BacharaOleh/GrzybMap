import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
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
        border: Border.all(color: AppColors.border),
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with icon and title
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('📍', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${spot.mushroomName} • ${mushroom.latin}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.emeraldNeon,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    spot.humanQuantity,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Details card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Data znaleziska',
                    value: spot.formattedDate,
                  ),
                  if (spot.forestParcelId != null) ...[
                    const Divider(color: AppColors.border, height: 16),
                    _InfoRow(
                      icon: Icons.forest_outlined,
                      label: 'Wydzielenie leśne BDL',
                      value: spot.forestParcelId!,
                    ),
                  ],
                  const Divider(color: AppColors.border, height: 16),
                  _InfoRow(
                    icon: Icons.my_location_rounded,
                    label: 'Współrzędne GPS',
                    value: '${spot.latitude.toStringAsFixed(4)}, ${spot.longitude.toStringAsFixed(4)}',
                  ),
                  if (spot.notes.isNotEmpty) ...[
                    const Divider(color: AppColors.border, height: 16),
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

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDelete();
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    label: const Text('Usuń miejsce', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (onNavigate != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onNavigate!();
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text('Pokaż na mapie'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldNeon,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
