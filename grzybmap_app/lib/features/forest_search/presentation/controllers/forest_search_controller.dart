import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../domain/models.dart';
import '../../domain/repositories/forest_search_repository.dart';

class ForestSearchState {
  final String query;
  final List<ForestSearchResult> results;
  final bool isLoading;
  final bool isOpen;
  final ForestSearchResult? selectedPlace;

  const ForestSearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.isOpen = false,
    this.selectedPlace,
  });

  ForestSearchState copyWith({
    String? query,
    List<ForestSearchResult>? results,
    bool? isLoading,
    bool? isOpen,
    ForestSearchResult? selectedPlace,
    bool clearSelectedPlace = false,
  }) {
    return ForestSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isOpen: isOpen ?? this.isOpen,
      selectedPlace: clearSelectedPlace ? null : (selectedPlace ?? this.selectedPlace),
    );
  }
}

class ForestSearchNotifier extends StateNotifier<ForestSearchState> {
  final ForestSearchRepository _repository;
  Timer? _debounceTimer;

  ForestSearchNotifier(this._repository) : super(const ForestSearchState());

  void openSearch() {
    state = state.copyWith(isOpen: true);
  }

  void closeSearch() {
    _debounceTimer?.cancel();
    state = state.copyWith(isOpen: false);
  }

  void onQueryChanged(String query) {
    state = state.copyWith(query: query, isOpen: true);
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      state = state.copyWith(results: const [], isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _repository.search(query);
        if (mounted) {
          state = state.copyWith(results: results, isLoading: false);
        }
      } catch (e) {
        if (mounted) {
          state = state.copyWith(isLoading: false);
        }
      }
    });
  }

  void clearQuery() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      query: '',
      results: const [],
      isLoading: false,
      isOpen: false,
    );
  }

  void selectPlace(ForestSearchResult place) {
    _debounceTimer?.cancel();
    state = state.copyWith(
      isOpen: false,
      selectedPlace: place,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final forestSearchProvider =
    StateNotifierProvider<ForestSearchNotifier, ForestSearchState>((ref) {
  final repository = ref.watch(forestSearchRepositoryProvider);
  return ForestSearchNotifier(repository);
});
