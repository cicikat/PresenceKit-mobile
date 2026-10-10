import 'package:flutter/foundation.dart';
import '../models/dream_appearance.dart';
import '../models/ui_layout.dart';

/// Local presentation only; ThemeController persists this through its JSON store.
class DreamAppearanceController extends ChangeNotifier {
  DreamAppearanceController({
    required Future<void> Function(DreamAppearanceSnapshot) persist,
  }) : _persist = persist;
  final Future<void> Function(DreamAppearanceSnapshot) _persist;
  DreamAppearanceSnapshot _snapshot = const DreamAppearanceSnapshot();
  DreamAppearanceSnapshot get snapshot => _snapshot;
  List<DreamAppearancePreset> get presets =>
      List.unmodifiable([...builtInDreamPresets, ..._snapshot.presets]);
  List<DreamAppearancePreset> forLayout(DreamLayout layout) =>
      presets.where((p) => p.layout == layout).toList();
  DreamAppearancePreset active(DreamLayout layout) =>
      forLayout(layout).firstWhere(
        (p) => p.id == _snapshot.selected[layout.name],
        orElse: () => forLayout(layout).first,
      );
  void restore(DreamAppearanceSnapshot value) {
    _snapshot = value;
    notifyListeners();
  }

  bool _disposed = false;
  Future<void> _pending = Future.value();
  Future<void> _update(DreamAppearanceSnapshot Function() next) {
    final operation = _pending.then((_) async {
      final value = next();
      await _persist(value);
      if (_disposed) return;
      _snapshot = value;
      notifyListeners();
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> select(DreamAppearancePreset preset) => _update(() {
    if (!presets.any((p) => p.id == preset.id && p.layout == preset.layout)) {
      throw StateError('Unknown dream preset');
    }
    return DreamAppearanceSnapshot(
      presets: _snapshot.presets,
      selected: {..._snapshot.selected, preset.layout.name: preset.id},
    );
  });
  Future<DreamAppearancePreset> save(
    DreamAppearancePreset draft, {
    bool asNew = false,
  }) async {
    final name = draft.name.trim();
    if (name.isEmpty || name.length > 80 || !isFlowDream(draft.layout)) {
      throw ArgumentError('Invalid dream preset');
    }
    final preset = draft.copyWith(
      flow: DreamFlowSettings.fromJson(draft.flow.toJson()),
      id: asNew || draft.builtIn
          ? 'dream-user-${DateTime.now().microsecondsSinceEpoch}'
          : draft.id,
      builtIn: false,
      name: name,
    );
    await _update(
      () => DreamAppearanceSnapshot(
        presets: [..._snapshot.presets.where((p) => p.id != preset.id), preset],
        selected: _snapshot.selected,
      ),
    );
    return preset;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
