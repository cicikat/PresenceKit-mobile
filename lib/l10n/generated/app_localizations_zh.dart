// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get screenObservationTitle => '允许角色按需截图';

  @override
  String get screenObservationHint =>
      '手机活跃且未锁屏时，允许按请求截图并发送到已配置的视觉服务，返回隐私过滤后的概括。需同时开启后端按需截图，与屏幕文字分享独立。';

  @override
  String get screenObservationRequirements =>
      '需要 Android 11 或更新版本及无障碍权限。锁屏时不会截图。';

  @override
  String get screenObservationFailed => '无法读取或保存截图授权，请重新打开此页面重试。';

  @override
  String get settingsShowChatTimeTitle => '显示聊天时间';

  @override
  String get settingsShowChatTimeSubtitle => '显示角色和自己的消息时间';

  @override
  String get settingsSystemModule => '系统配置';

  @override
  String get settingsDreamMemory => '记忆范围';

  @override
  String get settingsDreamCardOnly => '仅角色卡';

  @override
  String get settingsDreamRelationship => '关系摘要';

  @override
  String get settingsDreamSnapshot => '完整快照';

  @override
  String get settingsDreamBoundary => '感知边界';

  @override
  String get settingsDreamVague => '模糊';

  @override
  String get settingsDreamBody => '身体可感知';

  @override
  String get settingsDreamNumbers => '数值可见';

  @override
  String get settingsDreamThreshold => '阈值突破';

  @override
  String get settingsDreamLucidity => '清明模式';

  @override
  String get settingsDreamLucid => '清明共享';

  @override
  String get settingsDreamNonLucid => '非清明';

  @override
  String get settingsDreamModule => '梦境设置';

  @override
  String get settingsPermissionsTitle => '权限与功能';

  @override
  String get settingsSetupComplete => '已配置';

  @override
  String get settingsSetupHelp =>
      '本端仅为前端，需在自己的电脑或服务器上部署后端。完成后端鉴权初始化后，获取 mobile 访问 Token，再填写节点和用户 ID。';

  @override
  String get settingsDreamBackgroundTitle => '梦境背景';

  @override
  String get settingsDreamNextEntry => '下次入梦生效，梦境中不可修改';

  @override
  String get settingsDreamUnavailable => '尚未读取梦境设置，请配置连接后重试';

  @override
  String get lifeTitle => '生活记录';

  @override
  String get lifeStaleEditor => '记录在编辑期间已更新。请先复制要保留的修改，关闭后重新打开最新记录再校正。';

  @override
  String get lifeForegroundOnly => '电脑端仅允许前台同步，请打开本页后点击立即同步。';

  @override
  String get lifeSubtitle => '饮食 · 账单 · 购物车';

  @override
  String get lifeIntro => '拍照留存，由电脑整理。按日期回看，随时校正识别内容。';

  @override
  String get lifeDiet => '饮食';

  @override
  String get lifeBill => '账单';

  @override
  String get lifeCart => '购物车';

  @override
  String get lifeAll => '全部';

  @override
  String get lifeCamera => '拍一张';

  @override
  String get lifeGallery => '选图片';

  @override
  String get lifeSync => '立即同步';

  @override
  String get lifeQueue => '同步与队列';

  @override
  String get lifeSearch => '搜索名称、备注、明细';

  @override
  String get lifeDateRange => '选择日期范围';

  @override
  String get lifeClearDates => '全部日期';

  @override
  String get lifeEmpty => '暂无符合条件的记录。可以先拍照或上传截图。';

  @override
  String get lifeCacheOnly => '当前显示本机缓存；联网查询可查看电脑上的历史记录。';

  @override
  String get lifeServerResults => '已查询电脑记录；未同步的本机修改同时显示。';

  @override
  String get lifeCartHelp => '购物车暂支持上传淘宝等 App 的截图，不会自动读取账号或下单。';

  @override
  String get lifeBackgroundHelp =>
      '联网后自动补传。后台由 Android 安排，省电、强行停止等可能延后；重新打开 App 会继续。';

  @override
  String lifePendingCount(int count) {
    return '待同步 $count 项';
  }

  @override
  String lifeLastAck(String time) {
    return '最近同步成功：$time';
  }

  @override
  String get lifeConnected => '电脑已连接';

  @override
  String get lifeWaiting => '等待连接电脑';

  @override
  String get lifeAuth => '访问凭证无效，请在设置中更新；记录已保留。';

  @override
  String get lifeForbidden => '凭证权限不足，请在电脑端检查授权；记录已保留。';

  @override
  String get lifeNotIntegrated => '电脑尚未接入生活记录；图片和修改保留在本机等待同步。';

  @override
  String get lifeDisabled => '电脑端尚未启用生活记录；本机内容已保留。';

  @override
  String get lifeSetup => '请先在设置中配置可信后端节点、用户 ID 和访问凭证。';

  @override
  String get lifeAccountChanged => '节点或用户已切换，请回到原节点与用户后再保存。';

  @override
  String get lifeConflict => '电脑记录已变更，需要处理版本冲突。';

  @override
  String get lifeQueueFull => '本机队列已满（200 项或 100 MiB 图片），请先同步或删除待上传记录。';

  @override
  String get lifeImageTooLarge => '图片超过 10 MiB，请裁切或压缩后重试。';

  @override
  String get lifeImageFormat => '请使用 JPEG、PNG 或 WebP 图片。';

  @override
  String get lifeAndroidOnly => '拍照、离线存储和同步目前仅支持 Android。';

  @override
  String get lifeRejected => '同步被拒绝或返回格式不符；内容已保留，可检查后重试。';

  @override
  String get lifeRateLimited => '电脑暂时限流，稍后自动重试。';

  @override
  String get lifeStorageError => '读取或保存失败，请检查存储空间后重试。';

  @override
  String get lifeOffline => '暂时连不上电脑，已保存的内容将在恢复连接后重试。';

  @override
  String get lifeCaptureFailed => '未能获取图片，请检查相机或相册权限后重试。';

  @override
  String get lifeUntitled => '待整理记录';

  @override
  String get lifeQueued => '已存本机 · 等待同步';

  @override
  String get lifeDeleting => '等待同步删除';

  @override
  String get lifeRecognized => '已识别 · 可校正';

  @override
  String get lifeRecognitionFailed => '电脑识别失败，可手动补充明细。';

  @override
  String get lifeRecognizing => '已上传 · 等待电脑识别';

  @override
  String get lifeEdit => '查看 / 校正';

  @override
  String get lifeAdd => '新增生活记录';

  @override
  String get lifeDelete => '删除记录';

  @override
  String get lifeDeleteHelp => '确认删除这条记录？未上传的记录会从本机移除；已上传的记录会排队请求电脑删除。';

  @override
  String get lifeAcceptServer => '采用电脑版本';

  @override
  String get lifeConflictHelp =>
      '将放弃这条记录尚未同步的本机修改，采用电脑返回的版本。可以先复制要保留的内容，之后再校正。';

  @override
  String get lifeConfirm => '确认';

  @override
  String get lifeCancel => '取消';

  @override
  String get lifeClose => '关闭';

  @override
  String get lifeMore => '加载更多';

  @override
  String get lifeConsent => '保存即同意将本图及记录上传到下方电脑节点，供识别、存储及已获授权的角色查询。离线时先保存在本机。';

  @override
  String get lifeCategory => '分类';

  @override
  String get lifeDate => '记录日期';

  @override
  String get lifeRecordTitle => '标题（可留空待识别）';

  @override
  String get lifeNote => '备注 / 识别补充';

  @override
  String get lifeItems => '结构化明细（不确定的内容可留空）';

  @override
  String get lifeItemName => '食物 / 商品 / 账目名称';

  @override
  String get lifeQuantity => '数量 / 份量';

  @override
  String get lifeUnit => '单位（份、克、件等）';

  @override
  String get lifeAmount => '金额（退款可填负数）';

  @override
  String get lifeCurrency => '币种（如 CNY、USD）';

  @override
  String get lifeRequired => '请填写名称';

  @override
  String get lifeCurrencyRequired => '填写金额时必须提供三字母币种';

  @override
  String get lifeNumberInvalid => '请输入有效数字；数量必须大于零';

  @override
  String get lifeRemoveItem => '移除此项';

  @override
  String get lifeAddItem => '添加明细';

  @override
  String get lifeSaving => '保存中…';

  @override
  String get lifeSave => '保存并排队同步';

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
  String get settingsAccessTokenConfigured => '已配置';

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
  String drawerVersionLabel(String version) {
    return '版本号 $version';
  }

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
  String chatBackendStatus(String emotion) {
    return '后端已接入 · $emotion';
  }

  @override
  String chatMobileReceived(int count) {
    return '已接收 $count 条主动消息';
  }

  @override
  String get chatTyping => '正在输入';

  @override
  String get chatRoleHim => '他';

  @override
  String get chatRoleYou => '我';

  @override
  String get chatTodayDivider => '今天';

  @override
  String get chatYesterdayDivider => '昨天';

  @override
  String chatReplyTo(Object name) {
    return '回复 $name';
  }

  @override
  String get chatRetry => '重试';

  @override
  String get chatSendFailed => '发送失败';

  @override
  String chatUnreadCount(Object count) {
    return '$count 条未读';
  }

  @override
  String get chatVoiceHint => '按住说话，松手填入';

  @override
  String get chatVoiceCancelled => '已取消';

  @override
  String get voiceRecordingActive => '正在录音，请先松手';

  @override
  String get voicePermissionDenied => '麦克风权限未开启';

  @override
  String get voiceStartFailed => '无法开始录音';

  @override
  String get voiceNotActive => '当前没有正在进行的录音';

  @override
  String get voiceRecordingFailed => '录音失败';

  @override
  String get voiceCredentialRequired => '语音转写需要先配置访问凭证';

  @override
  String get voiceTranscriptionFailed => '语音转写失败';

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
  String get stickerLoadFailed => '表情包加载失败';

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
  String get settingsRelaySubtitle => '配置后台推送连接';

  @override
  String get settingsEditRelayTooltip => '修改中继地址';

  @override
  String get settingsNotificationsSection => '通知与主动性';

  @override
  String get settingsBackgroundNotificationsTitle => '后台通知';

  @override
  String get settingsBackgroundNotificationsSubtitle => '离开应用后继续接收消息';

  @override
  String get settingsNotificationTestTitle => '通知闸门测试模式（仅调试）';

  @override
  String get settingsNotificationTestSubtitle => '临时跳过 30 分钟提醒冷却';

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
  String get settingsChatLorebookSubtitle => 'Reality 对话当前启用项 · 多选与启停，不提供编辑';

  @override
  String get settingsChatJailbreakTitle => 'Chat 破限';

  @override
  String get settingsChatJailbreakSubtitle => 'Reality 当前启用项 · 多选与启停，不提供编辑';

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
  String get profileStatusUpdating => '正在刷新状态…';

  @override
  String profileStatusLastUpdated(String time) {
    return '最后成功更新：$time';
  }

  @override
  String profileStatusLoadError(String error) {
    return '状态刷新失败，正在显示上次成功值：$error';
  }

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

  @override
  String get cancelAction => '取消';

  @override
  String get deleteAction => '删除';

  @override
  String get saveAction => '保存';

  @override
  String get savingAction => '保存中…';

  @override
  String get closeAction => '关闭';

  @override
  String get startGameAction => '开局';

  @override
  String groupDeleteTitle(String title) {
    return '删除「$title」？';
  }

  @override
  String get groupDeleteWarning => '聊天记录一并清除，不可恢复。';

  @override
  String get groupTitle => '群聊';

  @override
  String get groupEyebrow => '多角色一起聊';

  @override
  String get groupCreateAction => '新建群聊';

  @override
  String get groupEmpty => '还没有群聊';

  @override
  String groupRosterDeleteHint(String members) {
    return '$members · 长按删除';
  }

  @override
  String get groupSelectAtLeastOne => '至少选择 1 位角色';

  @override
  String groupSelectedCount(int count) {
    return '选择成员（已选 $count 位）';
  }

  @override
  String get groupNoCharacters => '暂无可用角色';

  @override
  String groupMinResponders(int count) {
    return 'N 最少回应人数：$count';
  }

  @override
  String groupMaxResponders(int count) {
    return 'M 最多回应人数：$count';
  }

  @override
  String get groupCreating => '建群中…';

  @override
  String get groupConfirmCreate => '确认建群';

  @override
  String get groupSendToStart => '发送消息，开始群聊';

  @override
  String get groupMembersResponding => '成员陆续回应中…';

  @override
  String get groupSendHint => '发送消息…';

  @override
  String get groupKeepAtLeastOne => '至少保留 1 位成员';

  @override
  String get groupSettingsTitle => '群设置';

  @override
  String groupManagingCount(int count) {
    return '成员管理（已选 $count 位）';
  }

  @override
  String get groupDreamEnterAction => '入梦';

  @override
  String get groupDreamTitle => '群聊梦境';

  @override
  String get groupDreamEntering => '坠入中…';

  @override
  String get groupDreamEnterFailed => '后端没有允许这次入梦';

  @override
  String get groupDreamSendToStart => '发送消息，开始群聊梦境';

  @override
  String get groupDreamMembersResponding => '角色们陆续回应中…';

  @override
  String get groupDreamSendHint => '在梦中说些什么…';

  @override
  String get groupDreamExitAction => '醒来';

  @override
  String get groupDreamExitConfirmTitle => '确定要醒来吗？';

  @override
  String get groupDreamExitConfirmBody => '退出后本轮群聊梦境立即结束，无法继续。';

  @override
  String get groupDreamBlockedHint => '群聊梦境进行中，现实对话暂时锁定';

  @override
  String readingDeleteTitle(String title) {
    return '删除《$title》？';
  }

  @override
  String get irreversibleWarning => '此操作不可撤销。';

  @override
  String get readingInProgress => '阅读中';

  @override
  String get readingTogetherTitle => '一起看书';

  @override
  String get readingChatTitle => '看书聊天';

  @override
  String get readingLibrary => '书库';

  @override
  String get readingAdding => '添加中…';

  @override
  String get readingAddPdf => '添加 PDF';

  @override
  String get readingEmptyLibrary => '书库还是空的，先添加一本 PDF 吧';

  @override
  String readingBookPages(String pages) {
    return '$pages 页 · 长按删除';
  }

  @override
  String readingPageStatus(String current, String total) {
    return '第 $current 页 / 共 $total 页';
  }

  @override
  String get readingLoadingPage => '加载页面内容…';

  @override
  String get readingPreviousPage => '← 上一页';

  @override
  String get readingNextPage => '下一页 →';

  @override
  String get chessTitle => '国际象棋';

  @override
  String get chessIntro => '和他下一局国际象棋。你执白先行，点棋子选中，再点目标格落子。';

  @override
  String chessGameOver(String result) {
    return '对局结束：$result';
  }

  @override
  String chessTurn(String side) {
    return '当前走子方：$side';
  }

  @override
  String get whiteSide => '白方';

  @override
  String get blackSide => '黑方';

  @override
  String get gameChatTitle => '棋局闲聊';

  @override
  String get gomokuTitle => '五子棋';

  @override
  String get gomokuIntro => '和他下一局五子棋。你先手，触屏落子。';

  @override
  String get drawResult => '平局';

  @override
  String gomokuWinner(String stone) {
    return '$stone 获胜';
  }

  @override
  String gomokuTurn(String stone) {
    return '当前落子方：$stone';
  }

  @override
  String get blackStone => '黑棋';

  @override
  String get whiteStone => '白棋';

  @override
  String get boardLoading => '棋盘加载中…';

  @override
  String get themePresetsTitle => '颜色预设';

  @override
  String get themePresetsDescription => '分别选择日间和夜间配色，可导入或导出 JSON。';

  @override
  String get newAction => '新建';

  @override
  String get themeNoCustomPresets => '还没有自定义预设';

  @override
  String get themeBundledReadOnly => 'mods/ 内置 · 只读';

  @override
  String themeLocalPreset(String base) {
    return '$base底色 · 本机预设';
  }

  @override
  String get themeCopyEdit => '复制并编辑';

  @override
  String get editAction => '编辑';

  @override
  String get themeResetColors => '重置颜色';

  @override
  String get themeExportMod => '导出 mod';

  @override
  String get themeDeleteTitle => '删除颜色预设？';

  @override
  String themeDeleteWarning(String name) {
    return '“$name”会从本机删除，此操作无法撤销。';
  }

  @override
  String get themeExportSuccess => '主题 JSON 已导出';

  @override
  String get exportFailed => '导出失败';

  @override
  String get themeEditTitle => '编辑颜色预设';

  @override
  String get themePresetNameLabel => '预设名称';

  @override
  String get themeComponentColors => '组件颜色';

  @override
  String get themeFreeColor => '自由选色';

  @override
  String themeHue(int value) {
    return '色相 $value°';
  }

  @override
  String themeOpacity(int value) {
    return '透明度 $value%';
  }

  @override
  String get themeApplyRgbTooltip => '应用 RGB';

  @override
  String get previewLabel => '预览';

  @override
  String get themeCharacterPreview => '角色消息与正文颜色';

  @override
  String get themeUserPreview => '用户消息颜色';

  @override
  String get themeDefaultName => '我的配色';

  @override
  String get themeNewTitle => '新建颜色预设';

  @override
  String get nameLabel => '名称';

  @override
  String get themeLightBase => '信纸底色';

  @override
  String get themeDarkBase => '夜间底色';

  @override
  String get createAction => '创建';

  @override
  String get avatarCropTitle => '裁切头像';

  @override
  String get chatBackgroundEditorTitle => '聊天背景';

  @override
  String get chatBackgroundCropHelp => '拖动调整位置，双指或手势缩放；背景仅保存在本机。';

  @override
  String get chatBackgroundBlurLabel => '背景模糊';

  @override
  String get chatBubbleOpacityLabel => '聊天框透明度';

  @override
  String get settingsChatBackgroundTitle => '聊天背景';

  @override
  String get settingsChatBackgroundSubtitle => '导入图片、裁切并调整模糊与聊天框透明度';

  @override
  String get settingsImportChatBackgroundTooltip => '导入聊天背景';

  @override
  String get settingsResetChatBackgroundTooltip => '恢复默认聊天背景';

  @override
  String get chatBackgroundSaveFailed => '聊天背景保存失败';

  @override
  String get avatarCropHelp => '拖动调整位置，双指或手势缩放。保存后只作为手机端本地头像。';

  @override
  String get resetAction => '重置';

  @override
  String get closeTooltip => '关闭';

  @override
  String get themeCustomPaletteTitle => '自定义色盘';

  @override
  String themeEditingRole(String role) {
    return '正在修改：$role';
  }

  @override
  String get themePreviewBody => '这套颜色会应用到聊天、抽屉和设置组件。';

  @override
  String get themeSidebarPreview => '侧边栏背景 / 文字图标 / 选中态';

  @override
  String get themeUserBubblePreview => '用户气泡也会跟着变。';

  @override
  String get noOptions => '暂无可用项';

  @override
  String get attachmentSheetTitle => '附加内容';

  @override
  String get attachmentDocument => '文档';

  @override
  String get attachmentDocumentSubtitle => 'txt / md / docx · 5MB 内';

  @override
  String get attachmentImage => '图片';

  @override
  String get attachmentImageSubtitle => '可多选 · 走后端视觉识别';

  @override
  String get themeRoleSurface => '页面底色';

  @override
  String get themeRoleSurfaceSoft => '输入栏底色';

  @override
  String get themeRoleSurfaceDeep => '深层底色';

  @override
  String get themeRoleSurfaceEdge => '边框线';

  @override
  String get themeRoleInk1 => '主文字';

  @override
  String get themeRoleInk2 => '次文字';

  @override
  String get themeRoleInk3 => '弱文字';

  @override
  String get themeRoleInk4 => '淡线条';

  @override
  String get themeRoleCharacter => '角色主色/焦点';

  @override
  String get themeRoleCharacterDeep => '顶部/侧边栏';

  @override
  String get themeRoleCharacterSoft => '选中项/柔底';

  @override
  String get themeRoleCharacterOn => '侧边栏文字';

  @override
  String get themeRoleDanger => '危险提示';

  @override
  String get themeRoleWarn => '提醒提示';

  @override
  String get themeRoleOk => '正常提示';

  @override
  String get themeRoleSend => '发送按钮';

  @override
  String get themeRoleUserBubble => '用户气泡';

  @override
  String get themeRoleUserBubbleText => '用户气泡文字';

  @override
  String get themeRoleScrim => '遮罩颜色';

  @override
  String get backendInvalidAddress => '后端地址格式不对';

  @override
  String get tokenSetTitle => '设置访问 Token';

  @override
  String get tokenReplaceTitle => '设置 / 更换 Token';

  @override
  String get tokenHelp =>
      '填后端签发的 mobile token（emt_ 开头）；旧 admin secret 仍可用但不建议。Token 只保存在 Android 本机私有存储中，不会打包进应用。';

  @override
  String get tokenRequiredError => '请填写访问 Token';

  @override
  String saveFailedMessage(String error) {
    return '保存失败：$error';
  }

  @override
  String get deviceAdminRequired => '请先启用“陪伴锁屏确认”的设备管理器权限';

  @override
  String get accessibilityAuthorized => '陪伴操作助手已授权';

  @override
  String shoppingAppMissing(String label) {
    return '没有找到 $label，先手动安装或确认包名';
  }

  @override
  String orderBubbleShown(String label) {
    return '已弹出 $label 购物车确认悬浮窗';
  }

  @override
  String get overlayPermissionRequired => '请先允许“显示在其他应用上层”，回来后再点一次';

  @override
  String screenPushFailed(String error) {
    return '屏幕上下文推送失败：$error';
  }

  @override
  String get accessibilityRequiredForScreen => '请先开启无障碍服务，才能读取屏幕上下文';

  @override
  String get screenContextEmpty => '暂时没有可读的屏幕上下文';

  @override
  String behaviorTestQueued(String label) {
    return '已写入主动行为测试：$label';
  }

  @override
  String behaviorTestFailed(String error) {
    return '主动行为测试失败：$error';
  }

  @override
  String get profileNameHint => '留空则显示后端角色名';

  @override
  String get restoreDefaultAction => '恢复默认';

  @override
  String get avatarSaveFailed => '头像保存失败';

  @override
  String get backendNodeTitle => '后端节点';

  @override
  String get backendNodeHelp => '插线调试用 127.0.0.1；脱线使用电脑局域网 IP。';

  @override
  String get userIdLabel => '用户 ID';

  @override
  String get userIdHint => 'QQ 号或后端约定的 uid，仅限字母数字下划线短横线';

  @override
  String get invalidAddressError => '请输入有效地址';

  @override
  String get userIdInvalidError => '仅支持字母、数字、下划线、短横线';

  @override
  String get saveReconnectAction => '保存并重连';

  @override
  String get relayDialogTitle => '推送中继（ntfy）';

  @override
  String get relayAddressLabel => '中继地址';

  @override
  String get relayTopicHint => '例：mychar-wake-a1b2c3（当作密码，用随机串）';

  @override
  String get relayTokenLabel => 'token（可选）';

  @override
  String get relayTokenHint => '中继服务无鉴权时留空';

  @override
  String get relayHelp =>
      '需与后端 config.yaml 的 relay_base_url/relay_topic/relay_token 三项一致。留空 topic 会关闭中继实时唤醒，退化为周期补偿轮询。';

  @override
  String get relayTopicInvalidError => '仅支持小写字母、数字、/ _ -，且不超过 128 字符';

  @override
  String get untrustedAddressError => '未信任该地址';

  @override
  String get dreamLeaveTitle => '要走了吗';

  @override
  String get dreamStayFallback => '再待一会儿吧。';

  @override
  String get dreamLeaveAction => '还是要走';

  @override
  String get dreamStayAction => '留下';

  @override
  String get fileTypeUnsupported => '后端当前只支持 txt / md / docx';

  @override
  String get fileTooLarge => '后端文件上限是 5MB';

  @override
  String get fileFailureLabel => '文件';

  @override
  String get imageTypeUnsupported =>
      '后端当前只支持 jpg / png / gif / webp / heic / bmp';

  @override
  String get imageTooLarge => '后端图片上限是单张 10MB';

  @override
  String imageCountPreview(int count, String names, String suffix) {
    return '📎 $count张图片：$names$suffix';
  }

  @override
  String get imageFailureLabel => '图片';

  @override
  String get meituanName => '美团';

  @override
  String get taobaoName => '淘宝';

  @override
  String get capabilityTitle => '能力检查';

  @override
  String get capabilityRefreshTooltip => '重新检测';

  @override
  String get capabilityLoading => '正在读取系统状态…';

  @override
  String get capabilityUnavailable => '暂时读不到状态，稍后再试。';

  @override
  String get capabilityNotificationTitle => '通知权限';

  @override
  String get capabilityNotificationSubtitle => '允许系统通知，后台主动消息才能弹出来。';

  @override
  String get enabledStatus => '已开启';

  @override
  String get disabledStatus => '已关闭';

  @override
  String get enableAction => '去开启';

  @override
  String get configureAction => '去设置';

  @override
  String get authorizeAction => '去授权';

  @override
  String get authorizedStatus => '已豁免';

  @override
  String get capabilityBatteryTitle => '电池优化豁免';

  @override
  String get capabilityBatteryEnabled => '已允许后台持续运行；仍建议检查厂商自启动与后台白名单。';

  @override
  String get capabilityBatteryDisabled => '未豁免：息屏或 Doze 时后台轮询可能暂停。';

  @override
  String get capabilityOverlayTitle => '悬浮窗权限';

  @override
  String get capabilityOverlaySubtitle => '显示在桌面和其他 App 上层，用于短句提醒和确认。';

  @override
  String get capabilityAccessibilityTitle => '无障碍服务';

  @override
  String get capabilityAccessibilitySubtitle => '读取当前 App、窗口标题和可见文字摘要；不上传截图。';

  @override
  String get capabilityScreenContextTitle => '屏幕上下文';

  @override
  String get capabilityScreenContextEnabled => '已开启：仅上传经过本机过滤的非敏感文本摘要。';

  @override
  String get capabilityScreenContextDisabled => '默认关闭；能力页仍可读取经过本机过滤的快照。';

  @override
  String get capabilityDeviceAdminTitle => '设备管理器锁屏';

  @override
  String get capabilityDeviceAdminSubtitle => '授权后才能执行 lockNow，每次仍由界面确认。';

  @override
  String get capabilityBackgroundServiceTitle => '后台通知服务';

  @override
  String get switchEnabledStatus => '开关已开';

  @override
  String get capabilityRelayTitle => '中继连接状态';

  @override
  String get capabilityGateTitle => '提醒冷却状态';

  @override
  String get testingStatus => '测试中';

  @override
  String get normalStatus => '正常';

  @override
  String get capabilityBackendTitle => 'adb reverse / 后端连通';

  @override
  String get detectingStatus => '检测中';

  @override
  String get connectedStatus => '已接入';

  @override
  String get detectAction => '检测';

  @override
  String get notConnectedStatus => '未接通';

  @override
  String get capabilityEditBackendTooltip => '修改后端节点';

  @override
  String get capabilityDetectBackendTooltip => '检测后端连通';

  @override
  String capabilityBackendLastError(String error) {
    return '最近连接错误：$error';
  }

  @override
  String get capabilityBackendNotice =>
      '能力页只显示手机端可验证的状态；adb reverse 本身在电脑侧执行，手机端通过 127.0.0.1 后端是否可达来判断。';

  @override
  String get relayConnected => '已连接';

  @override
  String get relayConnecting => '连接中';

  @override
  String get relayStopped => '已停止';

  @override
  String get relayError => '错误';

  @override
  String get relayUnconfigured => '未配置';

  @override
  String get syncStatusTitle => '同步状态';

  @override
  String get readingStatus => '读取中';

  @override
  String failedStatus(String error) {
    return '失败：$error';
  }

  @override
  String get pendingSyncStatus => '待同步';

  @override
  String get pollingStatus => '轮询中';

  @override
  String get activatedStatus => '已激活';

  @override
  String get pendingActivationStatus => '待激活';

  @override
  String syncChatStatus(String status) {
    return '聊天记录：$status';
  }

  @override
  String syncGardenStatus(String status) {
    return '花园状态：$status';
  }

  @override
  String syncMobileStatus(String status, String received) {
    return '主动消息：$status$received';
  }

  @override
  String syncReceivedSuffix(int count) {
    return ' · 已接收 $count 条';
  }

  @override
  String syncLatestMessage(String content) {
    return '最近一条：$content';
  }

  @override
  String get screenSnapshotEmpty => '暂无屏幕快照';

  @override
  String get screenDebugTitle => '屏幕上下文调试';

  @override
  String get readAction => '读取';

  @override
  String get pushAction => '推送';

  @override
  String screenWindow(String value) {
    return '窗口：$value';
  }

  @override
  String screenVisible(String value) {
    return '可见：$value';
  }

  @override
  String screenClickable(String value) {
    return '可点：$value';
  }

  @override
  String get behaviorTestTitle => '主动行为测试';

  @override
  String get behaviorTestDescription =>
      '写入后端 mobile queue，并立刻轮询一次；悬浮/确认类会在前台直接弹。';

  @override
  String get behaviorOverlayTestMessage => '（测试）我在屏幕边等你一下。';

  @override
  String get behaviorLockTestMessage => '（测试）要我替你锁屏吗？点确认才会执行。';

  @override
  String get behaviorTakeoutTestMessage => '（测试）要不要打开外卖页看一眼？不会自动下单。';

  @override
  String get behaviorNotificationTestMessage => '（测试）这是一条普通主动消息。';

  @override
  String get notificationLabel => '通知';

  @override
  String get overlayLabel => '悬浮';

  @override
  String get lockConfirmLabel => '锁屏确认';

  @override
  String get takeoutConfirmLabel => '外卖确认';

  @override
  String get backgroundDeliveryTitle => '后台交付测试';

  @override
  String get backgroundDeliveryDescription =>
      '不经过后端，直接测试手机端后台通知 / 存在感悬浮 / 工具确认分流。';

  @override
  String get normalNotificationLabel => '普通通知';

  @override
  String get presenceOverlayLabel => '存在感悬浮';

  @override
  String get lockRequestLabel => '锁屏请求';

  @override
  String get takeoutRequestLabel => '外卖请求';

  @override
  String get behaviorDecisionTitle => '行为裁决状态';

  @override
  String get behaviorDecisionEmpty => '还没读取。刷新后会显示后端最近一次行为裁决为什么弹或为什么没弹。';

  @override
  String readFailedMessage(String error) {
    return '读取失败：$error';
  }

  @override
  String get fieldTime => '时间';

  @override
  String get fieldReason => '原因';

  @override
  String get fieldEvent => '事件';

  @override
  String get fieldApp => '应用';

  @override
  String get fieldNarrative => '叙事';

  @override
  String get fieldScreen => '屏幕';

  @override
  String get fieldReply => '回复';

  @override
  String get backendDiagnosticsTitle => '后端 / 资产诊断';

  @override
  String get backendDiagnosticsEmpty => '点击“读取”拉取后端节点、数据目录、模型、角色卡、世界书、破限和梦境配置。';

  @override
  String get diagnosticBackendNode => '后端节点';

  @override
  String get diagnosticDataPath => '数据目录';

  @override
  String get diagnosticNoPermission => '无权限（mobile token 预期行为）';

  @override
  String get diagnosticMetaMode => '元模式';

  @override
  String get diagnosticDangerMode => '危险模式';

  @override
  String get diagnosticSafeMode => '安全模式';

  @override
  String get diagnosticModel => '模型';

  @override
  String get diagnosticShortTermRounds => '短期轮数';

  @override
  String get diagnosticCharacterCard => '角色卡';

  @override
  String get diagnosticLorebook => '世界书';

  @override
  String get diagnosticJailbreak => '破限';

  @override
  String diagnosticEntries(int count) {
    return '$count 条';
  }

  @override
  String get diagnosticDream => '梦境';

  @override
  String get diagnosticDreamLorebook => '梦境世界书';

  @override
  String get enabledShortStatus => '已启用';

  @override
  String get disabledShortStatus => '未启用';

  @override
  String get diagnosticDreamLayer => '梦境层';

  @override
  String get diagnosticDreamJailbreak => '梦境破限';

  @override
  String get diagnosticPhoneControlTool => '手机自动化 · 角色授权';

  @override
  String get diagnosticPhoneControlVision => '手机自动化 · 视觉模型';

  @override
  String get capabilityDeveloperDiagnosticsTitle => '开发者诊断';

  @override
  String get capabilityDeveloperDiagnosticsSubtitle =>
      '默认关闭；开启后才显示会发起测试行为的调试工具。';

  @override
  String get phoneControlTestTitle => '手机自动化测试';

  @override
  String get phoneControlTestDescription =>
      '跳过 LLM 判断和聊天内二次确认，直接发起一次手机自动化任务；仍然要先在后端开启危险模式，安全模式下会直接拒绝。';

  @override
  String get phoneControlTestHint => '任务描述，例如：帮我点杯奶茶';

  @override
  String get phoneControlTestButton => '发起测试任务';

  @override
  String get phoneControlTestEmptyTask => '先写清楚要测试的任务';

  @override
  String get capabilityLastPollNone => '最近周期补偿：暂无';

  @override
  String capabilityLastPoll(String time) {
    return '最近周期补偿：$time';
  }

  @override
  String get capabilityLastErrorNone => '最近错误原因：无';

  @override
  String capabilityLastError(String error) {
    return '最近错误原因：$error';
  }

  @override
  String get capabilityNativeRelayRunning => '原生中继服务正在运行';

  @override
  String get capabilityNativeRelayStopped =>
      '原生中继服务未运行；前台由 Flutter 每 5 秒读取主动消息';

  @override
  String get capabilityGateTestOn => '测试模式已开启：跳过 30 分钟冷却';

  @override
  String get capabilityGateTestOff => '普通提醒间隔 30 分钟，消息仍会正常接收';

  @override
  String get noneStatus => '无';

  @override
  String capabilityGateSummary(String mode, int count, String reason) {
    return '$mode。\n被吞计数：$count / 最近原因：$reason';
  }

  @override
  String capabilityOverlayLastError(String base, String time, String error) {
    return '$base\n权限已授予，但最近一次弹窗失败$time：$error';
  }

  @override
  String get capabilitySignalNone => '最近信号时间：暂无';

  @override
  String capabilitySignalTime(String time) {
    return '最近信号时间：$time';
  }

  @override
  String get capabilityHeartbeatNone => '最近中继心跳：暂无';

  @override
  String capabilityHeartbeatTime(String time) {
    return '最近中继心跳：$time';
  }

  @override
  String capabilityRelayLastError(String error) {
    return '\n最近中继错误：$error';
  }

  @override
  String get capabilityRelayConfigWarning =>
      '\n已连接不等于后端已配置；请检查后端 relay_base_url / relay_topic 与此处完全一致。';

  @override
  String capabilityLoopbackHint(String url) {
    return '$url · 真机调试依赖 adb reverse tcp:8080 tcp:8080';
  }

  @override
  String capabilityRemoteHint(String url) {
    return '$url · 局域网/VPN/内网穿透需可达';
  }

  @override
  String get notEnabledStatus => '未开启';

  @override
  String get sandboxSuffix => '  ⚠ 沙盒';

  @override
  String diagnosticReadError(String label, String message) {
    return '$label：读取失败 — $message';
  }

  @override
  String get backgroundTestPresenceMessage => '我在这里。你不想说话也没关系。';

  @override
  String get backgroundTestLockMessage => '已经很晚了。要我替你锁一下屏吗？';

  @override
  String get backgroundTestTakeoutMessage => '你还没吃东西。要不要我帮你打开外卖页看一眼？';

  @override
  String get backgroundTestDefaultMessage => '我刚才给你发了一句话，回来再看也可以。';

  @override
  String get checkingStatus => '检测中';

  @override
  String get notRunStatus => '未运行';

  @override
  String chatTodayLine(String date, String time) {
    return '今日 · $date · $time';
  }

  @override
  String get moodNeutral => '平静';

  @override
  String get moodGentle => '温柔';

  @override
  String get moodThinking => '在想事情';

  @override
  String get moodHappy => '开心';

  @override
  String get moodSad => '有点难过';

  @override
  String get moodSurprised => '有点惊讶';

  @override
  String get moodAngry => '有点生气';

  @override
  String get moodSleepy => '困困的';

  @override
  String get moodYandere => '情绪很浓';

  @override
  String oemBackgroundGuide(String appName) {
    return '厂商后台白名单参考：\n小米：设置 → 应用设置 → 应用管理 → $appName → 省电策略/自启动 → 无限制并开启自启动\nOPPO：设置 → 应用 → 自启动/耗电管理 → $appName → 允许后台运行\nvivo：设置 → 电池 → 后台耗电管理 → $appName → 允许后台高耗电\n华为：设置 → 应用和服务 → 应用启动管理 → $appName → 手动管理并允许后台活动';
  }

  @override
  String get settingsChatSection => '聊天与表情';

  @override
  String get settingsStickerTitle => '接收表情包';

  @override
  String get settingsStickerSubtitle => '关闭时不接收表情包消息';

  @override
  String get settingsAutoPlayVoiceTitle => '自动播放语音';

  @override
  String get settingsAutoPlayVoiceSubtitle => '需在后端已启用语音功能时开启';

  @override
  String get chatPullRefresh => '下拉刷新最新历史';

  @override
  String get chatReleaseRefresh => '松手刷新';

  @override
  String get chatRefreshing => '正在刷新连接…';

  @override
  String get chatRefreshComplete => '历史记录已刷新';

  @override
  String get chatRefreshUnavailable => '暂时无法连接，请检查后端节点和访问 Token。';

  @override
  String get imageDecodeFailed => '无法显示此图片，请尝试 PNG 或 JPEG 格式。';

  @override
  String get imageCaptionTitle => '图片说明';

  @override
  String get imageCaptionHint => '可选：和图片一起发送的文字';

  @override
  String get dreamNarrationSize => '梦境旁白字号';

  @override
  String get dreamChatSize => '梦境聊天字号';

  @override
  String get dreamActionSize => '梦境动作字号';

  @override
  String get showReasoning => '显示思考入口';

  @override
  String get expandReasoning => '默认展开思考';

  @override
  String get reasoningLocal => '仅影响本机显示';

  @override
  String get reasoningOpen => '展开思考';

  @override
  String get reasoningClose => '关闭思考';

  @override
  String get reasoningUnavailable => '思考暂未就绪，可重试';

  @override
  String reasoningHeading(String name) {
    return '$name的内心活动：';
  }

  @override
  String get userDisplayName => '用户昵称';

  @override
  String get userSignature => '点击编辑签名';

  @override
  String get themeFontSize => '界面字号';

  @override
  String get systemFont => '系统字体';

  @override
  String get importFont => '导入字体（TTF / OTF / TTC）';

  @override
  String get fontImportFailed => '字体导入失败：最多 10 个字体，每个不超过 20 MB，请选择有效字体文件';

  @override
  String get themeImportJson => '导入主题 JSON';

  @override
  String get themeImportFailed => '主题导入失败：请选择完整的手机主题 JSON（256 KB 以内）';

  @override
  String get reasoningOpacity => '思考底面不透明度';

  @override
  String get dayAppearanceTheme => '日间外观主题';

  @override
  String get nightAppearanceTheme => '夜间外观主题';

  @override
  String get dreamUi => '梦境 UI';

  @override
  String get dreamNarrationColorLabel => '旁白颜色';

  @override
  String get dreamChatColorLabel => '聊天颜色';

  @override
  String get dreamActionColorLabel => '动作颜色';

  @override
  String get dreamPreviewNarration => '月光轻轻落在窗边。';

  @override
  String get dreamPreviewChat => '今晚，想去哪里看看？';

  @override
  String get dreamPreviewAction => '轻轻握住你的手。';
}
