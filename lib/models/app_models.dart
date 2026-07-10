part of '../main.dart';

class _BehaviorTestSpec {
  const _BehaviorTestSpec({
    required this.kind,
    required this.delivery,
    required this.label,
    required this.content,
  });

  factory _BehaviorTestSpec.forKind(String kind) {
    return switch (kind) {
      'overlay_message' => const _BehaviorTestSpec(
        kind: 'overlay_message',
        delivery: 'overlay',
        label: '悬浮短句',
        content: '（测试）我在屏幕边等你一下。',
      ),
      'lock_screen_confirm' => const _BehaviorTestSpec(
        kind: 'lock_screen_confirm',
        delivery: 'overlay',
        label: '锁屏确认',
        content: '（测试）要我替你锁屏吗？点确认才会执行。',
      ),
      'takeout_overlay' => const _BehaviorTestSpec(
        kind: 'takeout_overlay',
        delivery: 'overlay',
        label: '外卖确认',
        content: '（测试）要不要打开外卖页看一眼？不会自动下单。',
      ),
      _ => const _BehaviorTestSpec(
        kind: 'notify',
        delivery: 'notification',
        label: '普通通知',
        content: '（测试）这是一条普通主动消息。',
      ),
    };
  }

  final String kind;
  final String delivery;
  final String label;
  final String content;
}

class BehaviorDecisionStatus {
  const BehaviorDecisionStatus({
    required this.ts,
    required this.stage,
    required this.sent,
    required this.reason,
    required this.candidatesCount,
    required this.score,
    required this.risk,
    required this.tier,
    required this.eventType,
    required this.narrative,
    required this.focusApp,
    required this.screenTextHint,
    required this.behaviorKind,
    required this.behaviorId,
    required this.delivery,
    required this.replyPreview,
  });

  factory BehaviorDecisionStatus.fromJson(Map<String, dynamic> json) {
    final picked = json['picked'] is Map
        ? Map<String, dynamic>.from(json['picked'] as Map)
        : const <String, dynamic>{};
    final behavior = json['behavior'] is Map
        ? Map<String, dynamic>.from(json['behavior'] as Map)
        : const <String, dynamic>{};
    return BehaviorDecisionStatus(
      ts: json['ts'] is num ? (json['ts'] as num).toDouble() : null,
      stage: (json['stage'] ?? 'unknown').toString(),
      sent: json['sent'] == true,
      reason: (json['reason'] ?? '').toString(),
      candidatesCount: json['candidates_count'] is num
          ? (json['candidates_count'] as num).toInt()
          : null,
      score: json['score'] is num ? (json['score'] as num).toInt() : null,
      risk: json['risk'] is num ? (json['risk'] as num).toInt() : null,
      tier: (json['tier'] ?? '').toString(),
      eventType: (picked['type'] ?? '').toString(),
      narrative: (picked['narrative'] ?? '').toString(),
      focusApp: (picked['focus_app'] ?? '').toString(),
      screenTextHint: (picked['screen_text_hint'] ?? '').toString(),
      behaviorKind: (behavior['level'] ?? behavior['kind'] ?? '').toString(),
      behaviorId: (behavior['behavior_id'] ?? '').toString(),
      delivery: (behavior['delivery'] ?? '').toString(),
      replyPreview: (json['reply_preview'] ?? '').toString(),
    );
  }

  final double? ts;
  final String stage;
  final bool sent;
  final String reason;
  final int? candidatesCount;
  final int? score;
  final int? risk;
  final String tier;
  final String eventType;
  final String narrative;
  final String focusApp;
  final String screenTextHint;
  final String behaviorKind;
  final String behaviorId;
  final String delivery;
  final String replyPreview;

  String get timeLabel {
    final value = ts;
    if (value == null) return '未运行';
    return _formatDateTime(
      DateTime.fromMillisecondsSinceEpoch((value * 1000).round()),
    );
  }
}

enum AppRoute { chat, dream, profile, diary, garden }

extension AppRouteLabel on AppRoute {
  String get label {
    switch (this) {
      case AppRoute.chat:
        return '主对话';
      case AppRoute.dream:
        return '梦境';
      case AppRoute.profile:
        return '资料';
      case AppRoute.diary:
        return '日记';
      case AppRoute.garden:
        return '花园';
    }
  }
}

