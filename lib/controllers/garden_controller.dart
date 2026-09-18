import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../services/backend_client.dart';

class GardenController extends ChangeNotifier {
  GardenController({
    required BackendClient Function() backend,
    required String? Function() token,
  }) : _backend = backend,
       _token = token;

  final BackendClient Function() _backend;
  final String? Function() _token;
  Timer? _refreshTimer;
  GardenState? state;
  String? error;
  bool loading = false;
  bool _disposed = false;
  int _generation = 0;

  bool _live(int generation) => !_disposed && generation == _generation;

  Future<void> start() async {
    if (_disposed) return;
    if (_refreshTimer != null) {
      unawaited(load(silent: true));
      return;
    }
    unawaited(load());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(load(silent: true)),
    );
  }

  void stop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> load({bool silent = false}) async {
    final token = _token()?.trim();
    if (loading || token == null || token.isEmpty) return;
    final generation = _generation;
    loading = true;
    if (!silent) error = null;
    notifyListeners();
    try {
      final loaded = await _backend().loadGardenState(token: token);
      if (!_live(generation)) return;
      state = loaded;
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

  void clear() {
    _generation++;
    state = null;
    error = null;
    loading = false;
    notifyListeners();
  }

  void invalidateForIdentityChange() {
    stop();
    clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    stop();
    super.dispose();
  }
}
