import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../parcel_inspector/domain/models.dart';
import '../../../weather/domain/models.dart';
import '../../../mushroom_radar/domain/models.dart';
import '../../../mushroom_radar/service/match_engine.dart';
import 'info_card.dart';
import 'mushroom_card.dart';

/// Modal bottom sheet presenting parcel details, weather data, and mushroom matches.
class ParcelBottomSheet extends StatefulWidget {
  final ForestParcel? parcel;
  final WeatherRainfall? weather;
  final List<MushroomMatchResult> mushroomMatches;
  final int currentMonth;
  final VoidCallback? onSaveCarLocation;

  const ParcelBottomSheet({
    super.key,
    required this.parcel,
    required this.weather,
    required this.mushroomMatches,
    required this.currentMonth,
    this.onSaveCarLocation,
  });

  /// Helper to show this bottom sheet modal.
  static Future<void> show({
    required BuildContext context,
    required ForestParcel? parcel,
    required WeatherRainfall? weather,
    required List<MushroomMatchResult> mushroomMatches,
    required int currentMonth,
    VoidCallback? onSaveCarLocation,
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
      ),
    );
  }

  @override
  State<ParcelBottomSheet> createState() => _ParcelBottomSheetState();
}

class _ParcelBottomSheetState extends State<ParcelBottomSheet> {
  late int _selectedMonth;
  late List<MushroomMatchResult> _currentMatches;
  bool _showAllMushrooms = false;

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
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // === FOREST DATA AVAILABLE ===
              if (parcel != null) ...[
                // Title row: tree species + status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${parcel.primarySpecies.icon} ${parcel.primarySpecies.namePl}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${parcel.inspectorate} • ${parcel.ageYears} lat',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (parcel.secondarySpecies.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Text(
                                'Skład: ${parcel.compositionSummary}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: parcel.status.color.withValues(alpha: 0.15),
                        border: Border.all(
                          color: parcel.status.color.withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            parcel.status.code == 'GOSP'
                                ? Icons.check_circle_outline
                                : Icons.block,
                            size: 14,
                            color: parcel.status.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            parcel.status.code == 'GOSP' ? 'ZBIÓR OK' : 'ZAKAZ!',
                            style: TextStyle(
                              color: parcel.status.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
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
                ..._buildMushroomList(),

                const SizedBox(height: 16),

                // Save Car Parking button
                if (widget.onSaveCarLocation != null)
                  OutlinedButton.icon(
                    onPressed: widget.onSaveCarLocation,
                    icon: const Icon(
                      Icons.directions_car,
                      color: AppColors.goldAmber,
                      size: 18,
                    ),
                    label: const Text(
                      'Zapisz pozycję auta',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
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

  List<Widget> _buildMushroomList() {
    if (_currentMatches.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Brak danych do oceny grzybów.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ];
    }

    final topItems = _currentMatches.take(3).toList();
    final restItems = _currentMatches.skip(3).toList();

    final widgets = <Widget>[];
    for (final m in topItems) {
      widgets.add(MushroomCard(result: m));
    }

    if (restItems.isNotEmpty) {
      if (_showAllMushrooms) {
        for (final m in restItems) {
          widgets.add(MushroomCard(result: m));
        }
        widgets.add(
          TextButton(
            onPressed: () => setState(() => _showAllMushrooms = false),
            child: const Text(
              'Zwiń listę ▲',
              style: TextStyle(color: AppColors.textDim, fontSize: 12),
            ),
          ),
        );
      } else {
        widgets.add(
          TextButton(
            onPressed: () => setState(() => _showAllMushrooms = true),
            child: Text(
              'Pokaż jeszcze ${restItems.length} gatunków ▼',
              style: const TextStyle(
                color: AppColors.emeraldNeon,
                fontSize: 12,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}