class YxPrefs {
  const YxPrefs({
    this.infoStrip = true,
    this.fontSize = 16,
    this.showYouAvatar = false,
    this.proactiveRate = 'mid',
    this.nightSilent = true,
  });

  final bool infoStrip;
  final double fontSize;
  final bool showYouAvatar;
  final String proactiveRate;
  final bool nightSilent;

  YxPrefs copyWith({
    bool? infoStrip,
    double? fontSize,
    bool? showYouAvatar,
    String? proactiveRate,
    bool? nightSilent,
  }) {
    return YxPrefs(
      infoStrip: infoStrip ?? this.infoStrip,
      fontSize: fontSize ?? this.fontSize,
      showYouAvatar: showYouAvatar ?? this.showYouAvatar,
      proactiveRate: proactiveRate ?? this.proactiveRate,
      nightSilent: nightSilent ?? this.nightSilent,
    );
  }
}

class YxPalette {
  const YxPalette({
    required this.surface,
    required this.surfaceSoft,
    required this.surfaceDeep,
    required this.surfaceEdge,
    required this.ink1,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.character,
    required this.characterDeep,
    required this.characterSoft,
    required this.characterOn,
    required this.danger,
    required this.warn,
    required this.ok,
    required this.send,
    required this.userBubble,
    required this.userBubbleText,
    required this.scrim,
  });

  final Color surface;
  final Color surfaceSoft;
  final Color surfaceDeep;
  final Color surfaceEdge;
  final Color ink1;
  final Color ink2;
  final Color ink3;
  final Color ink4;
  final Color character;
  final Color characterDeep;
  final Color characterSoft;
  final Color characterOn;
  final Color danger;
  final Color warn;
  final Color ok;
  final Color send;
  final Color userBubble;
  final Color userBubbleText;
  final Color scrim;

  YxPalette copyWith({
    Color? surface,
    Color? surfaceSoft,
    Color? surfaceDeep,
    Color? surfaceEdge,
    Color? ink1,
    Color? ink2,
    Color? ink3,
    Color? ink4,
    Color? character,
    Color? characterDeep,
    Color? characterSoft,
    Color? characterOn,
    Color? danger,
    Color? warn,
    Color? ok,
    Color? send,
    Color? userBubble,
    Color? userBubbleText,
    Color? scrim,
  }) {
    return YxPalette(
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      surfaceDeep: surfaceDeep ?? this.surfaceDeep,
      surfaceEdge: surfaceEdge ?? this.surfaceEdge,
      ink1: ink1 ?? this.ink1,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      ink4: ink4 ?? this.ink4,
      character: character ?? this.character,
      characterDeep: characterDeep ?? this.characterDeep,
      characterSoft: characterSoft ?? this.characterSoft,
      characterOn: characterOn ?? this.characterOn,
      danger: danger ?? this.danger,
      warn: warn ?? this.warn,
      ok: ok ?? this.ok,
      send: send ?? this.send,
      userBubble: userBubble ?? this.userBubble,
      userBubbleText: userBubbleText ?? this.userBubbleText,
      scrim: scrim ?? this.scrim,
    );
  }

  String toJsonString() {
    return jsonEncode({
      'surface': surface.toARGB32(),
      'surfaceSoft': surfaceSoft.toARGB32(),
      'surfaceDeep': surfaceDeep.toARGB32(),
      'surfaceEdge': surfaceEdge.toARGB32(),
      'ink1': ink1.toARGB32(),
      'ink2': ink2.toARGB32(),
      'ink3': ink3.toARGB32(),
      'ink4': ink4.toARGB32(),
      'character': character.toARGB32(),
      'characterDeep': characterDeep.toARGB32(),
      'characterSoft': characterSoft.toARGB32(),
      'characterOn': characterOn.toARGB32(),
      'danger': danger.toARGB32(),
      'warn': warn.toARGB32(),
      'ok': ok.toARGB32(),
      'send': send.toARGB32(),
      'userBubble': userBubble.toARGB32(),
      'userBubbleText': userBubbleText.toARGB32(),
      'scrim': scrim.toARGB32(),
    });
  }

