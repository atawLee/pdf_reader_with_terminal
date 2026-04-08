import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recent_file.dart';

// ── SharedPreferences ──────────────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

// ── Current PDF path ───────────────────────────────────────────────────────
final currentPdfPathProvider = StateProvider<String?>((ref) => null);

// ── Recent files ──────────────────────────────────────────────────────────
class RecentFilesNotifier extends StateNotifier<List<RecentFile>> {
  RecentFilesNotifier(this._prefs) : super([]) {
    _load();
  }

  final SharedPreferences _prefs;
  static const _key = 'recent_files';

  void _load() {
    final raw = _prefs.getStringList(_key) ?? [];
    state = raw
        .map((s) => RecentFile.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(String path, String name) async {
    final updated = [
      RecentFile(path: path, name: name, openedAt: DateTime.now()),
      ...state.where((f) => f.path != path),
    ].take(20).toList();
    state = updated;
    await _prefs.setStringList(
      _key,
      updated.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }

  Future<void> remove(String path) async {
    final updated = state.where((f) => f.path != path).toList();
    state = updated;
    await _prefs.setStringList(
      _key,
      updated.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }

  Future<void> clear() async {
    state = [];
    await _prefs.remove(_key);
  }
}

final recentFilesProvider =
    StateNotifierProvider<RecentFilesNotifier, List<RecentFile>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RecentFilesNotifier(prefs);
});

// ── Sidebar visibility ─────────────────────────────────────────────────────
final sidebarVisibleProvider = StateProvider<bool>((ref) => true);

// ── Current page (driven by PdfViewerController, mirrored here for UI) ────
final currentPageProvider = StateProvider<int>((ref) => 1);
final totalPagesProvider = StateProvider<int>((ref) => 0);
