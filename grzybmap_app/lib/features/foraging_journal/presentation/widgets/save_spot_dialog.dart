import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../map/presentation/widgets/mushroom_photo_widget.dart';
import '../../../mushroom_radar/data/mushroom_database.dart';
import '../../domain/models/foraging_spot.dart';
import '../controllers/foraging_journal_controller.dart';

/// Modal bottom sheet allowing users to record a secret mushroom find.
class SaveSpotDialog extends ConsumerStatefulWidget {
  final LatLng location;
  final String? forestParcelId;
  final String? preselectedMushroomId;
  final String? defaultTitle;
  final String? initialPhotoBase64;

  const SaveSpotDialog({
    super.key,
    required this.location,
    this.forestParcelId,
    this.preselectedMushroomId,
    this.defaultTitle,
    this.initialPhotoBase64,
  });

  static Future<bool?> show({
    required BuildContext context,
    required LatLng location,
    String? forestParcelId,
    String? preselectedMushroomId,
    String? defaultTitle,
    String? initialPhotoBase64,
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
        initialPhotoBase64: initialPhotoBase64,
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
  String? _photoBase64;

  @override
  void initState() {
    super.initState();
    _photoBase64 = widget.initialPhotoBase64;
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

  Future<void> _openSpeciesPicker(BuildContext context) async {
    unawaited(HapticFeedback.selectionClick());
    final pickedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SpeciesPickerSheet(
        selectedMushroomId: _selectedMushroomId,
      ),
    );

    if (pickedId != null && pickedId != _selectedMushroomId) {
      _onMushroomChanged(pickedId);
    }
  }

  Future<void> _pickPhoto() async {
    unawaited(HapticFeedback.selectionClick());
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Dodaj zdjęcie znaleziska',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldNeon.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, color: AppColors.emeraldNeon),
                ),
                title: const Text('Zrób zdjęcie (Aparat)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Uruchom aparat fotograficzny', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              const Divider(color: AppColors.borderLight, height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.emeraldLight),
                ),
                title: const Text('Wybierz z galerii', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Wybierz zapisane zdjęcie z pamięci urządzenia', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        if (mounted) {
          setState(() {
            _photoBase64 = base64Str;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd podczas wybierania zdjęcia: $e'),
            backgroundColor: AppColors.card,
          ),
        );
      }
    }
  }

  void _submit() {
    unawaited(HapticFeedback.mediumImpact());
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
      photoPath: _photoBase64,
    );

