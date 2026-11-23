import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../parcel_inspector/domain/models.dart';
import '../data/report_repository.dart';
import '../domain/report_model.dart';

/// Modal bottom sheet for reporting environmental incidents, illegal dumps,
/// or blocked fire roads directly to local Polish forest districts (Nadleśnictwo).
class ForestReportSheet extends ConsumerStatefulWidget {
  final LatLng location;
  final ForestParcel? parcel;

  const ForestReportSheet({
    super.key,
    required this.location,
    required this.parcel,
  });

  /// Displays the modal sheet.
  static Future<bool?> show({
    required BuildContext context,
    required LatLng location,
    required ForestParcel? parcel,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ForestReportSheet(
        location: location,
        parcel: parcel,
      ),
    );
  }

  @override
  ConsumerState<ForestReportSheet> createState() => _ForestReportSheetState();
}

class _ForestReportSheetState extends ConsumerState<ForestReportSheet> {
  ForestReportCategory _selectedCategory = ForestReportCategory.trash;
  final TextEditingController _descController = TextEditingController();
  bool _hasPhoto = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await HapticFeedback.mediumImpact();

    final report = ForestReport(
      id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      category: _selectedCategory,
      latitude: widget.location.latitude,
      longitude: widget.location.longitude,
      nadlesnictwo: widget.parcel?.inspectorate ?? 'Nadleśnictwo w rejonie',
      oddzial: widget.parcel?.subareaId ?? 'Współrzędne GPS',
      description: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : _selectedCategory.labelPl,
      photoUrl: _hasPhoto ? 'assets/icons/report_sample.jpg' : null,
      createdAt: DateTime.now(),
    );

    final success = await ref
        .read(forestReportsProvider.notifier)
        .submitReport(report);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.of(context).pop(success);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.emeraldNeon, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Zgłoszenie przyjęte: ${_selectedCategory.shortLabel}. Dziękujemy za troskę o las!',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10281C),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderActive),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
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
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.amberWarn.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.amberWarn.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: AppColors.amberWarn,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eko-Zgłoszenie w lesie',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Powiadom leśniczych o zagrożeniu lub śmieciach',
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
                    // Location context pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.park_rounded, size: 18, color: AppColors.emeraldNeon),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'LOKALIZACJA ZDARZENIA',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.emeraldNeon,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.parcel?.address.isNotEmpty == true
                                      ? widget.parcel!.address
                                      : 'GPS: ${widget.location.latitude.toStringAsFixed(4)}, ${widget.location.longitude.toStringAsFixed(4)}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section 1: Category Selection
                    const Text(
                      'Typ incydentu',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ForestReportCategory.values.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return ChoiceChip(
                          showCheckmark: false,
                          avatar: Icon(
                            cat.iconData,
                            size: 16,
                            color: isSelected ? Colors.white : cat.color,
                          ),
                          label: Text(
                            cat.shortLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.textMain,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: cat.color.withValues(alpha: 0.85),
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            side: BorderSide(
                              color: isSelected
                                  ? cat.color
                                  : Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedCategory = cat);
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Section 2: Photo Attachment Button
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _hasPhoto = !_hasPhoto);
                      },
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _hasPhoto
                              ? AppColors.emeraldDeep.withValues(alpha: 0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(
                            color: _hasPhoto
                                ? AppColors.emeraldNeon.withValues(alpha: 0.5)
                                : AppColors.borderLight,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _hasPhoto
                                    ? AppColors.emeraldNeon.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _hasPhoto
                                    ? Icons.check_circle_rounded
                                    : Icons.add_a_photo_rounded,
                                size: 20,
                                color: _hasPhoto
                                    ? AppColors.emeraldNeon
                                    : AppColors.textDim,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _hasPhoto
                                        ? 'Zdjęcie dołączone (kompresja ~200 KB)'
                                        : 'Dołącz zdjęcie z aparatu',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: _hasPhoto ? Colors.white : AppColors.textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _hasPhoto
                                        ? 'Kliknij, aby usunąć załącznik'
                                        : 'Pomaga leśniczemu ocenić gabaryty śmieci lub powalonego pnia',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section 3: Description Field
                    const Text(
                      'Opis sytuacji (opcjonalnie)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: _descController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'np. 3 opony w rowie przy drodze pożarowej nr 4...',
                        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textDim),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          borderSide: const BorderSide(color: AppColors.emeraldNeon),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldDeep,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          side: BorderSide(
                            color: AppColors.emeraldNeon.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Wyślij zgłoszenie do leśnictwa',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
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
