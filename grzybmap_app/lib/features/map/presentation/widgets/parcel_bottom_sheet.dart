import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../parcel_inspector/domain/models.dart';
import '../../../weather/domain/models.dart';
import '../../../mushroom_radar/domain/models.dart';
import '../../../mushroom_radar/service/match_engine.dart';
import 'info_card.dart';
import 'mushroom_photo_widget.dart';

/// Modal bottom sheet presenting parcel details, weather data, and mushroom matches.
class ParcelBottomSheet extends StatefulWidget {
  final ForestParcel? parcel;
  final WeatherRainfall? weather;
  final List<MushroomMatchResult> mushroomMatches;
  final int currentMonth;
  final VoidCallback? onSaveCarLocation;
  final VoidCallback? onSaveSecretSpot;
  final bool isOfflineCached;

  const ParcelBottomSheet({
    super.key,
    required this.parcel,
    required this.weather,
    required this.mushroomMatches,
    required this.currentMonth,
    this.onSaveCarLocation,
    this.onSaveSecretSpot,
    this.isOfflineCached = false,
  });

  /// Helper to show this bottom sheet modal.
  static Future<void> show({
    required BuildContext context,
    required ForestParcel? parcel,
    required WeatherRainfall? weather,
    required List<MushroomMatchResult> mushroomMatches,
    required int currentMonth,
    VoidCallback? onSaveCarLocation,
    VoidCallback? onSaveSecretSpot,
    bool isOfflineCached = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ParcelBottomSheet(
        parcel: parcel,
        weather: weather,
        mushroomMatches: mushroomMatches,
        currentMonth: currentMonth,
        onSaveCarLocation: onSaveCarLocation,
        onSaveSecretSpot: onSaveSecretSpot,
        isOfflineCached: isOfflineCached,
      ),
    );
  }

  @override
  State<ParcelBottomSheet> createState() => _ParcelBottomSheetState();
}

