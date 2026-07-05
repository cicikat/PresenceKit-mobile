import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../main.dart'
    show
        BackendActiveCharacter,
        BackendChatResponse,
        BackendDiagnostics,
        BackendDreamSettingsSummary,
        BackendMetaMode,
        BackendStatusSummary,
        BehaviorDecisionStatus,
        ChatLogDates,
        ChatLogDay,
        DiaryDetail,
        DiaryListItem,
        DreamChatResponse,
        DreamSettings,
        DreamState,
        GardenState,
        MobilePollMessage,
        PromptAssets;
import '../models/screen_context.dart';
import 'app_settings_store.dart';

class BackendClient {
  BackendClient({required this.baseUrl, required this.settingsStore});

  final String baseUrl;
  final AppSettingsStore settingsStore;

  Future<Uri> _endpoint(String path, {required String token}) async {
    if (token.trim().isEmpty) {
      throw const BackendException('Please enter an access credential first');
    }
    if (!await settingsStore.isAllowedBaseUrl(baseUrl)) {
      throw const BackendException('Backend origin is not trusted');
    }
    return Uri.parse('$baseUrl$path');
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    required String token,
    String method = 'GET',
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 20),
    bool expectJson = true,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final endpoint = await _endpoint(path, token: token);
      final request = switch (method) {
        'PATCH' => await client.patchUrl(endpoint),
        'POST' => await client.postUrl(endpoint),
        _ => await client.getUrl(endpoint),
      };
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendException(
          _extractError(responseBody, response.statusCode),
          statusCode: response.statusCode,
        );
      }
      if (!expectJson) return const {};
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const BackendException('后端返回格式不是 JSON object');
      }
      return decoded;
    } on TimeoutException {
      throw const BackendException('后端响应超时');
    } on SocketException {
      throw const BackendException('连不上后端：请确认后端已启动，或 adb reverse 已生效');
    } on FormatException {
      throw const BackendException('后端返回不是有效 JSON');
    } finally {
      client.close(force: true);
    }
  }

  Future<ChatLogDates> loadChatLogDates({required String token}) async {
    return ChatLogDates.fromJson(
      await _request('/chat-log/dates', token: token),
    );
  }

  Future<ChatLogDay> loadChatLogDay(
    String date, {
    required String token,
  }) async {
    return ChatLogDay.fromJson(await _request('/chat-log/$date', token: token));
  }

  Future<GardenState> loadGardenState({required String token}) async {
    return GardenState.fromJson(await _request('/garden/state', token: token));
  }

  Future<List<DiaryListItem>> loadDiaryList({required String token}) async {
    final d = await _request('/diary/list', token: token);
    final rawEntries = d['entries'];
    if (rawEntries is! List) return const [];
    return rawEntries
        .whereType<Map>()
        .map((e) => DiaryListItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.date.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<DiaryDetail> loadDiaryEntry(
    String date, {
    required String token,
  }) async {
    return DiaryDetail.fromJson(await _request('/diary/$date', token: token));
  }

  Future<void> activateMobile({required String token}) async {
    await _request(
      '/mobile/activate',
      token: token,
      method: 'POST',
      body: const {},
      expectJson: false,
    );
  }

  Future<void> deactivateMobile({required String token}) async {
    await _request(
      '/mobile/deactivate',
      token: token,
      method: 'POST',
      body: const {},
      expectJson: false,
    );
  }

  Future<List<MobilePollMessage>> pollMobile({
    required String token,
    int limit = 20,
    int? after,
    int waitSeconds = 0,
  }) async {
    final afterQuery = after == null ? '' : '&after=$after';
    final waitQuery = waitSeconds > 0 ? '&wait=$waitSeconds' : '';
    final d = await _request(
      '/mobile/poll?limit=$limit$afterQuery$waitQuery',
      token: token,
      timeout: Duration(seconds: waitSeconds > 0 ? waitSeconds + 10 : 20),
    );
    final rawMessages = d['messages'];
    if (rawMessages is! List) return const [];
    return rawMessages
        .whereType<Map>()
        .map((m) => MobilePollMessage.fromJson(Map<String, dynamic>.from(m)))
        .where((m) => m.content.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> ackMobile({required String token, required int ackSeq}) async {
    await _request(
      '/mobile/ack',
      token: token,
      method: 'POST',
      body: {'ack_seq': ackSeq},
      expectJson: false,
    );
  }

  Future<BackendChatResponse> sendChat(
    String message, {
    required String token,
  }) async {
    return BackendChatResponse.fromJson(
      await _request(
        '/desktop/chat',
        token: token,
        method: 'POST',
        body: {'message': message},
        timeout: const Duration(seconds: 120),
      ),
    );
  }

  Future<DreamState> loadDreamState({required String token}) async {
    return DreamState.fromJson(await _request('/dream/state', token: token));
  }

  Future<bool> enterDream({required String token}) async {
    final d = await _request(
      '/dream/enter',
      token: token,
      method: 'POST',
      body: const {},
    );
    return d['ok'] == true;
  }

  Future<DreamChatResponse> sendDreamChat(
    String message, {
    required String token,
  }) async {
    return DreamChatResponse.fromJson(
      await _request(
        '/dream/chat',
        token: token,
        method: 'POST',
        body: {'message': message},
        timeout: const Duration(seconds: 120),
      ),
    );
  }

  Future<void> exitDream({required String token}) async {
    await _request(
      '/dream/exit',
      token: token,
      method: 'POST',
      body: const {},
      expectJson: false,
    );
  }

  Future<PromptAssets> loadPromptAssets({required String token}) async {
    return PromptAssets.fromJson(
      await _request('/settings/prompt-assets', token: token),
    );
  }

  Future<PromptAssets> updatePromptAssets({
    required String token,
    String? activeCharacter,
    Set<String>? enabledLorebooks,
    Set<String>? enabledJailbreaks,
  }) async {
    final decoded = await _request(
      '/settings/prompt-assets',
      token: token,
      method: 'PATCH',
      body: {
        if (activeCharacter != null) 'active_character': activeCharacter,
        if (enabledLorebooks != null)
          'enabled_lorebooks': enabledLorebooks.toList(),
        if (enabledJailbreaks != null)
          'enabled_jailbreaks': enabledJailbreaks.toList(),
      },
    );
    final active = decoded['active'];
    final current = await loadPromptAssets(token: token);
    return active is Map
        ? PromptAssets.fromJson({
            'characters': current.characters
                .map((item) => {'id': item.id, 'label': item.label})
                .toList(),
            'lorebooks': current.lorebooks
                .map((item) => {'id': item.id, 'label': item.label})
                .toList(),
            'jailbreaks': current.jailbreaks
                .map((item) => {'id': item.id, 'label': item.label})
                .toList(),
            'active': Map<String, dynamic>.from(active),
          })
        : current;
  }

  Future<DreamSettings> loadDreamSettings({required String token}) async {
    return DreamSettings.fromJson(
      await _request('/dream/settings', token: token),
    );
  }

  Future<DreamSettings> updateDreamSettings({
    required String token,
    bool? enableDreamLorebook,
    String? worldLayer,
    String? jailbreakPreset,
  }) async {
    final decoded = await _request(
      '/dream/settings',
      token: token,
      method: 'PATCH',
      body: {
        if (enableDreamLorebook != null)
          'enable_dream_lorebook': enableDreamLorebook,
        if (worldLayer != null) 'world_layer': worldLayer,
        if (jailbreakPreset != null) 'jailbreak_preset': jailbreakPreset,
      },
    );
    final settings = decoded['settings'];
    return DreamSettings.fromJson(
      settings is Map ? Map<String, dynamic>.from(settings) : decoded,
    );
  }

  Future<BackendChatResponse> uploadFile({
    required PickedUploadFile file,
    required String token,
    String message = '',
    String channel = 'mobile',
  }) async {
    return uploadFiles(
      files: [file],
      token: token,
      message: message,
      channel: channel,
    );
  }

  Future<BackendChatResponse> uploadFiles({
    required List<PickedUploadFile> files,
    required String token,
    String message = '',
    String channel = 'mobile',
  }) async {
    if (files.isEmpty) {
      throw const BackendException('没有选择文件');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final endpoint = await _endpoint('/upload/ingest', token: token);
      final request = await client.postUrl(endpoint);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final boundary =
          '----yexuan-mobile-${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );

      void writeTextField(String name, String value) {
        request.add(
          utf8.encode(
            '--$boundary\r\n'
            'Content-Disposition: form-data; name="$name"\r\n\r\n'
            '$value\r\n',
          ),
        );
      }

      writeTextField('message', message);
      writeTextField('channel', channel);
      for (final file in files) {
        request.add(
          utf8.encode(
            '--$boundary\r\n'
            'Content-Disposition: form-data; name="files"; filename="${_multipartEscape(file.name)}"\r\n'
            'Content-Type: ${_contentTypeForFile(file.name)}\r\n\r\n',
          ),
        );
        request.add(file.bytes);
        request.add(utf8.encode('\r\n'));
      }
      request.add(utf8.encode('--$boundary--\r\n'));

      final response = await request.close().timeout(
        const Duration(seconds: 180),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendException(
          _extractError(body, response.statusCode),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const BackendException('文件上传返回格式不是 JSON object');
      }
      return BackendChatResponse.fromJson(decoded);
    } on TimeoutException {
      throw const BackendException('文件上传响应超时');
    } on SocketException {
      throw const BackendException('连不上后端：请确认后端已启动，或 adb reverse 已生效');
    } on FormatException {
      throw const BackendException('文件上传返回不是有效 JSON');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> pushScreenContext(
    ScreenContextSnapshot snapshot, {
    required String token,
    required bool allowTextUpload,
  }) async {
    await _request(
      '/sensor/realtime',
      token: token,
      method: 'POST',
      body: snapshot.toRealtimePayload(allowTextUpload: allowTextUpload),
      expectJson: false,
    );
  }

  // 前台是叶瑄 App 自身时，只发焦点信号，不带任何正文。
  Future<void> pushSelfFocusSignal({required String token}) async {
    await _request(
      '/sensor/realtime',
      token: token,
      method: 'POST',
      body: {
        'window_seconds': 45,
        'ts': DateTime.now().millisecondsSinceEpoch / 1000,
        'sensor_version': 'android_accessibility_1.0',
        'input': {
          'keystrokes': 0,
          'mouse_clicks': 0,
          'mouse_distance_px': 0,
          'idle_seconds': 0,
        },
        'focus': {'app': 'self', 'title_hint': 'yexuan_app', 'switch_count': 0},
        'screen': {
          'package_name': 'self',
          'app_label': '',
          'window_title': '',
          'visible_text': <String>[],
          'clickable_text': <String>[],
        },
      },
      expectJson: false,
    );
  }

  Future<void> pushMobileBehaviorTest({
    required String token,
    required String userId,
    required String content,
    required String kind,
    required String delivery,
  }) async {
    await _request(
      '/mobile/push',
      token: token,
      method: 'POST',
      body: {
        'user_id': userId,
        'content': content,
        'behavior': {
          'kind': kind,
          'delivery': delivery,
          'requires_confirmation':
              kind == 'lock_screen_confirm' || kind == 'takeout_overlay',
          'prompt_kind': 'debug_test',
          'cooldown_key': 'debug:$kind',
          'score': 99,
          'risk': kind == 'notify' ? 10 : 25,
          'reason': '手机端调试按钮',
          'facts': ['来自能力检查页的主动行为测试'],
          'allowed_actions': ['debug'],
          'blocked_actions': ['payment', 'submit_order'],
        },
      },
      expectJson: false,
    );
  }

  Future<BehaviorDecisionStatus> loadBehaviorDecisionStatus({
    required String token,
  }) async {
    return BehaviorDecisionStatus.fromJson(
      await _request('/sensor/behavior/status', token: token),
    );
  }

  // ── 后端/资产诊断（只读） ──────────────────────────────────────────────────

  Future<BackendDiagnostics> fetchDiagnostics({required String token}) async {
    final results = await Future.wait([
      _request('/system/data-path', token: token).then<Object?>((d) => d).catchError((e) => e),
      _request('/system/meta-mode', token: token).then<Object?>((d) => d).catchError((e) => e),
      _request('/status', token: token).then<Object?>((d) => d).catchError((e) => e),
      _request('/characters/active-info', token: token).then<Object?>((d) => d).catchError((e) => e),
      _request('/lorebook', token: token).then<Object?>((d) => d).catchError((e) => e),
      _request('/jailbreak-entries', token: token).then<Object?>((d) => d).catchError((e) => e),
      _request('/dream/settings', token: token).then<Object?>((d) => d).catchError((e) => e),
    ]);

    String errMsg(Object? r) =>
        r is Exception ? r.toString() : (r is Error ? r.toString() : '读取失败');

    String? dataPath;
    String? dataPathError;
    bool dataPathForbidden = false;
    if (results[0] is Map<String, dynamic>) {
      dataPath = (results[0] as Map<String, dynamic>)['data_prefix']?.toString();
    } else if (results[0] is BackendException &&
        (results[0] as BackendException).statusCode == 403) {
      // mobile token 预期拿不到 admin-only 的 /system/data-path，见 round-鉴权分层-scoped-tokens-移动端.md §2.3
      dataPathForbidden = true;
    } else {
      dataPathError = errMsg(results[0]);
    }

    BackendMetaMode? metaMode;
    String? metaModeError;
    if (results[1] is Map<String, dynamic>) {
      metaMode = BackendMetaMode.fromJson(results[1] as Map<String, dynamic>);
    } else {
      metaModeError = errMsg(results[1]);
    }

    BackendStatusSummary? statusSummary;
    String? statusSummaryError;
    if (results[2] is Map<String, dynamic>) {
      statusSummary = BackendStatusSummary.fromJson(results[2] as Map<String, dynamic>);
    } else {
      statusSummaryError = errMsg(results[2]);
    }

    BackendActiveCharacter? activeCharacter;
    String? activeCharacterError;
    if (results[3] is Map<String, dynamic>) {
      activeCharacter = BackendActiveCharacter.fromJson(results[3] as Map<String, dynamic>);
    } else {
      activeCharacterError = errMsg(results[3]);
    }

    int? lorebookCount;
    String? lorebookError;
    if (results[4] is Map<String, dynamic>) {
      final raw = (results[4] as Map<String, dynamic>)['entries'];
      lorebookCount = raw is List ? raw.length : 0;
    } else {
      lorebookError = errMsg(results[4]);
    }

    int? jailbreakCount;
    String? jailbreakError;
    if (results[5] is Map<String, dynamic>) {
      final raw = (results[5] as Map<String, dynamic>)['entries'];
      jailbreakCount = raw is List ? raw.length : 0;
    } else {
      jailbreakError = errMsg(results[5]);
    }

    BackendDreamSettingsSummary? dreamSettings;
    String? dreamSettingsError;
    if (results[6] is Map<String, dynamic>) {
      dreamSettings = BackendDreamSettingsSummary.fromJson(results[6] as Map<String, dynamic>);
    } else {
      dreamSettingsError = errMsg(results[6]);
    }

    return BackendDiagnostics(
      backendBase: baseUrl,
      dataPath: dataPath,
      dataPathError: dataPathError,
      dataPathForbidden: dataPathForbidden,
      metaMode: metaMode,
      metaModeError: metaModeError,
      statusSummary: statusSummary,
      statusSummaryError: statusSummaryError,
      activeCharacter: activeCharacter,
      activeCharacterError: activeCharacterError,
      lorebookCount: lorebookCount,
      lorebookError: lorebookError,
      jailbreakCount: jailbreakCount,
      jailbreakError: jailbreakError,
      dreamSettings: dreamSettings,
      dreamSettingsError: dreamSettingsError,
    );
  }

  @visibleForTesting
  static String debugExtractError(String body, int statusCode) =>
      _extractError(body, statusCode);

  static String _extractError(String body, int statusCode) {
    String? detail;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        detail = decoded['detail'].toString();
      } else if (decoded is Map && decoded['error'] != null) {
        detail = decoded['error'].toString();
      }
    } catch (_) {
      // Fall through to the status-based messages below.
    }
    switch (statusCode) {
      case 401:
        return 'token 无效，请检查系统设置里的 token';
      case 403:
        return 'token 权限不足：${detail ?? "HTTP 403"}';
      case 429:
        return '认证失败过多，来源已被临时限制，稍后再试';
      default:
        return detail ?? 'HTTP $statusCode';
    }
  }

  static String _multipartEscape(String value) {
    return value.replaceAll('\\', '\\\\').replaceAll('"', r'\"');
  }

  static String _contentTypeForFile(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.md')) return 'text/markdown; charset=utf-8';
    if (lower.endsWith('.txt')) return 'text/plain; charset=utf-8';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'application/octet-stream';
  }
}

class BackendException implements Exception {
  const BackendException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
