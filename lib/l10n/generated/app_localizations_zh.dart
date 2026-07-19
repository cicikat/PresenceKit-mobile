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

  @override
  String get localDeviceLabel => '本机';

  @override
  String get refreshAction => '刷新';

  @override
  String get loadingAction => '正在读取…';

  @override
  String get profileTitle => '角色资料';

  @override
  String profileEyebrow(String name) {
    return '$name · 本机显示';
  }

  @override
  String get profileAvatarConfigured => '本机头像已设置';

  @override
  String get profileAvatarDefault => '使用默认字母头像';

  @override
  String get profileNameAction => '备注名';

  @override
  String get profileAvatarAction => '头像';

  @override
  String get profileDefaultAction => '默认';

  @override
  String get profileNowSection => '此刻';

  @override
  String get profileNoActivity => '暂时没有特别的动向';

  @override
  String profileMoodStatus(String label, int percent) {
    return '心情：$label（$percent%）';
  }

  @override
  String get profileLocalNameTitle => '本机备注名';

  @override
  String get profileDefaultCharacterName => '默认角色名';

  @override
  String get profileLocalNameBody =>
      '只影响这台手机里的显示：顶部栏、抽屉、偏好页和 HIM 聊天气泡。不会写回后端，也不会改核心人格配置。';

  @override
  String get profileAvatarScopeTitle => '头像作用域';

  @override
  String get profileDefaultAvatar => '默认头像';

  @override
  String get profileAvatarScopeBody =>
      '头像保存在 App 私有目录，只作为手机端本地头像源。当前不会上传到后端，也不会同步到桌宠或其他客户端。';

  @override
  String get profileRealityCardTitle => 'Reality 角色卡';

  @override
  String get profileRealityCardBody => '切换后会影响主对话使用的人格卡；由后端保存并同步到其他客户端。';

  @override
  String get profileCurrentCardLabel => '当前角色卡';

  @override
  String get profileLoadCards => '读取角色卡';

  @override
  String get profileSyncBoundaryTitle => '同步边界';

  @override
  String get profileSyncBoundaryValue => '手机端覆盖显示';

  @override
  String get profileSyncBoundaryBody =>
      '后续如果要同步备注名到后端，建议单独做确认按钮；现在资料页保持轻客户端边界，避免误改核心配置。';

  @override
  String get profileDisplayLocationTitle => '显示位置';

  @override
  String get profileDisplayLocationValue => 'UI 已跟随';

  @override
  String profileDisplayLocationBody(String name) {
    return '顶部栏、抽屉、偏好页和$name消息头像都会读取这份本机资料。用户自己的头像设置仍独立处理。';
  }

  @override
  String profileFooterNotice(String name) {
    return '这页只管理手机薄客户端的外观身份。$name的核心人格、记忆和调度仍然以后端为准。';
  }

  @override
  String get activityTitle => '活动';

  @override
  String get activityEyebrow => '和他一起做点什么';

  @override
  String get activityReadingTitle => '一起看书';

  @override
  String get activityReadingSubtitle => '上传 PDF，翻页时聊两句';

  @override
  String get activityGomokuTitle => '五子棋';

  @override
  String get activityGomokuSubtitle => '对战角色 AI，触屏落子';

  @override
  String get activityChessTitle => '国际象棋';

  @override
  String get activityChessSubtitle => '对战角色 AI';

  @override
  String get activityDreamBuildTitle => '梦境预构';

  @override
  String get activityDreamBuildSubtitle => '出发前先聊聊今晚想做什么梦';

  @override
  String get activityChatPrompt => '说点什么，聊聊现在的进展';

  @override
  String get saySomethingHint => '说点什么…';

  @override
  String sendFailedMessage(String error) {
    return '（发送失败：$error）';
  }

  @override
  String get endAction => '结束';

  @override
  String get dreamBuildIntro =>
      '还没开始预构梦境。开始后可以先跟他聊聊今晚想梦到什么，结束时会把这段对话浓缩成一个种子，供入梦时参考。';

  @override
  String get dreamBuildStart => '开始预构';

  @override
  String get dreamBuildChatTitle => '预构对话';

  @override
  String get openChatAction => '打开对话';

  @override
  String get diaryAllFilter => '全部';

  @override
  String get diaryTitle => '日记';

  @override
  String diaryEyebrow(String name) {
    return '$name · 私写';
  }

  @override
  String get syncingStatus => '同步中';

  @override
  String get syncedStatus => '已同步';

  @override
  String get diarySearchHint => '搜索 · 关键词 / 日期 / 心情';

  @override
  String get retryAction => '重试';

  @override
  String get diaryLoadingList => '正在从后端读取日记列表…';

  @override
  String get diaryEmpty => '他还没开始写日记。';

  @override
  String get diaryNoResults => '找不到对应的日记。';

  @override
  String diaryRecentRefreshError(String error) {
    return '最近刷新失败：$error';
  }

  @override
  String get diaryOpenToLoad => '点开条目后再读取正文。';

  @override
  String get diaryTapToLoad => '点击读取正文';

  @override
  String get loadingStatus => '加载中…';

  @override
  String get noData => '无数据';

  @override
  String loadFailedMessage(String error) {
    return '加载失败：$error';
  }

  @override
  String get gardenTitle => '陪伴花园';

  @override
  String gardenEyebrow(String name) {
    return '$name · 状态花园';
  }

  @override
  String get gardenShortTitle => '花园';

  @override
  String get gardenLoadingDescription => '正在读取后端花园状态。';

  @override
  String get gardenErrorDescription => '花园同步失败，稍后可以重新刷新。';

  @override
  String get gardenLoadedDescription => '已读取后端花园状态。它在你不看的时候，也在生长。';

  @override
  String get gardenNotLoadedDescription => '还没有读取到后端花园状态。';

  @override
  String get gardenDominantMood => '他现在 · 主导心境';

  @override
  String get waitingStatus => '等待';

  @override
  String get gardenWaitingData => '等待后端花园数据';

  @override
  String get gardenSyncing => '正在同步花园';

  @override
  String get syncFailedStatus => '同步失败';

  @override
  String get gardenAutoRefresh => '后端 · 每 30 秒自动刷新';

  @override
  String get notSyncedStatus => '尚未同步';

  @override
  String get gardenRefreshTooltip => '刷新花园';

  @override
  String get gardenSyncingMessage => '正在同步花园…';

  @override
  String get gardenEmpty => '暂无花园数据';

  @override
  String get gardenWaitingSlot => '等待后端返回花园槽位。';

  @override
  String gardenStageSummary(
    String mood,
    int percent,
    String harvest,
    String vase,
  ) {
    return '$mood 槽位最接近下一阶段 · $percent% · 收获 $harvest · 花瓶 $vase';
  }

  @override
  String dreamHeaderTitle(String name) {
    return '梦 · $name';
  }

  @override
  String get dreamInProgress => '进行中';

  @override
  String get dreamReady => 'DREAM · READY';

  @override
  String get dreamWakeAction => '醒来';

  @override
  String dreamConnectionError(String error) {
    return '梦境连接异常 · $error';
  }

  @override
  String get dreamResponding => '梦在回应';

  @override
  String get dreamStability => '稳定度';

  @override
  String get dreamDepth => '深度';

  @override
  String get dreamFindingEntrance => '正在寻找梦境入口';

  @override
  String get dreamEntranceOpen => '梦境入口已经打开';

  @override
  String get dreamEntranceDescription => '进入后，对话会暂时停在更轻、更慢的地方。这里与主对话消息流彼此独立。';

  @override
  String dreamValidCount(int count) {
    return '已经做过 $count 次有效的梦';
  }

  @override
  String get dreamEntering => '坠入中…';

  @override
  String get dreamEnterAction => '进入梦境';

  @override
  String get dreamComposerHint => '在这儿写点什么…';

  @override
  String get dreamWaitingBehindDoor => '梦在门后等待';
}
