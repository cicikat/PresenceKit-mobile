import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../services/backend_client.dart';

class DiaryController extends ChangeNotifier {
  DiaryController({
    required BackendClient Function() backend,
    required String? Function() token,
  }) : _backend = backend,
       _token = token;

  final BackendClient Function() _backend;
  final String? Function() _token;
  final List<DiaryListItem> entries = [];
  String? error;
  bool loading = false;
  bool loaded = false;

  Future<void> load({bool silent = false}) async {
    final token = _token()?.trim();
    if (loading || token == null || token.isEmpty) return;
    loading = true;
    if (!silent) error = null;
    notifyListeners();
    try {
      final result = await _backend().loadDiaryList(token: token);
      entries
        ..clear()
        ..addAll(result);
      loaded = true;
      error = null;
    } on BackendException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<DiaryDetail> loadEntry(String date) {
    final token = _token()?.trim();
    if (token == null || token.isEmpty) {
      throw const BackendException('Please enter an access credential first');
    }
    return _backend().loadDiaryEntry(date, token: token);
  }

  void clear() {
    entries.clear();
    error = null;
    loading = false;
    loaded = false;
    notifyListeners();
  }
}
