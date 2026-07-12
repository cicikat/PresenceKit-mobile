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

  Future<void> start() async {
    _refreshTimer?.cancel();
    unawaited(load());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(load(silent: true)),
    );
  }

  void stop() => _refreshTimer?.cancel();

  Future<void> load({bool silent = false}) async {
    final token = _token()?.trim();
    if (loading || token == null || token.isEmpty) return;
    loading = true;
    if (!silent) error = null;
    notifyListeners();
    try {
      state = await _backend().loadGardenState(token: token);
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

  void clear() {
    state = null;
    error = null;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
