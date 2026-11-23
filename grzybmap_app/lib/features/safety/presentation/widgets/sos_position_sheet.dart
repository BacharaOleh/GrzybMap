import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../parcel_inspector/domain/models.dart';
import '../../../navigation/service/parking_service.dart';
import '../../domain/sos_card_generator.dart';

/// High-contrast tactical emergency rescue sheet.
/// Designed for maximum legibility in high-stress outdoor situations,
/// poor GSM connectivity, and direct sunlight.
class SosPositionSheet extends StatelessWidget {
  final LatLng? location;
  final ForestParcel? parcel;
  final ParkingNavigation? carNavigation;
  final VoidCallback? onLocateMe;

  const SosPositionSheet({
    super.key,
    required this.location,
    required this.parcel,
    this.carNavigation,
    this.onLocateMe,
  });

  /// Displays the modal sheet.
  static Future<void> show({
    required BuildContext context,
    required LatLng? location,
    required ForestParcel? parcel,
    ParkingNavigation? carNavigation,
    VoidCallback? onLocateMe,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SosPositionSheet(
        location: location,
        parcel: parcel,
        carNavigation: carNavigation,
        onLocateMe: onLocateMe,
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Skopiowano dane pozycji do schowka!'),
        backgroundColor: AppColors.emeraldDeep,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchSms(BuildContext context, String body) async {
    final uri = Uri(
      scheme: 'sms',
      path: '112',
      queryParameters: {'body': body},
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!context.mounted) return;
        _copyToClipboard(context, body);
      }
    } catch (_) {
      if (!context.mounted) return;
      _copyToClipboard(context, body);
    }
  }

  Future<void> _launchPhoneCall(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rescueText = SosCardGenerator.generateRescueText(
      location: location,
      parcel: parcel,
      carNavigation: carNavigation,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1813),
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x33F87171), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 32,
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

            // Header Bar with SOS emblem
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.sos_rounded,
                      color: AppColors.danger,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Karta Pozycji Leśnej (SOS)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Precyzyjna lokalizacja dla ratowników i leśniczych',
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

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Emergency Info Card (High Contrast)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16231A),
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // BDL Forest Address Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.park_rounded,
                                size: 20,
                                color: AppColors.emeraldNeon,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ADRES LEŚNY (BDL)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.emeraldNeon,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      parcel?.address.isNotEmpty == true
                                          ? parcel!.address
                                          : (parcel?.inspectorate.isNotEmpty == true
                                              ? parcel!.inspectorate
                                              : 'Pobieranie adresu leśnego...'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 1.25,
                                      ),
                                    ),
                                    if (parcel?.subareaId.isNotEmpty == true) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.emeraldNeon
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: AppColors.emeraldNeon
                                                .withValues(alpha: 0.3),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          'Wydzielenie leśne: ${parcel!.subareaId}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.emeraldNeon,
                                            fontFeatures: [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(
                              color: AppColors.borderLight,
                              height: 1,
                            ),
                          ),

                          // GPS Coordinates Row
                          Row(
                            children: [
                              const Icon(
                                Icons.my_location_rounded,
                                size: 20,
                                color: AppColors.skyBlue,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'WSPÓŁRZĘDNE GPS (WGS84)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.skyBlue,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      location != null
                                          ? SosCardGenerator.formatCoordinates(location!)
                                          : 'Brak sygnału GPS',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Kopiuj współrzędne',
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  size: 18,
                                  color: AppColors.skyBlue,
                                ),
                                onPressed: location != null
                                    ? () => _copyToClipboard(
                                          context,
                                          '${location!.latitude.toStringAsFixed(5)}, ${location!.longitude.toStringAsFixed(5)}',
                                        )
                                    : null,
                              ),
                            ],
                          ),

                          // Car Navigation Vector (if car is saved)
                          if (carNavigation != null) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                color: AppColors.borderLight,
                                height: 1,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.directions_car_rounded,
                                  size: 20,
                                  color: AppColors.amberWarn,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'POWRÓT DO SAMOCHODU',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.amberWarn,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${carNavigation!.humanDistance} w kierunku ${carNavigation!.cardinalDirection} (${carNavigation!.arrowSymbol})',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Quick Action Buttons Row: Call 112 & Send SMS
                    Row(
                      children: [
                        // Emergency 112 Call
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _launchPhoneCall('112'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadii.card),
                              ),
                            ),
                            icon: const Icon(Icons.phone_in_talk_rounded, size: 19),
                            label: const Text(
                              'Zadzwoń 112',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // SMS Dispatch
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _launchSms(context, rescueText),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A2B),
                              foregroundColor: AppColors.emeraldNeon,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadii.card),
                                side: BorderSide(
                                  color: AppColors.emeraldNeon.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.sms_rounded, size: 19),
                            label: const Text(
                              'Wyślij SMS',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Copy Full Rescue Card Button
                    OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(context, rescueText),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.borderLight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.card),
                        ),
                      ),
                      icon: const Icon(Icons.copy_all_rounded, size: 18),
                      label: const Text(
                        'Kopiuj pełną wiadomość dla służb',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Safety in Forest Tips
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(AppRadii.inner),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.textDim,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Wskazówka terenowa: W lesie szukaj kamiennych lub betonowych słupków oddziałowych na skrzyżowaniach linii podziału. Wyryte na nich numery pozwalają leśniczym i strażakom określić pozycję z dokładnością do kilku metrów.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
