import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../foraging_journal/presentation/widgets/save_spot_dialog.dart';
import '../../../forest_reports/presentation/forest_report_sheet.dart';
import '../../../parcel_inspector/domain/models.dart';
import '../../../navigation/service/parking_service.dart';
import '../../../safety/presentation/widgets/sos_position_sheet.dart';

/// Central tactical action hub modal.
/// Elegantly balances citizen mushroom foraging tools with forest district
/// crowdsourcing (Eko-Zgłoszenia) and emergency rescue (SOS).
class TacticalActionHubSheet extends StatelessWidget {
  final LatLng currentPoint;
  final ForestParcel? parcel;
  final ParkingNavigation? carNavigation;
  final int journalSpotsCount;
  final VoidCallback onOpenJournal;

  const TacticalActionHubSheet({
    super.key,
    required this.currentPoint,
    required this.parcel,
    this.carNavigation,
    required this.journalSpotsCount,
    required this.onOpenJournal,
  });

  /// Displays the modal sheet.
  static Future<void> show({
    required BuildContext context,
    required LatLng currentPoint,
    required ForestParcel? parcel,
    ParkingNavigation? carNavigation,
    required int journalSpotsCount,
    required VoidCallback onOpenJournal,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TacticalActionHubSheet(
        currentPoint: currentPoint,
        parcel: parcel,
        carNavigation: carNavigation,
        journalSpotsCount: journalSpotsCount,
        onOpenJournal: onOpenJournal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.border, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Centrum Akcji Terenowych',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Grzybobranie, współpraca z leśnictwem i bezpieczeństwo',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textDim),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.borderLight, height: 1),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                children: [
                  // Action 1: Add Private Mushroom Spot
                  _ActionTile(
                    icon: Icons.add_location_alt_rounded,
                    iconColor: AppColors.emeraldNeon,
                    iconBg: AppColors.emeraldNeon.withValues(alpha: 0.14),
                    title: 'Dodaj prywatne miejsce grzybowe',
                    subtitle: 'Zapisz zbiór i gatunek w 100% bezpiecznym dzienniku offline',
                    badgeText: 'Prywatne',
                    badgeColor: AppColors.emeraldNeon,
                    onTap: () {
                      Navigator.of(context).pop();
                      HapticFeedback.lightImpact();
                      SaveSpotDialog.show(
                        context: context,
                        location: currentPoint,
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Action 2: Open Foraging Journal
                  _ActionTile(
                    icon: Icons.auto_stories_rounded,
                    iconColor: AppColors.emeraldLight,
                    iconBg: AppColors.emeraldLight.withValues(alpha: 0.12),
                    title: 'Dziennik Grzybiarza',
                    subtitle: 'Przeglądaj zebrane zbiory, statystyki i mapę znalezisk',
                    badgeText: journalSpotsCount > 0 ? '$journalSpotsCount miejsc' : null,
                    badgeColor: AppColors.textMuted,
                    onTap: () {
                      Navigator.of(context).pop();
                      HapticFeedback.lightImpact();
                      onOpenJournal();
                    },
                  ),

                  const SizedBox(height: 8),

                  // Action 3: Eko-Zgłoszenie (Forest crowdsourcing)
                  _ActionTile(
                    icon: Icons.campaign_rounded,
                    iconColor: AppColors.amberWarn,
                    iconBg: AppColors.amberWarn.withValues(alpha: 0.14),
                    title: 'Eko-Zgłoszenie dla Leśnictwa',
                    subtitle: 'Zgłoś dzikie wysypisko, wiatrołom na drodze pożarowej lub dym',
                    badgeText: 'Nadleśnictwo',
                    badgeColor: AppColors.amberWarn,
                    onTap: () {
                      Navigator.of(context).pop();
                      HapticFeedback.lightImpact();
                      ForestReportSheet.show(
                        context: context,
                        location: currentPoint,
                        parcel: parcel,
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Action 4: SOS Rescue Card
                  _ActionTile(
                    icon: Icons.sos_rounded,
                    iconColor: AppColors.danger,
                    iconBg: AppColors.danger.withValues(alpha: 0.16),
                    title: 'Karta Ratunkowa SOS / Gdzie jestem',
                    subtitle: 'Oddział leśny BDL, słupek oddziałowy i szybki SMS do 112',
                    badgeText: 'Pomoc',
                    badgeColor: AppColors.danger,
                    onTap: () {
                      Navigator.of(context).pop();
                      HapticFeedback.mediumImpact();
                      SosPositionSheet.show(
                        context: context,
                        location: currentPoint,
                        parcel: parcel,
                        carNavigation: carNavigation,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppRadii.inner),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? AppColors.emeraldNeon).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: badgeColor ?? AppColors.emeraldNeon,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDim,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
