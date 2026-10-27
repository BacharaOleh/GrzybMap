import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models.dart';
import '../controllers/forest_search_controller.dart';

class ForestSearchBar extends ConsumerStatefulWidget {
  final void Function(ForestSearchResult place) onSelectPlace;

  const ForestSearchBar({
    super.key,
    required this.onSelectPlace,
  });

  @override
  ConsumerState<ForestSearchBar> createState() => _ForestSearchBarState();
}

class _ForestSearchBarState extends ConsumerState<ForestSearchBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        ref.read(forestSearchProvider.notifier).openSearch();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onClear() {
    _textController.clear();
    ref.read(forestSearchProvider.notifier).clearQuery();
    ref.read(forestSearchProvider.notifier).closeSearch();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ForestSearchState>(forestSearchProvider, (previous, next) {
      if (previous?.isOpen == true && !next.isOpen) {
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      }
    });

    final searchState = ref.watch(forestSearchProvider);
    final isOpen = searchState.isOpen;
    final results = searchState.results;
    final isLoading = searchState.isLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Outer Shell of Double-Bezel
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? AppColors.emeraldNeon.withValues(alpha: 0.6)
                  : AppColors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
              if (_focusNode.hasFocus)
                BoxShadow(
                  color: AppColors.emeraldNeon.withValues(alpha: 0.12),
                  blurRadius: 10,
                ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              // Leading Icon
              const Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.textDim,
              ),
              const SizedBox(width: 10),

              // Search Text Field
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  onChanged: (val) =>
                      ref.read(forestSearchProvider.notifier).onQueryChanged(val),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Szukaj puszczy, lasu, miasta...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.textDim,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),

              // Loading or Clear Button
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.emeraldNeon,
                    ),
                  ),
                )
              else if (_textController.text.isNotEmpty || isOpen)
                GestureDetector(
                  onTap: _onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 44,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textDim,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),

        // Dropdown Search Results Card (if open and has items)
        if (isOpen && results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        physics: const BouncingScrollPhysics(),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.border.withValues(alpha: 0.4),
                          indent: 48,
                        ),
                        itemBuilder: (context, index) {
                          final place = results[index];
                          return _SearchResultTile(
                            place: place,
                            onTap: () {
                              _focusNode.unfocus();
                              _textController.text = place.shortName;
                              ref.read(forestSearchProvider.notifier).selectPlace(place);
                              widget.onSelectPlace(place);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  final ForestSearchResult place;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.place,
    required this.onTap,
  });

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isForest = widget.place.isForest;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _isPressed
            ? AppColors.emeraldDeep.withValues(alpha: 0.3)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Icon wrapper in button-in-button style
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isForest
                    ? AppColors.emeraldDeep.withValues(alpha: 0.35)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isForest
                      ? AppColors.emeraldNeon.withValues(alpha: 0.3)
                      : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.place.iconEmoji,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),

            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.place.shortName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.place.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.place.subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDim,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Badge pill
            if (isForest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.emeraldNeon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LAS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emeraldNeon,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
