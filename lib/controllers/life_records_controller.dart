import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/life_record.dart';
import '../services/life_records_service.dart';

class LifeRecordsController extends ChangeNotifier {
  LifeRecordsController({
    required this.origin,
    required this.owner,
    LifeRecordsService? service,
  }) : service = service ?? LifeRecordsService();

  final String Function() origin;
  final String Function() owner;
  final LifeRecordsService service;
  List<LifeRecord> records = [];
  Map<String, dynamic> queue = {};
  Map<String, dynamic> syncState = {};
  Map<String, dynamic>? observation;
  String? error;
  String category = '';
  String query = '';
  String from = '';
  String to = '';
  String? cursor;
  bool busy = false;
  bool querying = false;
  bool _searchAgain = false;
  bool _syncAgain = false;
  bool _manualSyncAgain = false;
  bool cacheOnly = true;
  Timer? _timer;
  bool _disposed = false;
  String _realm = '';
  int _generation = 0;
  Set<String>? _remoteIds;

  String get realm => '${origin()}\n${owner()}';
  bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  int get pendingCount =>
      queue.values.fold(0, (sum, n) => sum + (n as num).toInt());
  List<LifeRecord> get visible => records.where((record) {
    if (_remoteIds != null &&
        !record.pending &&
        !_remoteIds!.contains(record.id)) {
      return false;
    }
    return (category.isEmpty || record.category == category) &&
        (from.isEmpty || record.date.compareTo(from) >= 0) &&
        (to.isEmpty || record.date.compareTo(to) <= 0) &&
        (query.isEmpty || record.searchText.contains(query.toLowerCase()));
  }).toList()..sort((a, b) => b.date.compareTo(a.date));

  void start() {
    if (!available) return;
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(synchronize()),
    );
    unawaited(synchronize());
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void connectionChanged() {
    if (realm != _realm) {
      _realm = realm;
      _generation++;
      records = [];
      queue = {};
      syncState = {};
      observation = null;
      _remoteIds = null;
      cursor = null;
      cacheOnly = true;
      error = null;
      _notify();
    }
    if (available) unawaited(synchronize());
  }

  bool _current(int generation, String expectedRealm) =>
      !_disposed && generation == _generation && realm == expectedRealm;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _code(Object e) => e is PlatformException
      ? e.code
      : e is MissingPluginException
      ? 'unsupported_platform'
      : 'storage_error';

  Future<void> reload() async {
    final generation = _generation;
    final expected = realm;
    final snapshot = await service.object('snapshot', origin(), owner());
    if (!_current(generation, expected)) return;
    records = (snapshot['records'] as List)
        .map((e) => LifeRecord(Map<String, dynamic>.from(e as Map)))
        .toList();
    queue = Map<String, dynamic>.from(snapshot['queue'] as Map);
    syncState = Map<String, dynamic>.from(snapshot['sync'] as Map);
    _notify();
  }

  Future<void> synchronize({bool manual = false}) async {
    if (_disposed) return;
    if (busy) {
      _syncAgain = true;
      _manualSyncAgain = _manualSyncAgain || manual;
      return;
    }
    if (realm != _realm) {
      _realm = realm;
      _generation++;
      records = [];
      _remoteIds = null;
    }
    final generation = _generation;
    final expected = realm;
    busy = true;
    _notify();
    try {
      // A cache read failure must not suppress a durable queue upload.
      try {
        await reload();
      } catch (_) {}
      if (!_current(generation, expected)) return;
      final previousAck = syncState['last_ack'];
      await service.object('sync', origin(), owner(), {'manual': manual});
      if (_current(generation, expected)) {
        error = null;
        await reload();
        if (syncState['status'] == 'ready' &&
            (previousAck != syncState['last_ack'] ||
                records.any(
                  (r) =>
                      !r.pending &&
                      (r.recognition == 'pending' ||
                          r.recognition == 'processing'),
                ))) {
          await search();
        }
      }
    } catch (e) {
      if (_current(generation, expected)) error = _code(e);
    } finally {
      busy = false;
      _notify();
      if (_syncAgain && !_disposed) {
        final retryManually = _manualSyncAgain;
        _syncAgain = false;
        _manualSyncAgain = false;
        unawaited(synchronize(manual: retryManually));
      }
    }
  }

  void filters({String? category, String? query, String? from, String? to}) {
    this.category = category ?? this.category;
    this.query = query ?? this.query;
    this.from = from ?? this.from;
    this.to = to ?? this.to;
    _generation++;
    _remoteIds = null;
    cursor = null;
    cacheOnly = true;
    _notify();
  }

  Future<void> search({bool more = false}) async {
    if (_disposed) return;
    if (querying) {
      _searchAgain = true;
      return;
    }
    final generation = _generation;
    final expected = realm;
    querying = true;
    _notify();
    try {
      final response = await service.object('query', origin(), owner(), {
        'filters': jsonEncode({
          'category': category,
          'q': query,
          'from': from,
          'to': to,
          if (more && cursor != null) 'cursor': cursor,
        }),
      });
      if (!_current(generation, expected)) return;
      final ids = (response['records'] as List)
          .where((e) => e['deleted'] != true)
          .map((e) => e['id'] as String)
          .toSet();
      _remoteIds = more ? {...?_remoteIds, ...ids} : ids;
      cursor = response['next_cursor'] as String?;
      cacheOnly = false;
      error = null;
      await reload();
    } catch (e) {
      if (_current(generation, expected)) {
        error = _code(e);
        cacheOnly = true;
        _remoteIds = null;
      }
    } finally {
      querying = false;
      _notify();
      if (_searchAgain && !_disposed) {
        _searchAgain = false;
        unawaited(search());
      }
    }
  }

  Future<bool> save(
    Map<String, dynamic> record,
    Uint8List? image, {
    required String expectedRealm,
  }) async {
    if (realm != expectedRealm) {
      error = 'account_changed';
      _notify();
      return false;
    }
    return _mutate('save', {
      'record': jsonEncode(record),
      if (image != null) 'image': image,
    });
  }

  Future<bool> delete(String id) => _mutate('delete', {'id': id});
  Future<bool> acceptServer(String id) => _mutate('acceptServer', {'id': id});

  Future<bool> _mutate(String method, Map<String, dynamic> args) async {
    final expected = realm;
    try {
      await service.invoke(method, origin(), owner(), args);
    } catch (e) {
      error = _code(e);
      _notify();
      return false;
    }
    // A committed native mutation is successful even if refreshing its UI fails.
    // Reporting a failed save here would let a second tap create a duplicate.
    if (realm != expected || _disposed) return true;
    error = null;
    try {
      await reload();
    } catch (e) {
      error = _code(e);
      _notify();
    }
    unawaited(synchronize());
    return true;
  }

  Future<void> observe() async {
    final expected = realm;
    try {
      final value = await service.object('observe', origin(), owner());
      if (realm == expected) {
        observation = value;
        error = null;
      }
    } catch (e) {
      if (realm == expected) error = _code(e);
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    pause();
    super.dispose();
  }
}
