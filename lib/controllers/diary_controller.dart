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
  bool _disposed = false;
  int _generation = 0;

  bool _live(int generation) => !_disposed && generation == _generation;

  Future<void> load({bool silent = false}) async {
    final token = _token()?.trim();
    if (loading || token == null || token.isEmpty) return;
    final generation = _generation;
    loading = true;
    if (!silent) error = null;
    notifyListeners();
    try {
      final result = await _backend().loadDiaryList(token: token);
      if (!_live(generation)) return;
      entries
        ..clear()
        ..addAll(result);
      loaded = true;
      error = null;
    } on BackendException catch (e) {
      if (!_live(generation)) return;
      error = e.message;
    } catch (e) {
      if (!_live(generation)) return;
      error = e.toString();
    } finally {
      if (_live(generation)) {
        loading = false;
        notifyListeners();
      }
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
    _generation++;
    entries.clear();
    error = null;
    loading = false;
    loaded = false;
    notifyListeners();
  }

  void invalidateForIdentityChange() => clear();

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
