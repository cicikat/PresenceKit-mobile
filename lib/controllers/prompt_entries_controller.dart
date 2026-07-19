import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../services/backend_client.dart';

/// 世界书/破限条目状态,读写 desktop 同款 /lorebook /jailbreak-entries
/// (全量 CRUD,条目自带 enabled),不是 /settings/prompt-assets 的聚合字段。
class PromptEntriesController extends ChangeNotifier {
  PromptEntriesController({
    required BackendClient Function() backend,
    required String? Function() token,
  }) : _backend = backend,
       _token = token;

  final BackendClient Function() _backend;
  final String? Function() _token;

  List<LoreEntry> loreEntries = const [];
  List<JailbreakEntry> jailbreakEntries = const [];
  bool loading = false;
  bool saving = false;
  String? error;

  String? get _accessToken {
    final value = _token()?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> load() async {
    final token = _accessToken;
    if (loading || token == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _backend().loadLoreEntries(token: token),
        _backend().loadJailbreakEntries(token: token),
      ]);
      loreEntries = results[0] as List<LoreEntry>;
      jailbreakEntries = results[1] as List<JailbreakEntry>;
    } on BackendException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLore(String id) async {
    final token = _accessToken;
    final entry = loreEntries.where((item) => item.id == id).firstOrNull;
    if (saving || token == null || entry == null) return;
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _backend().setLoreEntryEnabled(
        token: token,
        entry: entry,
        enabled: !entry.enabled,
      );
      loreEntries = await _backend().loadLoreEntries(token: token);
    } on BackendException catch (e) {
      error = e.message;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> toggleJailbreak(String id) async {
    final token = _accessToken;
    final entry = jailbreakEntries.where((item) => item.id == id).firstOrNull;
    if (saving || token == null || entry == null) return;
    saving = true;
    error = null;
    notifyListeners();
    try {
      await _backend().setJailbreakEntryEnabled(
        token: token,
        entry: entry,
        enabled: !entry.enabled,
      );
      jailbreakEntries = await _backend().loadJailbreakEntries(token: token);
    } on BackendException catch (e) {
      error = e.message;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