  static YxPalette? fromJsonString(String? raw, {YxPalette? fallback}) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final base = fallback ?? YxPalette.light;
      return base.copyWith(
        surface: _colorFromJson(decoded['surface'], base.surface),
        surfaceSoft: _colorFromJson(decoded['surfaceSoft'], base.surfaceSoft),
        surfaceDeep: _colorFromJson(decoded['surfaceDeep'], base.surfaceDeep),
        surfaceEdge: _colorFromJson(decoded['surfaceEdge'], base.surfaceEdge),
        ink1: _colorFromJson(decoded['ink1'], base.ink1),
        ink2: _colorFromJson(decoded['ink2'], base.ink2),
        ink3: _colorFromJson(decoded['ink3'], base.ink3),
        ink4: _colorFromJson(decoded['ink4'], base.ink4),
        character: _colorFromJson(decoded['character'], base.character),
        characterDeep: _colorFromJson(
          decoded['characterDeep'],
          base.characterDeep,
        ),
        characterSoft: _colorFromJson(
          decoded['characterSoft'],
          base.characterSoft,
        ),
        characterOn: _colorFromJson(decoded['characterOn'], base.characterOn),
        danger: _colorFromJson(decoded['danger'], base.danger),
        warn: _colorFromJson(decoded['warn'], base.warn),
        ok: _colorFromJson(decoded['ok'], base.ok),
        send: _colorFromJson(decoded['send'], base.send),
        userBubble: _colorFromJson(decoded['userBubble'], base.userBubble),
        userBubbleText: _colorFromJson(
          decoded['userBubbleText'],
          base.userBubbleText,
        ),
        scrim: _colorFromJson(decoded['scrim'], base.scrim),
      );
    } catch (_) {
      return null;
    }
  }

  static Color _colorFromJson(Object? raw, Color fallback) {
    final value = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (value == null) return fallback;
    return Color.fromARGB(
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    );
  }

  static const light = YxPalette(
    surface: Color(0xFFECE3D0),
    surfaceSoft: Color(0xFFF1E8D6),
    surfaceDeep: Color(0xFFE3D7BF),
    surfaceEdge: Color(0xFFD0BF96),
    ink1: Color(0xFF2A1F18),
    ink2: Color(0xFF5A4A3A),
    ink3: Color(0xFF8A7A66),
    ink4: Color(0xFFB5A88E),
    character: Color(0xFF1F3A2E),
    characterDeep: Color(0xFF14271F),
    characterSoft: Color(0xFFDCE3D6),
    characterOn: Color(0xFFF1E9D6),
    danger: Color(0xFF8B3A2B),
    warn: Color(0xFFB8893A),
    ok: Color(0xFF4A6B40),
    send: Color(0xFFB6553F),
    userBubble: Color(0xFF1F1812),
    userBubbleText: Color(0xFFECE3D0),
    scrim: Color(0x990F0B07),
  );

  static const dark = YxPalette(
    surface: Color(0xFF1B1410),
    surfaceSoft: Color(0xFF221912),
    surfaceDeep: Color(0xFF2C2117),
    surfaceEdge: Color(0xFF3D3022),
    ink1: Color(0xFFE8DCC0),
    ink2: Color(0xFFB5A488),
    ink3: Color(0xFF897A5F),
    ink4: Color(0xFF5A4E3A),
    character: Color(0xFF88A589),
    characterDeep: Color(0xFFC5D6BD),
    characterSoft: Color(0xFF1F2A20),
    characterOn: Color(0xFF14271F),
    danger: Color(0xFFC76851),
    warn: Color(0xFFD4A256),
    ok: Color(0xFF88A589),
    send: Color(0xFFC76851),
    userBubble: Color(0xFFE8DCC0),
    userBubbleText: Color(0xFF1B1410),
    scrim: Color(0xB3000000),
  );
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    required this.time,
  });

  final String role;
  final String text;
  final String time;
}

class DreamState {
  const DreamState({
    required this.status,
    required this.sceneLabel,
    required this.emotionLabel,
    required this.dreamStability,
    required this.dreamDepth,
  });

  final String status;
  final String sceneLabel;
  final String emotionLabel;
  final int? dreamStability;
  final int? dreamDepth;

  bool get isActive =>
      status == 'DREAM_ACTIVE' || status == 'DREAM_EXIT_REQUESTED';

  factory DreamState.fromJson(Map<String, dynamic> json) {
    int? number(Object? value) {
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '');
    }

