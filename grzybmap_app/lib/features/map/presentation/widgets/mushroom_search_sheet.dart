import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../mushroom_radar/data/mushroom_database.dart';
import '../../../mushroom_radar/domain/models.dart';
import 'mushroom_photo_widget.dart';

/// Modal bottom sheet allowing the user to search and filter mushroom targets
/// with instant multi-language search (Polish, Russian, Latin), category chips,
/// authentic botanical photos, and a quick reset option.
class MushroomSearchSheet extends StatefulWidget {
  final String? currentTargetId;

  const MushroomSearchSheet({
    super.key,
    this.currentTargetId,
  });

  /// Opens the search sheet and returns the selected mushroom id (or null for "all species").
  static Future<String?> show(BuildContext context, {String? currentTargetId}) {
    return showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MushroomSearchSheet(currentTargetId: currentTargetId),
    );
  }

  @override
  State<MushroomSearchSheet> createState() => _MushroomSearchSheetState();
}

class _MushroomSearchSheetState extends State<MushroomSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Wszystkie';

  static const List<String> _categories = [
    'Wszystkie',
    'Borowiki',
    'Kurki (Pieprzniki)',
    'Podgrzybki',
    'Koźlarze',
    'Maślaki',
    'Mleczaje (Rydze)',
    'Inne jadalne',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  bool _matchesCategory(Mushroom m, String category) {
    if (category == 'Wszystkie') return true;
    final lowerPl = m.namePl.toLowerCase();
    final lowerLatin = m.latin.toLowerCase();
    switch (category) {
      case 'Borowiki':
        return lowerPl.contains('borowik') || lowerLatin.contains('boletus') || m.id.contains('borowik');
      case 'Kurki (Pieprzniki)':
        return lowerPl.contains('pieprznik') || lowerPl.contains('kurka') || lowerLatin.contains('cantharellus') || m.id.contains('pieprznik');
      case 'Podgrzybki':
        return lowerPl.contains('podgrzybek') || lowerLatin.contains('imeria') || lowerLatin.contains('xerocomus') || m.id.contains('podgrzybek');
      case 'Koźlarze':
        return lowerPl.contains('koźlarz') || lowerLatin.contains('leccinum') || m.id.contains('kozlarz');
      case 'Maślaki':
        return lowerPl.contains('maślak') || lowerLatin.contains('suillus') || m.id.contains('maslak');
      case 'Mleczaje (Rydze)':
        return lowerPl.contains('mleczaj') || lowerPl.contains('rydz') || lowerLatin.contains('lactarius') || m.id.contains('mleczaj');
      case 'Inne jadalne':
        return !lowerPl.contains('borowik') &&
            !lowerPl.contains('pieprznik') &&
            !lowerPl.contains('podgrzybek') &&
            !lowerPl.contains('koźlarz') &&
            !lowerPl.contains('maślak') &&
            !lowerPl.contains('mleczaj');
      default:
        return true;
    }
  }

  List<Mushroom> _filteredMushrooms() {
    final query = _searchController.text.trim().toLowerCase();

    return MushroomDatabase.allMushrooms.where((m) {
      // Category filter
      if (!_matchesCategory(m, _selectedCategory)) return false;

      // Search query filter (matches Polish, Russian, and Latin botanical names)
      if (query.isNotEmpty) {
        final matchesPl = m.namePl.toLowerCase().contains(query);
        final matchesRu = m.nameRu.toLowerCase().contains(query);
        final matchesLatin = m.latin.toLowerCase().contains(query);
        final matchesDesc = m.descriptionPl.toLowerCase().contains(query);
        return matchesPl || matchesRu || matchesLatin || matchesDesc;
      }

      return true;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final filtered = _filteredMushrooms();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            offset: Offset(0, -4),
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
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldNeon.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.emeraldNeon.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🎯', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cel poszukiwań radaru',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Wybierz grzyba, aby skalibrować radar pod ten gatunek',
                          style: TextStyle(fontSize: 11, color: AppColors.textDim),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textDim),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _searchController.text.isNotEmpty
                        ? AppColors.emeraldNeon.withValues(alpha: 0.6)
                        : AppColors.borderLight,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: AppColors.emeraldNeon,
                  decoration: InputDecoration(
                    hintText: 'Wpisz nazwę (np. Borowik, Kurka, Prawdziwek, Белый)...',
                    hintStyle: const TextStyle(
                      color: AppColors.textDim,
                      fontSize: 12.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.emeraldNeon,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textDim),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Category Chips (Horizontal scroll)
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == _selectedCategory;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.emeraldNeon.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.emeraldNeon
                              : AppColors.borderLight,
                          width: isSelected ? 1.2 : 0.8,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.emeraldNeon : AppColors.textMuted,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            const Divider(color: AppColors.borderLight, height: 1),

            // List of mushrooms + All species option
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                children: [
                  // Option: All species (General mode)
                  if (_searchController.text.isEmpty && _selectedCategory == 'Wszystkie')
                    _buildAllSpeciesTile(context),

                  if (filtered.isEmpty)
                    _buildEmptyState()
                  else
                    ...filtered.map((m) => _buildMushroomTile(context, m)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllSpeciesTile(BuildContext context) {
    final isSelected = widget.currentTargetId == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.emeraldNeon.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.emeraldNeon : AppColors.borderLight,
          width: isSelected ? 1.2 : 0.8,
        ),
      ),
      child: ListTile(
        onTap: () => Navigator.of(context).pop('__ALL__'),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.goldAmber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.goldAmber.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: const Text('✨', style: TextStyle(fontSize: 22)),
        ),
        title: const Text(
          'Wszystkie gatunki (Tryb ogólny)',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        subtitle: const Text(
          'Radar skanuje las pod kątem wszystkich 18 gatunków grzybów',
          style: TextStyle(fontSize: 11, color: AppColors.textDim),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded, color: AppColors.emeraldNeon, size: 22)
            : const Icon(Icons.radio_button_off_rounded, color: AppColors.textDim, size: 20),
      ),
    );
  }

  Widget _buildMushroomTile(BuildContext context, Mushroom m) {
    final isSelected = widget.currentTargetId == m.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.emeraldNeon.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.emeraldNeon : AppColors.borderLight,
          width: isSelected ? 1.2 : 0.8,
        ),
      ),
      child: ListTile(
        onTap: () => Navigator.of(context).pop(m.id),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: MushroomPhotoWidget(
          assetPath: m.photoAsset,
          fallbackEmoji: m.badge,
          size: 44,
          borderRadius: 10,
          borderColor: isSelected ? AppColors.emeraldNeon : AppColors.borderLight,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                m.namePl,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: m.edibilityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: m.edibilityColor.withValues(alpha: 0.4), width: 0.6),
              ),
              child: Text(
                m.edibility.split(' ').first,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: m.edibilityColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${m.latin} • ${m.nameRu}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textDim,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '🌲 ${m.preferredTrees.take(3).join(', ')}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded, color: AppColors.emeraldNeon, size: 22)
            : const Icon(Icons.chevron_right_rounded, color: AppColors.textDim, size: 20),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🔍', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 14),
          Text(
            'Nie znaleziono grzyba dla „${_searchController.text}”',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Sprawdź pisownię lub wybierz inną kategorię z paska powyżej.',
            style: TextStyle(fontSize: 12, color: AppColors.textDim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _selectedCategory = 'Wszystkie';
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.emeraldNeon),
            label: const Text(
              'Wyczyść filtry',
              style: TextStyle(color: AppColors.emeraldNeon, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