    ref.read(foragingJournalProvider.notifier).addSpot(spot);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentMushroom = MushroomDatabase.allMushrooms.firstWhere(
      (m) => m.id == _selectedMushroomId,
      orElse: () => MushroomDatabase.allMushrooms.first,
    );

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
        border: Border.all(color: AppColors.borderLight),
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
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.emeraldDeep.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.emeraldNeon.withValues(alpha: 0.4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.bookmark_add_rounded,
                    size: 22,
                    color: AppColors.emeraldNeon,
                  ),
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
              'Nazwa miejsca',
              style: AppTypography.labelSmall,
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
                prefixIcon: const Icon(
                  Icons.drive_file_rename_outline_rounded,
                  size: 18,
                  color: AppColors.textDim,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.emeraldNeon, width: 1.2),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Mushroom species picker (Interactive Selector Card)
            const Text(
              'Gatunek grzyba',
              style: AppTypography.labelSmall,
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _openSpeciesPicker(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    MushroomPhotoWidget(
                      assetPath: currentMushroom.photoAsset,
                      size: 40,
                      borderRadius: 8,
                      borderColor: AppColors.emeraldNeon.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentMushroom.namePl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentMushroom.latin,
                            style: TextStyle(
                              color: AppColors.emeraldLight.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Zmień',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.unfold_more_rounded, size: 14, color: AppColors.textDim),
                        ],
                      ),
                    ),
                  ],
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
                        'Wielkość zbioru',
                        style: AppTypography.labelSmall,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () {
                                if (_quantity > (_unit == 'kg' ? 0.5 : 1)) {
                                  HapticFeedback.selectionClick();
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
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
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
                        'Jednostka',
                        style: AppTypography.labelSmall,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_unit != 'kg') {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _unit = 'kg';
                                      _quantity = 1.0;
                                    });
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _unit == 'kg'
                                        ? AppColors.emeraldNeon.withValues(alpha: 0.18)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: _unit == 'kg'
                                        ? Border.all(
                                            color: AppColors.emeraldNeon.withValues(alpha: 0.6),
                                            width: 1.0,
                                          )
                                        : null,
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
                                onTap: () {
                                  if (_unit != 'szt.') {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _unit = 'szt.';
                                      _quantity = 5.0;
                                    });
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _unit == 'szt.'
                                        ? AppColors.emeraldNeon.withValues(alpha: 0.18)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: _unit == 'szt.'
                                        ? Border.all(
                                            color: AppColors.emeraldNeon.withValues(alpha: 0.6),
                                            width: 1.0,
                                          )
                                        : null,
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
              'Notatki i wskazówki (opcjonalnie)',
              style: AppTypography.labelSmall,
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
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Icon(Icons.sticky_note_2_rounded, size: 18, color: AppColors.textDim),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.emeraldNeon, width: 1.2),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Photo attachment section
            const Text(
              'Zdjęcie znaleziska (opcjonalnie)',
              style: AppTypography.labelSmall,
            ),
            const SizedBox(height: 6),
            if (_photoBase64 == null)
              InkWell(
                onTap: _pickPhoto,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.emeraldNeon.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_a_photo_rounded,
                          size: 20,
                          color: AppColors.emeraldNeon,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dodaj zdjęcie do znaleziska',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Zrób zdjęcie aparatem lub wybierz z galerii',
                              style: TextStyle(
                                color: AppColors.textDim,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: AppColors.emeraldNeon,
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.emeraldNeon.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    MushroomPhotoWidget(
                      assetPath: null,
                      base64Data: _photoBase64,
                      size: 54,
                      borderRadius: 10,
                      borderColor: AppColors.emeraldNeon,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 14, color: AppColors.emeraldNeon),
                              SizedBox(width: 4),
                              Text(
                                'Zdjęcie dołączone',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Zapisane w pamięci lokalnej',
                            style: TextStyle(
                              color: AppColors.textDim,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _pickPhoto,
                      child: const Text('Zmień',
                          style: TextStyle(
                              color: AppColors.emeraldLight, fontSize: 12)),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _photoBase64 = null);
                      },
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: Colors.redAccent),
                      tooltip: 'Usuń zdjęcie',
                    ),
                  ],
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

/// Upgraded Species Search and Selection Bottom Sheet
class _SpeciesPickerSheet extends StatefulWidget {
  final String selectedMushroomId;

  const _SpeciesPickerSheet({
    required this.selectedMushroomId,
  });

  @override
  State<_SpeciesPickerSheet> createState() => _SpeciesPickerSheetState();
}

class _SpeciesPickerSheetState extends State<_SpeciesPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const all = MushroomDatabase.allMushrooms;
    final filtered = _searchQuery.isEmpty
        ? all
        : all.where((m) {
            final q = _searchQuery.toLowerCase();
            return m.namePl.toLowerCase().contains(q) ||
                m.latin.toLowerCase().contains(q);
          }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 16,
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Wybierz gatunek grzyba',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: AppColors.textDim, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search Field
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.card,
              hintText: 'Szukaj gatunku (np. borowik, pieprznik)...',
              hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 12.5),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: AppColors.emeraldNeon,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textDim),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.emeraldNeon, width: 1.2),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Species List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 36,
                            color: AppColors.textDim.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Brak gatunków o tej nazwie',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: AppColors.borderLight,
                      height: 1,
                      indent: 56,
                    ),
                    itemBuilder: (context, index) {
                      final m = filtered[index];
                      final isSelected = m.id == widget.selectedMushroomId;

                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            Navigator.of(context).pop(m.id);
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          leading: MushroomPhotoWidget(
                            assetPath: m.photoAsset,
                            size: 42,
                            borderRadius: 8,
                            borderColor: isSelected
                                ? AppColors.emeraldNeon
                                : AppColors.borderLight,
                          ),
                          title: Text(
                            m.namePl,
                            style: TextStyle(
                              color: isSelected ? AppColors.emeraldNeon : Colors.white,
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.latin,
                                  style: const TextStyle(
                                    color: AppColors.textDim,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: m.edibilityColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  m.edibility,
                                  style: TextStyle(
                                    color: m.edibilityColor,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.emeraldNeon,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
