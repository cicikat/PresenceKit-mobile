import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../services/backend_client.dart';

/// Owns the profile page's one-shot activity and mood snapshot.
///
/// A failed refresh deliberately retains the last successful values so the UI
/// can identify them as stale instead of presenting them as current.
class ProfileStatusController extends ChangeNotifier {
  ProfileStatusController({
    required BackendClient Function() backend,
    required String? Function() token,
    String? Function()? charId,
  }) : _backend = backend,
       _token = token,
       _charId = charId ?? (() => null);

  final BackendClient Function() _backend;
  final String? Function() _token;
  final String? Function() _charId;

  ActivityCurrentState? activityCurrent;
  MoodStateSnapshot? moodState;
  DateTime? lastSuccessfulAt;
  String? error;
  bool loading = false;
  bool _disposed = false;
  int _generation = 0;

  String? get _accessToken {
    final value = _token()?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get isStale => error != null && lastSuccessfulAt != null;

  bool _live(int generation) => !_disposed && generation == _generation;

  Future<void> load() async {
    final token = _accessToken;
    if (loading || token == null) return;
    final generation = _generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final charId = _charId();
      final results = await Future.wait([
        _backend().loadActivityCurrent(token: token, charId: charId),
        _backend().loadMoodState(token: token, charId: charId),
      ]);
      if (!_live(generation)) return;
      activityCurrent = results[0] as ActivityCurrentState;
      moodState = results[1] as MoodStateSnapshot;
      lastSuccessfulAt = DateTime.now();
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

  void invalidateForIdentityChange() {
    _generation++;
    activityCurrent = null;
    moodState = null;
    lastSuccessfulAt = null;
    error = null;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
