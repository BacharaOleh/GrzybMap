import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/report_model.dart';

class ForestReportsState {
  final List<ForestReport> reports;
  final bool isLoading;
  final String? errorMessage;

  const ForestReportsState({
    this.reports = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ForestReportsState copyWith({
    List<ForestReport>? reports,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ForestReportsState(
      reports: reports ?? this.reports,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ForestReportsNotifier extends StateNotifier<ForestReportsState> {
  static const String _storageKey = 'grzybmap_local_forest_reports_v1';
  final Dio _dio;

  ForestReportsNotifier({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
              ),
            ),
        super(const ForestReportsState()) {
    loadReports();
  }

  Future<void> loadReports() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString(_storageKey);
      List<ForestReport> localReports = [];
      if (localJson != null) {
        final decoded = jsonDecode(localJson);
        if (decoded is List) {
          localReports = decoded
              .map((item) => ForestReport.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }

      // Try fetching from local Node.js backend if available
      try {
        final res = await _dio.get<dynamic>('/api/reports');
        if (res.statusCode == 200 && res.data != null) {
          final serverData = res.data is String
              ? jsonDecode(res.data as String)
              : res.data;
          if (serverData is List) {
            final serverReports = serverData
                .map((item) => ForestReport.fromJson(item as Map<String, dynamic>))
                .toList();

            // Merge without duplicates
            final Map<String, ForestReport> map = {};
            for (final r in localReports) {
              map[r.id] = r;
            }
            for (final r in serverReports) {
              map[r.id] = r;
            }
            state = state.copyWith(
              reports: map.values.toList(),
              isLoading: false,
            );
            return;
          }
        }
      } catch (_) {
        // Fallback to local reports when offline
      }

      state = state.copyWith(reports: localReports, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> submitReport(ForestReport report) async {
    state = state.copyWith(isLoading: true);

    // 1. Immediately store in local state for optimistic UI & offline safety
    final updated = [report, ...state.reports];
    state = state.copyWith(reports: updated, isLoading: false);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(updated.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}

    // 2. Try pushing to remote backend
    try {
      final res = await _dio.post<dynamic>(
        '/api/reports',
        data: report.toJson(),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      // Saved locally in offline queue
      return true;
    }
  }

  void addConfirmation(String reportId) {
    final updated = state.reports.map((r) {
      if (r.id == reportId) {
        return ForestReport(
          id: r.id,
          category: r.category,
          latitude: r.latitude,
          longitude: r.longitude,
          nadlesnictwo: r.nadlesnictwo,
          oddzial: r.oddzial,
          description: r.description,
          photoUrl: r.photoUrl,
          photoBase64: r.photoBase64,
          status: r.status,
          createdAt: r.createdAt,
          confirmationsCount: r.confirmationsCount + 1,
        );
      }
      return r;
    }).toList();

    state = state.copyWith(reports: updated);

    // Also notify server in background if possible
    _syncConfirmation(
      reportId,
      state.reports.firstWhere((r) => r.id == reportId).confirmationsCount,
    );
  }

  Future<void> _syncConfirmation(String reportId, int count) async {
    try {
      await _dio.patch<dynamic>(
        '/api/reports/$reportId',
        data: {'confirmationsCount': count},
      );
    } catch (_) {}
  }
}

final forestReportsProvider =
    StateNotifierProvider<ForestReportsNotifier, ForestReportsState>((ref) {
  return ForestReportsNotifier();
});