    return DreamState(
      status: json['status']?.toString() ?? 'REALITY_CHAT',
      sceneLabel:
          json['scene_label']?.toString() ??
          json['scene_state']?.toString() ??
          '梦境边缘',
      emotionLabel: json['emotion_label']?.toString() ?? '未命名',
      dreamStability: number(json['dream_stability']),
      dreamDepth: number(json['dream_depth']),
    );
  }
}

class DreamChatResponse {
  const DreamChatResponse({
    required this.reply,
    required this.exitAccepted,
    required this.forceExited,
    required this.error,
  });

  final String reply;
  final bool exitAccepted;
  final bool forceExited;
  final String? error;

  factory DreamChatResponse.fromJson(Map<String, dynamic> json) {
    return DreamChatResponse(
      reply: json['reply']?.toString() ?? '',
      exitAccepted: json['exit_accepted'] == true,
      forceExited: json['force_exited'] == true,
      error: json['error']?.toString(),
    );
  }
}

class PromptAssetOption {
  const PromptAssetOption({required this.id, required this.label});

  final String id;
  final String label;

  factory PromptAssetOption.fromJson(Object? value) {
    if (value is String) return PromptAssetOption(id: value, label: value);
    final json = value is Map ? Map<String, dynamic>.from(value) : const {};
    final id = json['id']?.toString() ?? '';
    return PromptAssetOption(id: id, label: json['label']?.toString() ?? id);
  }
}

class PromptAssets {
  const PromptAssets({
    required this.characters,
    required this.lorebooks,
    required this.jailbreaks,
    required this.activeCharacter,
    required this.enabledLorebooks,
    required this.enabledJailbreaks,
  });

  final List<PromptAssetOption> characters;
  final List<PromptAssetOption> lorebooks;
  final List<PromptAssetOption> jailbreaks;
  final String activeCharacter;
  final Set<String> enabledLorebooks;
  final Set<String> enabledJailbreaks;

  factory PromptAssets.fromJson(Map<String, dynamic> json) {
    List<PromptAssetOption> options(Object? value) => value is List
        ? value
              .map(PromptAssetOption.fromJson)
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false)
        : const [];
    Set<String> ids(Object? value) => value is List
        ? value.map((item) => item.toString()).toSet()
        : <String>{};
    final active = json['active'] is Map
        ? Map<String, dynamic>.from(json['active'] as Map)
        : const <String, dynamic>{};
    return PromptAssets(
      characters: options(json['characters']),
      lorebooks: options(json['lorebooks']),
      jailbreaks: options(json['jailbreaks']),
      activeCharacter: active['active_character']?.toString() ?? '',
      enabledLorebooks: ids(active['enabled_lorebooks']),
      enabledJailbreaks: ids(active['enabled_jailbreaks']),
    );
  }
}

class DreamSettings {
  const DreamSettings({
    required this.enableDreamLorebook,
    required this.worldLayer,
    required this.jailbreakPreset,
  });

  final bool enableDreamLorebook;
  final String worldLayer;
  final String jailbreakPreset;

  factory DreamSettings.fromJson(Map<String, dynamic> json) {
    return DreamSettings(
      enableDreamLorebook: json['enable_dream_lorebook'] != false,
      worldLayer: json['world_layer']?.toString() ?? 'reality_derived',
      jailbreakPreset: json['jailbreak_preset']?.toString() ?? 'default',
    );
  }
}

class AttachmentPlaceholder {
  const AttachmentPlaceholder({
    required this.filename,
    required this.note,
    required this.kind,
  });

  final String filename;
  final String note;
  final String kind;

  bool get isImage => kind == 'image' || _looksLikeImage(filename);

