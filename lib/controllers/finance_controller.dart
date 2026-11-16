import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/finance_service.dart';

class FinanceController extends ChangeNotifier {
  FinanceController({
    required this.origin,
    required this.owner,
    FinanceService? service,
  }) : service = service ?? FinanceService();
  final String Function() origin;
  final String Function() owner;
  final FinanceService service;
  List<Map<String, dynamic>> records = [];
  bool enabled = false, permission = false, busy = false, _disposed = false;
  String status = '', _loadedRealm = '';
  String get realm => '${origin()}\n${owner()}';
  String get loadedRealm => _loadedRealm;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh({bool sync = false}) async {
    if (busy || _disposed) return;
    busy = true;
    final expected = realm;
    if (_loadedRealm != expected) {
      records = [];
      enabled = false;
      permission = false;
      status = '';
    }
    _notify();
    try {
      if (sync) await service.invoke('sync', origin(), owner());
      final value = await service.snapshot(origin(), owner());
      if (_disposed || expected != realm) return;
      _loadedRealm = expected;
      records =
          (value['records'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
            ..sort(
              (a, b) =>
                  (b['occurred_at'] as int).compareTo(a['occurred_at'] as int),
            );
      enabled = value['enabled'] == true;
      permission = value['permission'] == true;
      status = (value['sync'] as Map?)?['status'] as String? ?? '';
    } catch (e) {
      if (expected == realm) {
        status = e is PlatformException ? e.code : 'unsupported';
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> action(
    String method,
    Map<String, dynamic> args, {
    String? expectedRealm,
  }) async {
    if (busy || _disposed) return;
    if (expectedRealm != null && expectedRealm != realm) {
      status = 'account_changed';
      _notify();
      return;
    }
    final expected = realm;
    busy = true;
    _notify();
    try {
      await service.invoke(method, origin(), owner(), args);
    } catch (e) {
      if (expected == realm) {
        status = e is PlatformException ? e.code : 'storage_error';
      }
      busy = false;
      _notify();
      return;
    }
    busy = false;
    await refresh();
  }

  Future<void> edit(
    Map<String, dynamic> row,
    Map<String, dynamic> patch,
    String expected,
  ) => action('edit', {
    'id': row['candidate_id'],
    'patch': jsonEncode(patch),
  }, expectedRealm: expected);
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
