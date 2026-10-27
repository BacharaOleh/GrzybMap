import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mushroom_radar/data/mushroom_database.dart';
import '../../domain/models/foraging_spot.dart';
import '../controllers/foraging_journal_controller.dart';

/// Modal bottom sheet allowing users to record a secret mushroom find.
class SaveSpotDialog extends ConsumerStatefulWidget {
  final LatLng location;
  final String? forestParcelId;
  final String? preselectedMushroomId;
  final String? defaultTitle;

  const SaveSpotDialog({
    super.key,
    required this.location,
    this.forestParcelId,
    this.preselectedMushroomId,
    this.defaultTitle,
  });

  static Future<bool?> show({
    required BuildContext context,
    required LatLng location,
    String? forestParcelId,
    String? preselectedMushroomId,
    String? defaultTitle,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SaveSpotDialog(
        location: location,
        forestParcelId: forestParcelId,
        preselectedMushroomId: preselectedMushroomId,
        defaultTitle: defaultTitle,
      ),
    );
  }

  @override
  ConsumerState<SaveSpotDialog> createState() => _SaveSpotDialogState();
}

class _SaveSpotDialogState extends ConsumerState<SaveSpotDialog> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late String _selectedMushroomId;
  double _quantity = 1.0;
  String _unit = 'kg'; // 'kg' or 'szt.'

  @override
  void initState() {
    super.initState();
    _selectedMushroomId = widget.preselectedMushroomId ??
        MushroomDatabase.allMushrooms.first.id;

    final defaultMushroom = MushroomDatabase.allMushrooms.firstWhere(
      (m) => m.id == _selectedMushroomId,
      orElse: () => MushroomDatabase.allMushrooms.first,
    );

    _titleController = TextEditingController(
      text: widget.defaultTitle ??
          (widget.forestParcelId != null
              ? '${defaultMushroom.namePl} (Wydzielenie ${widget.forestParcelId})'
              : 'Miejscówka: ${defaultMushroom.namePl}'),
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onMushroomChanged(String newId) {
    setState(() {
      _selectedMushroomId = newId;
      final m = MushroomDatabase.allMushrooms.firstWhere((x) => x.id == newId);
      if (_titleController.text.startsWith('Miejscówka:') ||
          _titleController.text.isEmpty) {
        _titleController.text = 'Miejscówka: ${m.namePl}';
      }
    });
  }

  void _submit() {
    final title = _titleController.text.trim().isEmpty
        ? 'Moja miejscówka'
        : _titleController.text.trim();

    final mushroom = MushroomDatabase.allMushrooms.firstWhere(
      (m) => m.id == _selectedMushroomId,
      orElse: () => MushroomDatabase.allMushrooms.first,
    );

    final spot = ForagingSpot(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      mushroomId: mushroom.id,
      mushroomName: mushroom.namePl,
      mushroomEmoji: '🍄',
      quantityAmount: _quantity,
      quantityUnit: _unit,
      latitude: widget.location.latitude,
      longitude: widget.location.longitude,
      foundAt: DateTime.now(),
      notes: _notesController.text.trim(),
      forestParcelId: widget.forestParcelId,
    );

    ref.read(foragingJournalProvider.notifier).addSpot(spot);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 24,
      ),
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
      child: SingleChildScrollView(
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

            // Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.emeraldDeep.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.emeraldNeon.withValues(alpha: 0.4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('📍', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zapisz sekretne miejsce',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Zapisywane tylko lokalnie na Twoim urządzeniu',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.emeraldNeon,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textDim),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Spot Title Field
            const Text(
              'NAZWA MIEJSCA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textDim,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.card,
                hintText: 'np. Moja polana pod dębami',
                hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.emeraldNeon),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Mushroom species picker
            const Text(
              'ZNALEZIONY GATUNEK GRZYBA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textDim,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMushroomId,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceElevated,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textDim),
                  items: MushroomDatabase.allMushrooms.map((m) {
                    return DropdownMenuItem<String>(
                      value: m.id,
                      child: Row(
                        children: [
                          const Text('🍄', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              m.namePl,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) _onMushroomChanged(val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Quantity & Unit
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ILOŚĆ / ZBIÓR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDim,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () {
                                if (_quantity > (_unit == 'kg' ? 0.5 : 1)) {
                                  setState(() {
                                    _quantity -= (_unit == 'kg' ? 0.5 : 1);
                                  });
                                }
                              },
                              icon: const Icon(Icons.remove, size: 18, color: Colors.white),
                            ),
                            Text(
                              _quantity == _quantity.roundToDouble()
                                  ? _quantity.toInt().toString()
                                  : _quantity.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _quantity += (_unit == 'kg' ? 0.5 : 1);
                                });
                              },
                              icon: const Icon(Icons.add, size: 18, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'JEDNOSTKA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDim,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _unit = 'kg';
                                  _quantity = 1.0;
                                }),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _unit == 'kg'
                                        ? AppColors.emeraldDeep
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'kg',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _unit == 'kg'
                                          ? Colors.white
                                          : AppColors.textDim,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _unit = 'szt.';
                                  _quantity = 5.0;
                                }),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _unit == 'szt.'
                                        ? AppColors.emeraldDeep
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'szt.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _unit == 'szt.'
                                          ? Colors.white
                                          : AppColors.textDim,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Notes field
            const Text(
              'NOTATKI / WSKAZÓWKI (OPCJONALNIE)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textDim,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.card,
                hintText: 'np. Za starym rowem, na skraju mchów po ulewie...',
                hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.emeraldNeon),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.bookmark_add_rounded, size: 20),
                label: const Text(
                  'Zapisz w Dzienniku',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldNeon,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.emeraldNeon.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