  static AttachmentPlaceholder? parse(String text) {
    final normalized = text.trim().replaceAll('\r\n', '\n');
    final match = RegExp(
      '^📎\\s*(.+?)(?:\\n([\\s\\S]*))?\$',
    ).firstMatch(normalized);
    if (match != null) {
      return AttachmentPlaceholder(
        filename: match.group(1)?.trim().isEmpty ?? true
            ? '附件'
            : match.group(1)!.trim(),
        note: (match.group(2) ?? '').trim(),
        kind: _looksLikeImage(match.group(1) ?? '') ? 'image' : 'file',
      );
    }

    final legacy = RegExp(
      r'^[（(]?\s*上传了(?:(\d+)张)?(文件|图片)\s*[：:]\s*(.+?)[）)]?(?:\n([\s\S]*))?$',
    ).firstMatch(normalized);
    if (legacy != null) {
      final kindLabel = legacy.group(2) ?? '';
      final rawName = (legacy.group(3) ?? '').trim();
      return AttachmentPlaceholder(
        filename: rawName.isEmpty ? '附件' : rawName,
        note: (legacy.group(4) ?? '').trim(),
        kind: kindLabel == '图片' ? 'image' : 'file',
      );
    }

    final contextual = RegExp(
      r'^[（(]?\s*你发来了一个(文件|图片)\s*[：:]\s*([^,，）)]+)\s*(?:[,，]\s*内容如下)?[）)]?(?:[,，][\s\S]*)?$',
    ).firstMatch(normalized);
    if (contextual != null) {
      final kindLabel = contextual.group(1) ?? '';
      final rawName = (contextual.group(2) ?? '').trim();
      return AttachmentPlaceholder(
        filename: rawName.isEmpty ? '附件' : rawName,
        note: '',
        kind: kindLabel == '图片' ? 'image' : 'file',
      );
    }

    return null;
  }

  static bool _looksLikeImage(String name) {
    final lower = name.toLowerCase();
    return [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.heic',
      '.heif',
      '.bmp',
    ].any(lower.contains);
  }
}

class ChatLogEntry {
  const ChatLogEntry({
    required this.time,
    required this.user,
    required this.assistant,
  });

  factory ChatLogEntry.fromJson(Map<String, dynamic> json) {
    return ChatLogEntry(
      time: (json['time'] ?? '').toString(),
      user: (json['user'] ?? '').toString(),
      assistant: (json['assistant'] ?? '').toString(),
    );
  }

  final String time;
  final String user;
  final String assistant;
}

class ChatLogDay {
  const ChatLogDay({
    required this.date,
    required this.entries,
    required this.rawFallback,
  });

  factory ChatLogDay.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    return ChatLogDay(
      date: (json['date'] ?? '').toString(),
      entries: rawEntries is List
          ? rawEntries
                .whereType<Map>()
                .map(
                  (entry) =>
                      ChatLogEntry.fromJson(Map<String, dynamic>.from(entry)),
                )
                .toList(growable: false)
          : const [],
      rawFallback: json['raw_fallback'] == true,
    );
  }

  final String date;
  final List<ChatLogEntry> entries;
  final bool rawFallback;
}

class ChatLogDates {
  const ChatLogDates({required this.dates, required this.count});

  factory ChatLogDates.fromJson(Map<String, dynamic> json) {
    final rawDates = json['dates'];
    return ChatLogDates(
      dates: rawDates is List
          ? rawDates.map((date) => date.toString()).toList(growable: false)
          : const [],
      count: json['count'] is num
          ? (json['count'] as num).toInt()
          : int.tryParse((json['count'] ?? '0').toString()) ?? 0,
    );
  }

  final List<String> dates;
  final int count;
}

class GardenState {
  const GardenState({
    required this.slots,
    required this.harvestCount,
    required this.vaseCount,
  });

  factory GardenState.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'];
    return GardenState(
      slots: rawSlots is List
          ? rawSlots
                .whereType<Map>()
                .map(
                  (slot) =>
                      GardenSlot.fromJson(Map<String, dynamic>.from(slot)),
                )
                .toList(growable: false)
          : const [],
      harvestCount: json['harvest_count'] is num
          ? (json['harvest_count'] as num).toInt()
          : int.tryParse((json['harvest_count'] ?? '0').toString()) ?? 0,
      vaseCount: json['vase_count'] is num
          ? (json['vase_count'] as num).toInt()
          : int.tryParse((json['vase_count'] ?? '0').toString()) ?? 0,
    );
  }

  final List<GardenSlot> slots;
  final int harvestCount;
  final int vaseCount;
}

class GardenSlot {
  const GardenSlot({
    required this.slotKey,
    required this.flowerId,
    required this.name,
    required this.enName,
    required this.stage,
    required this.growth,
    required this.stageProgress,
    required this.moodKeys,
    required this.lastWatered,
  });

