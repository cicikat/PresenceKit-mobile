// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '陪伴';

  @override
  String get appErrorTitle => '页面出了点问题';

  @override
  String get backHome => '回到主界面';

  @override
  String get retry => '重试';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsGeneralSection => '通用';

  @override
  String get settingsLanguageTitle => '语言';

  @override
  String get settingsLanguageSubtitle => '切换后立即生效，并保存到本机';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsConnectionAccountSection => '连接与账户';

  @override
  String get settingsAccessTokenTitle => '访问 Token';

  @override
  String get settingsAccessTokenConfigured => '已设置 · 保存在本机 Android 私有存储';

  @override
  String get settingsAccessTokenMissing => '尚未设置 · 连接后端前必须填写';

  @override
  String get settingsReplaceAction => '更换';

  @override
  String get settingsSetAction => '设置';

  @override
  String get drawerClientSubtitle => '手机薄客户端 · 本机显示';

  @override
  String get drawerPagesSection => '页面';

  @override
  String get drawerChatTitle => '主对话';

  @override
  String get drawerChatSubtitle => '聊天窗口';

  @override
  String get drawerDreamTitle => '梦境';

  @override
  String get drawerDreamSubtitle => '独立的 Dream 对话';

  @override
  String get drawerProfileTitle => '角色资料';

  @override
  String get drawerProfileSubtitle => '本机备注和头像';

  @override
  String drawerDiaryTitle(String name) {
    return '$name的日记';
  }

  @override
  String get drawerDiarySubtitle => '他写给自己的';

  @override
  String get drawerActivityTitle => '活动';

  @override
  String get drawerActivitySubtitle => '看书 / 五子棋 / 国际象棋 / 梦境预构';

  @override
  String get drawerGroupTitle => '群聊';

  @override
  String get drawerGroupSubtitle => '多角色一起聊';

  @override
  String get drawerGrowthSection => '养成';

  @override
  String get drawerGardenTitle => '状态花园';

  @override
  String get drawerGardenSubtitle => '他今天的心境';

  @override
  String get drawerSettingsTitle => '设置';

  @override
  String get drawerSettingsSubtitle => '连接、通知、外观与对话配置';

  @override
  String get drawerCurrent => '当前';

  @override
  String get presenceOnline => '在场';

  @override
  String get presenceMobileOnline => '手机端在线';

  @override
  String get presenceReady => '就绪';

  @override
  String get presenceChatting => '聊天';

  @override
  String get presenceNow => '现在';

  @override
  String get backTooltip => '返回';

  @override
  String get chatLoadingOlder => '正在加载更早的对话…';

  @override
  String chatHiddenOlder(int count) {
    return '已折叠 $count 条更早对话 · 上滑继续展开';
  }

  @override
  String get chatLoadingHistory => '正在从后端读取聊天记录';

  @override
  String get chatEmptyHistory => '后端已连接 · 暂无聊天记录';

  @override
  String chatHistoryError(String error) {
    return '历史加载失败 · $error';
  }

  @override
  String get chatWaitingReply => '已送到后端 · 正在等他回话';

  @override
  String chatBackendError(String error) {
    return '后端连接异常 · $error';
  }

  @override
  String chatBackendStatus(String emotion, int affection) {
    return '后端已接入 · $emotion · 好感 $affection';
  }

  @override
  String chatMobileReceived(int count) {
    return '已接收 $count 条主动消息';
  }

  @override
  String get chatTyping => '正在输入';

  @override
  String get drawerTooltip => '抽屉';

  @override
  String get preferencesTooltip => '偏好';

  @override
  String get switchToLightTooltip => '切到白天';

  @override
  String get switchToDarkTooltip => '切到夜里';

  @override
  String get copyAction => '复制';

  @override
  String get selectAllAction => '全选';

  @override
  String get replyAction => '回复';

  @override
  String get cancelReplyTooltip => '取消回复';

  @override
  String get imageAttachment => '图片附件';

  @override
  String get fileAttachment => '文件附件';

  @override
  String get composerPlaceholder => '对他说些什么…';

  @override
  String get attachmentTooltip => '附件';

  @override
  String get releaseToSendTooltip => '松开发送';

  @override
  String get holdToTalkTooltip => '长按说话';

  @override
  String get waitAction => '等待';

  @override
  String get sendAction => '寄出';

  @override
  String characterCount(int count) {
    return '$count 字';
  }

  @override
  String get settingsBackendNodeTitle => '后端节点与用户 ID';

  @override
  String settingsBackendNodeSubtitle(String baseUrl, String userId) {
    return '$baseUrl · 用户 $userId';
  }

  @override
  String get settingsEditBackendTooltip => '修改后端地址';

  @override
  String get settingsRelayTitle => '推送中继 ntfy';

  @override
  String get settingsRelaySubtitle => '中继只承载新消息信号，正文会从已鉴权后端回源读取。';

  @override
  String get settingsEditRelayTooltip => '修改中继地址';

  @override
  String get settingsNotificationsSection => '通知与主动性';

  @override
  String get settingsBackgroundNotificationsTitle => '后台通知';

  @override
  String get settingsBackgroundNotificationsSubtitle =>
      '中继实时订阅 · 长时间断线周期补偿 · 静音/冷却';

  @override
  String get settingsNotificationTestTitle => '通知闸门测试模式（仅调试）';

  @override
  String get settingsNotificationTestSubtitle => '仅绕过静音时段和 30 分钟冷却，不改变消息消费逻辑。';

  @override
  String get settingsAppearanceSection => '外观与显示';

  @override
  String get settingsProfileTitle => '角色资料';

  @override
  String get settingsProfileSubtitle => '本机备注和头像 · 资料页有完整说明';

  @override
  String get settingsOpenProfileTooltip => '打开角色资料页';

  @override
  String get settingsEditProfileNameTooltip => '设置本机备注名';

  @override
  String get settingsImportAvatarTooltip => '导入并裁切头像';

  @override
  String get settingsResetAvatarTooltip => '恢复默认头像';

  @override
  String get settingsThemeTitle => '外观主题';

  @override
  String settingsThemeBuiltInSubtitle(int count) {
    return '信纸 · 夜间 · $count 个颜色预设';
  }

  @override
  String settingsThemePresetSubtitle(String name, int count) {
    return '当前：$name · 共 $count 个预设';
  }

  @override
  String get themePaper => '信纸';

  @override
  String get themeNight => '夜间';

  @override
  String settingsColorPresets(int count) {
    return '颜色预设 ($count)';
  }

  @override
  String get settingsInfoStripTitle => '对话信息栏';

  @override
  String get settingsInfoStripSubtitle => '控制主页整块深绿色状态区';

  @override
  String get settingsFontSizeTitle => '正文字号';

  @override
  String settingsFontSizeSubtitle(int size) {
    return '${size}px · 影响气泡和正文段落';
  }

  @override
  String get settingsShowAvatarTitle => '显示我的头像';

  @override
  String get settingsShowAvatarSubtitle => '对话气泡右侧也放小头像';

  @override
  String get settingsProactiveRateTitle => '主动消息频率';

  @override
  String get settingsProactiveRateSubtitle => '控制后台主动提醒的大致密度';

  @override
  String get rateLow => '少';

  @override
  String get rateMedium => '适中';

  @override
  String get rateHigh => '多';

  @override
  String get settingsNightSilentTitle => '夜深时段静音';

  @override
  String get settingsNightSilentSubtitle => '他在 23:30 到 06:30 不主动找你';

  @override
  String get settingsChatContentSection => '对话内容配置';

  @override
  String get settingsChatLorebookTitle => 'Chat 世界书';

  @override
  String get settingsChatLorebookSubtitle => 'Reality 对话使用 · 多选';

  @override
  String get settingsChatJailbreakTitle => 'Chat 破限';

  @override
  String get settingsChatJailbreakSubtitle => 'Reality 独立破限 · 多选';

  @override
  String get settingsDreamLorebookTitle => 'Dream 世界书';

  @override
  String get settingsDreamLorebookSubtitle => 'Dream 独立 Lorebook 开关';

  @override
  String get settingsDreamWorldTitle => 'Dream 世界层';

  @override
  String get settingsDreamWorldSubtitle => '下一次入梦时使用';

  @override
  String get dreamWorldRealityDerived => '现实派生';

  @override
  String get dreamWorldAbo => 'ABO';

  @override
  String get dreamWorldVampire => '吸血鬼';

  @override
  String get dreamWorldCat => '猫';

  @override
  String get dreamWorldFlowerBud => '花苞';

  @override
  String get customOption => '自定义';

  @override
  String get settingsDreamJailbreakTitle => 'Dream 破限';

  @override
  String get settingsDreamJailbreakSubtitle => 'Dream 独立 D0 预设';

  @override
  String get defaultOption => '默认';

  @override
  String settingsBackendSaveError(String error) {
    return '后端设置读取/保存失败：$error';
  }

  @override
  String get settingsDiagnosticsSection => '诊断';

  @override
  String get settingsCapabilitiesTitle => '能力检查';

  @override
  String get settingsCapabilitiesSubtitle => '权限状态、后端连通、中继与同步状态';

  @override
  String get openAction => '打开';

  @override
  String get settingsThinClientNotice => '手机端负责聊天、通知、悬浮窗和本机显示；人格、记忆与调度仍由后端维护。';
}
