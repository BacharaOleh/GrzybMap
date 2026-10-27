import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/foraging_journal_service.dart';
import '../../domain/models/foraging_spot.dart';

/// Immutable state for the private foraging journal.
class ForagingJournalState {
  final List<ForagingSpot> spots;
  final bool isLayerVisible;
  final String? filterMushroomId;
  final int? filterYear;
  final bool isLoading;

  const ForagingJournalState({
    this.spots = const [],
    this.isLayerVisible = true,
    this.filterMushroomId,
    this.filterYear,
    this.isLoading = false,
  });

  /// Spots filtered by selected mushroom species and year.
  List<ForagingSpot> get filteredSpots {
    return spots.where((s) {
      if (filterMushroomId != null && s.mushroomId != filterMushroomId) {
        return false;
      }
      if (filterYear != null && s.foundAt.year != filterYear) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  int get totalSpotsCount => spots.length;

  /// Approximate total weight in kg (converting pieces @ ~0.05kg each).
  double get estimatedTotalKg {
    return spots.fold<double>(0.0, (acc, s) {
      if (s.quantityUnit == 'kg') return acc + s.quantityAmount;
      return acc + (s.quantityAmount * 0.05);
    });
  }

  ForagingJournalState copyWith({
    List<ForagingSpot>? spots,
    bool? isLayerVisible,
    String? filterMushroomId,
    bool clearMushroomFilter = false,
    int? filterYear,
    bool clearYearFilter = false,
    bool? isLoading,
  }) {
    return ForagingJournalState(
      spots: spots ?? this.spots,
      isLayerVisible: isLayerVisible ?? this.isLayerVisible,
      filterMushroomId: clearMushroomFilter
          ? null
          : (filterMushroomId ?? this.filterMushroomId),
      filterYear:
          clearYearFilter ? null : (filterYear ?? this.filterYear),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier managing user's secret mushroom spots and privacy toggles.
class ForagingJournalNotifier extends StateNotifier<ForagingJournalState> {
  final ForagingJournalService _service;

  ForagingJournalNotifier(this._service) : super(const ForagingJournalState()) {
    loadSpots();
  }

  Future<void> loadSpots() async {
    state = state.copyWith(isLoading: true);
    await _service.init();
    final spots = _service.getSpots();
    final layerVis = _service.isLayerVisible();
    state = state.copyWith(
      spots: spots,
      isLayerVisible: layerVis,
      isLoading: false,
    );
  }

  Future<void> addSpot(ForagingSpot spot) async {
    final updated = await _service.saveSpot(spot);
    state = state.copyWith(spots: updated);
  }

  Future<void> deleteSpot(String spotId) async {
    final updated = await _service.deleteSpot(spotId);
    state = state.copyWith(spots: updated);
  }

  Future<void> toggleLayerVisibility() async {
    final next = !state.isLayerVisible;
    await _service.setLayerVisible(next);
    state = state.copyWith(isLayerVisible: next);
  }

  void setFilterMushroom(String? mushroomId) {
    if (mushroomId == null) {
      state = state.copyWith(clearMushroomFilter: true);
    } else {
      state = state.copyWith(filterMushroomId: mushroomId);
    }
  }

  void setFilterYear(int? year) {
    if (year == null) {
      state = state.copyWith(clearYearFilter: true);
    } else {
      state = state.copyWith(filterYear: year);
    }
  }
}

/// Provider for ForagingJournalService
final foragingJournalServiceProvider = Provider<ForagingJournalService>((ref) {
  final service = ForagingJournalService();
  service.init();
  return service;
});

/// Provider for the ForagingJournalNotifier and its state
final foragingJournalProvider =
    StateNotifierProvider<ForagingJournalNotifier, ForagingJournalState>((ref) {
  final service = ref.watch(foragingJournalServiceProvider);
  return ForagingJournalNotifier(service);
});