  factory GardenSlot.fromJson(Map<String, dynamic> json) {
    final rawMoods = json['mood_keys'];
    final rawLastWatered = json['last_watered'];
    return GardenSlot(
      slotKey: (json['slot_key'] ?? '').toString(),
      flowerId: (json['flower_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      enName: (json['en_name'] ?? '').toString(),
      stage: (json['stage'] ?? '').toString(),
      growth: json['growth'] is num
          ? (json['growth'] as num).toInt()
          : int.tryParse((json['growth'] ?? '0').toString()) ?? 0,
      stageProgress: json['stage_progress'] is num
          ? (json['stage_progress'] as num).toDouble()
          : double.tryParse((json['stage_progress'] ?? '0').toString()) ?? 0,
      moodKeys: rawMoods is List
          ? rawMoods.map((mood) => mood.toString()).toList(growable: false)
          : const [],
      lastWatered: rawLastWatered is num
          ? DateTime.fromMillisecondsSinceEpoch((rawLastWatered * 1000).round())
          : null,
    );
  }

  final String slotKey;
  final String flowerId;
  final String name;
  final String enName;
  final String stage;
  final int growth;
  final double stageProgress;
  final List<String> moodKeys;
  final DateTime? lastWatered;
}

class DiaryListItem {
  const DiaryListItem({
    required this.date,
    required this.title,
    required this.emotion,
  });

  factory DiaryListItem.fromJson(Map<String, dynamic> json) {
    final emotion = json['emotion'];
    return DiaryListItem(
      date: (json['date'] ?? '').toString(),
      title: (json['title'] ?? '(空)').toString(),
      emotion: emotion?.toString(),
    );
  }

  final String date;
  final String title;
  final String? emotion;
}

class DiaryDetail {
  const DiaryDetail({
    required this.date,
    required this.title,
    required this.emotion,
    required this.body,
  });

  factory DiaryDetail.fromJson(Map<String, dynamic> json) {
    final emotion = json['emotion'];
    return DiaryDetail(
      date: (json['date'] ?? '').toString(),
      title: (json['title'] ?? '(空)').toString(),
      emotion: emotion?.toString(),
      body: (json['body'] ?? '').toString(),
    );
  }

  final String date;
  final String title;
  final String? emotion;
  final String body;
}

class MobilePollMessage {
  const MobilePollMessage({
    required this.id,
    required this.seq,
    required this.content,
    required this.userId,
    required this.timestamp,
    required this.behaviorKind,
    required this.behaviorDelivery,
    required this.behaviorLevel,
    required this.behaviorId,
  });

  factory MobilePollMessage.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];
    final rawBehavior = json['behavior'];
    final behavior = rawBehavior is Map
        ? Map<String, dynamic>.from(rawBehavior)
        : const <String, dynamic>{};
    return MobilePollMessage(
      id: (json['id'] ?? '').toString(),
      seq: json['seq'] is num ? (json['seq'] as num).toInt() : null,
      content: (json['content'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      timestamp: rawTimestamp is num
          ? DateTime.fromMillisecondsSinceEpoch((rawTimestamp * 1000).round())
          : null,
      behaviorKind: (behavior['kind'] ?? '').toString(),
      behaviorDelivery: (behavior['delivery'] ?? '').toString(),
      behaviorLevel: (behavior['level'] ?? '').toString(),
      behaviorId: (behavior['behavior_id'] ?? '').toString(),
    );
  }

  final String id;
  final int? seq;
  final String content;
  final String userId;
  final DateTime? timestamp;
  final String behaviorKind;
  final String behaviorDelivery;
  final String behaviorLevel;
  final String behaviorId;

  ChatMessage toChatMessage() {
    return ChatMessage(
      role: 'him',
      text: content,
      time: timestamp == null ? '刚才' : _formatDateTime(timestamp!),
    );
  }
}

class BackendChatResponse {
  const BackendChatResponse({
    required this.reply,
    required this.affection,
    required this.level,
    required this.emotion,
    this.msgId,
    this.turnId,
  });

  factory BackendChatResponse.fromJson(Map<String, dynamic> json) {
    String? toId(Object? raw) {
      final s = raw?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return BackendChatResponse(
      reply: (json['reply'] ?? '').toString(),
      affection: json['affection'] is num
          ? (json['affection'] as num).toInt()
          : int.tryParse((json['affection'] ?? '0').toString()) ?? 0,
      level: (json['level'] ?? '').toString(),
      emotion: (json['emotion'] ?? 'neutral').toString(),
      msgId: toId(json['msg_id']) ?? toId(json['turn_id']),
      turnId: toId(json['turn_id']),
    );
  }

  final String reply;
  final int affection;
  final String level;
  final String emotion;
  final String? msgId;
  final String? turnId;
}

// ── 后端/资产诊断 ───────────────────────────────────────────────────────────

class BackendDiagnostics {
  const BackendDiagnostics({
    required this.backendBase,
    this.dataPath,
    this.dataPathError,
    this.dataPathForbidden = false,
    this.metaMode,
    this.metaModeError,
    this.statusSummary,
    this.statusSummaryError,
    this.activeCharacter,
    this.activeCharacterError,
    this.lorebookCount,
    this.lorebookError,
    this.jailbreakCount,
    this.jailbreakError,
    this.dreamSettings,
    this.dreamSettingsError,
  });

  final String backendBase;

  final String? dataPath;
  final String? dataPathError;
  // mobile profile token 拿不到 admin-only 的 /system/data-path 是预期行为，见
  // round-鉴权分层-scoped-tokens-移动端.md §2.3；渲染时不应视为故障。
  final bool dataPathForbidden;

  final BackendMetaMode? metaMode;
  final String? metaModeError;

  final BackendStatusSummary? statusSummary;
  final String? statusSummaryError;

  final BackendActiveCharacter? activeCharacter;
  final String? activeCharacterError;

  final int? lorebookCount;
  final String? lorebookError;

  final int? jailbreakCount;
  final String? jailbreakError;

  final BackendDreamSettingsSummary? dreamSettings;
  final String? dreamSettingsError;

  bool get dataPathIsSandbox =>
      dataPath != null && dataPath!.contains('test_sandbox');
}

class BackendMetaMode {
  const BackendMetaMode({required this.mode, this.expiresAt});

  factory BackendMetaMode.fromJson(Map<String, dynamic> json) {
    return BackendMetaMode(
      mode: (json['mode'] ?? '').toString(),
      expiresAt: json['expires_at']?.toString(),
    );
  }

  final String mode;
  final String? expiresAt;

  bool get isDanger => mode == 'danger';
}

class BackendStatusSummary {
  const BackendStatusSummary({
    this.llmModel,
    this.llmProvider,
    this.shortTermRounds,
  });

  factory BackendStatusSummary.fromJson(Map<String, dynamic> json) {
    final cs = json['config_summary'];
    final summary = cs is Map ? Map<String, dynamic>.from(cs) : json;
    return BackendStatusSummary(
      llmModel: summary['llm_model']?.toString(),
      llmProvider: summary['llm_provider']?.toString(),
      shortTermRounds: summary['short_term_rounds'] is num
          ? (summary['short_term_rounds'] as num).toInt()
          : null,
    );
  }

  final String? llmModel;
  final String? llmProvider;
  final int? shortTermRounds;
}

class BackendActiveCharacter {
  const BackendActiveCharacter({this.charId, this.name});

  factory BackendActiveCharacter.fromJson(Map<String, dynamic> json) {
    return BackendActiveCharacter(
      charId: json['char_id']?.toString(),
      name: json['name']?.toString(),
    );
  }

  final String? charId;
  final String? name;

  String get display {
    if (name != null && name!.isNotEmpty) return name!;
    if (charId != null && charId!.isNotEmpty) return charId!;
    return '（未知）';
  }
}

class BackendDreamSettingsSummary {
  const BackendDreamSettingsSummary({
    this.enableDreamLorebook,
    this.worldLayer,
    this.jailbreakPreset,
  });

  factory BackendDreamSettingsSummary.fromJson(Map<String, dynamic> json) {
    return BackendDreamSettingsSummary(
      enableDreamLorebook: json['enable_dream_lorebook'] as bool?,
      worldLayer: json['world_layer']?.toString(),
      jailbreakPreset: json['jailbreak_preset']?.toString(),
    );
  }

  final bool? enableDreamLorebook;
  final String? worldLayer;
  final String? jailbreakPreset;
}

String _formatDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _weekdayLabel(int weekday) {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  return labels[(weekday - 1).clamp(0, labels.length - 1)];
}

String _formatTodayLine(DateTime date) {
  return '今日 · ${date.month}月${date.day}日 · 周${_weekdayLabel(date.weekday)} · ${_formatDateTime(date)}';
}