class _ParcelBottomSheetState extends State<ParcelBottomSheet> {
  late int _selectedMonth;
  late List<MushroomMatchResult> _currentMatches;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.currentMonth;
    _currentMatches = widget.mushroomMatches;
  }

  void _onSelectMonth(int month) {
    if (_selectedMonth == month) return;
    setState(() {
      _selectedMonth = month;
      if (widget.parcel != null) {
        _currentMatches = MatchEngine.evaluateMushrooms(
          parcel: widget.parcel!,
          weather: widget.weather,
          selectedMonth: month,
        );
      }
    });
  }

  String _monthName(int month) {
    const months = [
      '',
      'Styczeń',
      'Luty',
      'Marzec',
      'Kwiecień',
      'Maj',
      'Czerwiec',
      'Lipiec',
      'Sierpień',
      'Wrzesień',
      'Październik',
      'Listopad',
      'Grudzień',
    ];
    return month >= 1 && month <= 12 ? months[month] : 'Sezon';
  }

  String _shortMonthName(int month) {
    const months = [
      '',
      'Sty',
      'Lut',
      'Mar',
      'Kwi',
      'Maj',
      'Cze',
      'Lip',
      'Sie',
      'Wrz',
      'Paź',
      'Lis',
      'Gru',
    ];
    return month >= 1 && month <= 12 ? months[month] : '';
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    final weather = widget.weather;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),

              // === FOREST DATA AVAILABLE ===
              if (parcel != null) ...[
                // Title row: tree species + status badge matching mockup
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.park_rounded,
                                size: 20,
                                color: AppColors.emeraldNeon,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${parcel.primarySpecies.namePl} (${parcel.primarySpecies.sharePercent}%)',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nadleśnictwo ${parcel.inspectorate} • ${parcel.ageYears} lat • Wydz. ${parcel.subareaId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: parcel.status.code == 'GOSP'
                            ? AppColors.emeraldNeon
                            : parcel.status.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: parcel.status.code == 'GOSP'
                            ? [
                                BoxShadow(
                                  color: AppColors.emeraldNeon.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: parcel.status.code == 'GOSP'
                                  ? Colors.black
                                  : parcel.status.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            parcel.status.code == 'GOSP'
                                ? 'ZBIÓR DOZWOLONY'
                                : 'ZAKAZ ZBIORU',
                            style: TextStyle(
                              color: parcel.status.code == 'GOSP'
                                  ? Colors.black
                                  : parcel.status.color,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Habitat + Weather cards
                Row(
                  children: [
                    Expanded(
                      child: InfoCard(
                        icon: Icons.forest,
                        iconColor: AppColors.emeraldNeon,
                        label: 'TYP LASU',
                        value: parcel.habitat.namePl,
                        desc: parcel.habitat.descPl,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InfoCard(
                        icon: Icons.water_drop,
                        iconColor:
                            weather?.moistureBadgeColor ?? AppColors.skyBlue,
                        label: 'OPADY (14 DNI)',
                        value: weather != null
                            ? '${weather.totalRainMm.toStringAsFixed(1)} mm'
                            : '-- mm',
                        desc: weather != null
                            ? weather.moistureLabel
                            : 'Stacja niedostępna',
                      ),
                    ),
                  ],
                ),
                // Soil metrics banner (W2)
                if (weather != null &&
                    (weather.soilTempC != null || weather.soilMoistureM3 != null)) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.thermostat,
                          size: 14,
                          color: AppColors.goldAmber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Gleba (6cm): ${weather.soilTempLabel}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.water,
                          size: 14,
                          color: AppColors.skyBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ściółka: ${weather.soilMoisturePercent}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (weather == null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 14,
                          color: AppColors.textDim,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Brak danych ze stacji pogodowej (ocena neutralna)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Age category info strip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppColors.textDim,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          parcel.ageCategory,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (parcel.areaHa != null)
                        Text(
                          parcel.areaHa!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textDim,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // U4: Technical forestry address spoiler
                ForestDetailsSpoiler(parcel: parcel),
                const SizedBox(height: 18),

                // === MUSHROOM RADAR HEADER ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🍄 RADAR GRZYBIARZA',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.emeraldNeon,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _monthName(_selectedMonth),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.emeraldNeon,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Interactive Month Selector (1-12)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(12, (index) {
                      final m = index + 1;
                      final isSelected = m == _selectedMonth;
                      final isRealMonth = m == DateTime.now().month;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => _onSelectMonth(m),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.emeraldDeep
                                  : (isRealMonth
                                      ? AppColors.card
                                      : AppColors.surface),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.emeraldNeon
                                    : (isRealMonth
                                        ? AppColors.borderLight
                                        : Colors.white10),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              _shortMonthName(m),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : (isRealMonth
                                        ? FontWeight.w600
                                        : FontWeight.normal),
                                color: isSelected
                                    ? Colors.white
                                    : (isRealMonth
                                        ? AppColors.textMain
                                        : AppColors.textMuted),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                // Scored mushrooms list
                // Horizontal Mushroom Carousel (~74% width per card with peeking next card)
                _buildMushroomCarousel(context),

                const SizedBox(height: 18),

                // Clean Bottom Action Button matching mockup: "🧭 Nawiguj do tego wydziału"
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.explore_rounded, size: 20, color: Colors.black),
                    label: const Text(
                      'Nawiguj do tego wydziału',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: Colors.black,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),

              // === NO FOREST DATA ===
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.forest_outlined,
                          size: 48,
                          color: AppColors.textDim,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Brak danych o lesie',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ten punkt nie leży na terenie Lasów Państwowych, lub dane BDL są niedostępne.\n\nSpróbuj kliknąć w inny punkt lasu lub przybliż mapę.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (weather != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.water_drop,
                                  size: 16,
                                  color: weather.moistureBadgeColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Opady (14 dni): ${weather.totalRainMm.toStringAsFixed(1)} mm • Gleba: ${weather.soilTempLabel} (${weather.soilMoisturePercent})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              border: Border.fromBorderSide(BorderSide(color: Colors.white10)),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.cloud_off,
                                  size: 16,
                                  color: AppColors.textDim,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Brak danych ze stacji pogodowej dla tego punktu.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMushroomCarousel(BuildContext context) {
    if (_currentMatches.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Brak danych do oceny grzybów dla tego wydełu.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.74).clamp(260.0, 360.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header matching mockup: "🎯 PROGNOZA GRZYBOWA (Przesuń w prawo ➔)"
        const Row(
          children: [
            Text('🎯', style: TextStyle(fontSize: 14)),
            SizedBox(width: 6),
            Text(
              'PROGNOZA GRZYBOWA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: 6),
            Text(
              '(Przesuń w prawo ➔)',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textDim,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 335,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            itemCount: _currentMatches.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final result = _currentMatches[index];
              return SizedBox(
                width: cardWidth,
                child: _CarouselMushroomCard(
                  result: result,
                  onShowLookalike: () =>
                      _showLookalikeComparison(context, result.mushroom),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // Indicator Dots matching mockup
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _currentMatches.length.clamp(1, 6),
            (dotIndex) => Container(
              width: dotIndex == 0 ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: dotIndex == 0 ? Colors.white : Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLookalikeComparison(BuildContext context, Mushroom m) {
    final lookalike = m.lookalike;
    if (lookalike == null) return;

    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: lookalike.isLethal
                ? AppColors.danger.withValues(alpha: 0.6)
                : AppColors.goldAmber.withValues(alpha: 0.4),
            width: 1.4,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    lookalike.isLethal
                        ? Icons.dangerous_rounded
                        : Icons.warning_amber_rounded,
                    color: lookalike.isLethal
                        ? AppColors.danger
                        : AppColors.goldAmber,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lookalike.isLethal
                          ? 'ŚMIERTELNIE TRUJĄCY SOBOWTÓR'
                          : 'UWAGA NA PODOBNY GATUNEK',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: lookalike.isLethal
                            ? AppColors.danger
                            : AppColors.goldAmber,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14241B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                AppColors.emeraldLight.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          MushroomPhotoWidget(
                            assetPath: m.photoAsset,
                            size: 54,
                            borderRadius: 12,
                            borderColor: AppColors.emeraldNeon,
                            borderWidth: 1.5,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            m.namePl,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'JADALNY 🟢',
                            style: TextStyle(
                              color: AppColors.emeraldNeon,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('VS',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDim)),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lookalike.isLethal
                            ? const Color(0xFF281013)
                            : const Color(0xFF281E10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: lookalike.isLethal
                              ? AppColors.danger
                              : AppColors.goldAmber,
                        ),
                      ),
                      child: Column(
                        children: [
                          MushroomPhotoWidget(
                            assetPath: lookalike.photoAsset,
                            size: 54,
                            borderRadius: 12,
                            borderColor: lookalike.isLethal
                                ? AppColors.danger
                                : AppColors.goldAmber,
                            borderWidth: 1.5,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lookalike.namePl,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lookalike.isLethal
                                ? 'ŚMIERTELNY ☠️'
                                : 'TRUJĄCY / NIEJADALNY ⚠️',
                            style: TextStyle(
                              color: lookalike.isLethal
                                  ? AppColors.danger
                                  : AppColors.goldAmber,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  lookalike.warningPl,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white, height: 1.4),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Rozumiem, zachowam ostrożność'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarouselMushroomCard extends StatelessWidget {
  final MushroomMatchResult result;
  final VoidCallback onShowLookalike;

  const _CarouselMushroomCard({
    required this.result,
    required this.onShowLookalike,
  });

  @override
  Widget build(BuildContext context) {
    final m = result.mushroom;
    final lookalike = m.lookalike;
    final hasLethalLookalike = lookalike != null && lookalike.isLethal;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141F16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasLethalLookalike
              ? AppColors.danger.withValues(alpha: 0.7)
              : (lookalike != null
                  ? AppColors.goldAmber.withValues(alpha: 0.5)
                  : AppColors.emeraldNeon.withValues(alpha: 0.55)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (hasLethalLookalike
                    ? AppColors.danger
                    : AppColors.emeraldNeon)
                .withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Large Top Photo (Full Width, Height 160)
          MushroomPhotoWidget(
            assetPath: m.photoAsset,
            width: double.infinity,
            height: 160,
            borderRadius: 16,
            borderColor: Colors.white.withValues(alpha: 0.08),
            borderWidth: 1.0,
          ),

          const SizedBox(height: 10),

          // 2. Names & Probability Badge Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.namePl,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '(${m.latin})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textDim,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Glowing Chance Badge: "94% \n SZANS"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: result.chanceColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: result.chanceColor.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${result.probabilityPercent}%',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1.1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Text(
                      'SZANS',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // 3. Season Status Row
          Text(
            'Wysyp: ${result.chanceCategory}${result.positiveReasons.isNotEmpty ? ' • ${result.positiveReasons.first}' : ''}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // 4. Lookalike Button or Safe Indicator
          if (lookalike != null) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onShowLookalike,
              child: Container(
                width: double.infinity,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: lookalike.isLethal
                      ? const Color(0xFF2B1215)
                      : const Color(0xFF241C12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: lookalike.isLethal
                        ? AppColors.danger.withValues(alpha: 0.7)
                        : AppColors.goldAmber.withValues(alpha: 0.6),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      lookalike.isLethal
                          ? Icons.dangerous_rounded
                          : Icons.warning_amber_rounded,
                      size: 16,
                      color: lookalike.isLethal
                          ? AppColors.danger
                          : AppColors.goldAmber,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Uwaga na sobowtóra: ${lookalike.namePl}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: lookalike.isLethal
                              ? AppColors.danger
                              : AppColors.goldAmber,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: lookalike.isLethal
                          ? AppColors.danger
                          : AppColors.goldAmber,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10261A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.emeraldLight.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: AppColors.emeraldNeon,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Brak trujących sobowtórów w Polsce',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emeraldNeon,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// U4: Expandable spoiler widget that cleanly encapsulates technical forestry
/// address, subarea, inspectorate, STL habitat code, and GPS coordinates.
class ForestDetailsSpoiler extends StatefulWidget {
  final ForestParcel parcel;

  const ForestDetailsSpoiler({super.key, required this.parcel});

  @override
  State<ForestDetailsSpoiler> createState() => _ForestDetailsSpoilerState();
}

class _ForestDetailsSpoilerState extends State<ForestDetailsSpoiler> {
  bool _isExpanded = false;

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label skopiowano do schowka: $text'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_tree_outlined,
                      size: 16,
                      color: AppColors.emeraldNeon,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Szczegóły leśne (BDL)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                    Text(
                      _isExpanded ? 'Zwiń' : 'Rozwiń',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDim,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.textDim,
                    ),
                  ],
                ),
                if (!_isExpanded) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Adres: ${parcel.address}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textDim,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (_isExpanded) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: AppColors.borderLight, height: 1),
                        const SizedBox(height: 10),
                        // Forest Address with copy button
                        _buildDetailRow(
                          label: 'Adres leśny',
                          value: parcel.address,
                          isMonospace: true,
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.copy,
                              size: 14,
                              color: AppColors.emeraldNeon,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Kopiuj adres leśny',
                            onPressed: () => _copyToClipboard(
                              context,
                              parcel.address,
                              'Adres leśny',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          label: 'Wydzielenie',
                          value: parcel.subareaId,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          label: 'Nadleśnictwo',
                          value: parcel.inspectorate,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          label: 'Siedlisko (STL)',
                          value: '${parcel.habitat.code} — ${parcel.habitat.namePl}',
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          label: 'Status prawny',
                          value: '${parcel.status.labelPl} (${parcel.status.code})',
                        ),
                        if (parcel.areaHa != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            label: 'Powierzchnia',
                            value: parcel.areaHa!,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          label: 'Współrzędne GPS',
                          value:
                              '${parcel.latitude.toStringAsFixed(5)}°N, ${parcel.longitude.toStringAsFixed(5)}°E',
                          isMonospace: true,
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.copy,
                              size: 14,
                              color: AppColors.emeraldNeon,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Kopiuj współrzędne',
                            onPressed: () => _copyToClipboard(
                              context,
                              '${parcel.latitude.toStringAsFixed(5)}, ${parcel.longitude.toStringAsFixed(5)}',
                              'Współrzędne GPS',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isMonospace = false,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textDim,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}

