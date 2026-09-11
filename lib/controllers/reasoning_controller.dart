import 'package:flutter/foundation.dart';

class ReasoningController extends ChangeNotifier {
  ReasoningController(this.load);
  final Future<String> Function(String) load;
  String text = '';
  bool loading = false;
  bool failed = false;
  int _generation = 0;

  Future<void> fetch(String id) async {
    if (id.isEmpty || loading || text.isNotEmpty) return;
    final generation = ++_generation;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final result = await load(id);
      if (generation != _generation) return;
      text = result;
      failed = result.isEmpty;
    } catch (_) {
      if (generation != _generation) return;
      failed = true;
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
