import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'陪伴'**
  String get appTitle;

  /// No description provided for @appErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'页面出了点问题'**
  String get appErrorTitle;

  /// No description provided for @backHome.
  ///
  /// In zh, this message translates to:
  /// **'回到主界面'**
  String get backHome;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsGeneralSection.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get settingsGeneralSection;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'切换后立即生效，并保存到本机'**
  String get settingsLanguageSubtitle;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageSimplifiedChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageSimplifiedChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsConnectionAccountSection.
  ///
  /// In zh, this message translates to:
  /// **'连接与账户'**
  String get settingsConnectionAccountSection;

  /// No description provided for @settingsAccessTokenTitle.
  ///
  /// In zh, this message translates to:
  /// **'访问 Token'**
  String get settingsAccessTokenTitle;

  /// No description provided for @settingsAccessTokenConfigured.
  ///
  /// In zh, this message translates to:
  /// **'已设置 · 保存在本机 Android 私有存储'**
  String get settingsAccessTokenConfigured;

  /// No description provided for @settingsAccessTokenMissing.
  ///
  /// In zh, this message translates to:
  /// **'尚未设置 · 连接后端前必须填写'**
  String get settingsAccessTokenMissing;

  /// No description provided for @settingsReplaceAction.
  ///
  /// In zh, this message translates to:
  /// **'更换'**
  String get settingsReplaceAction;

  /// No description provided for @settingsSetAction.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsSetAction;

  /// No description provided for @drawerClientSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'手机薄客户端 · 本机显示'**
  String get drawerClientSubtitle;

  /// No description provided for @drawerPagesSection.
  ///
  /// In zh, this message translates to:
  /// **'页面'**
  String get drawerPagesSection;

  /// No description provided for @drawerChatTitle.
  ///
  /// In zh, this message translates to:
  /// **'主对话'**
  String get drawerChatTitle;

  /// No description provided for @drawerChatSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'聊天窗口'**
  String get drawerChatSubtitle;

  /// No description provided for @drawerDreamTitle.
  ///
  /// In zh, this message translates to:
  /// **'梦境'**
  String get drawerDreamTitle;

  /// No description provided for @drawerDreamSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'独立的 Dream 对话'**
  String get drawerDreamSubtitle;

  /// No description provided for @drawerProfileTitle.
  ///
  /// In zh, this message translates to:
  /// **'角色资料'**
  String get drawerProfileTitle;

  /// No description provided for @drawerProfileSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'本机备注和头像'**
  String get drawerProfileSubtitle;

  /// No description provided for @drawerDiaryTitle.
  ///
  /// In zh, this message translates to:
  /// **'{name}的日记'**
  String drawerDiaryTitle(String name);

  /// No description provided for @drawerDiarySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'他写给自己的'**
  String get drawerDiarySubtitle;

  /// No description provided for @drawerActivityTitle.
  ///
  /// In zh, this message translates to:
  /// **'活动'**
  String get drawerActivityTitle;

  /// No description provided for @drawerActivitySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'看书 / 五子棋 / 国际象棋 / 梦境预构'**
  String get drawerActivitySubtitle;

  /// No description provided for @drawerGroupTitle.
  ///
  /// In zh, this message translates to:
  /// **'群聊'**
  String get drawerGroupTitle;

  /// No description provided for @drawerGroupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'多角色一起聊'**
  String get drawerGroupSubtitle;

  /// No description provided for @drawerGrowthSection.
  ///
  /// In zh, this message translates to:
  /// **'养成'**
  String get drawerGrowthSection;

  /// No description provided for @drawerGardenTitle.
  ///
  /// In zh, this message translates to:
  /// **'状态花园'**
  String get drawerGardenTitle;

  /// No description provided for @drawerGardenSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'他今天的心境'**
  String get drawerGardenSubtitle;

  /// No description provided for @drawerSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get drawerSettingsTitle;

  /// No description provided for @drawerSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'连接、通知、外观与对话配置'**
  String get drawerSettingsSubtitle;

  /// No description provided for @drawerCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get drawerCurrent;

  /// No description provided for @presenceOnline.
  ///
  /// In zh, this message translates to:
  /// **'在场'**
  String get presenceOnline;

  /// No description provided for @presenceMobileOnline.
  ///
  /// In zh, this message translates to:
  /// **'手机端在线'**
  String get presenceMobileOnline;

  /// No description provided for @presenceReady.
  ///
  /// In zh, this message translates to:
  /// **'就绪'**
  String get presenceReady;

  /// No description provided for @presenceChatting.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get presenceChatting;

  /// No description provided for @presenceNow.
  ///
  /// In zh, this message translates to:
  /// **'现在'**
  String get presenceNow;

  /// No description provided for @backTooltip.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get backTooltip;

  /// No description provided for @chatLoadingOlder.
  ///
  /// In zh, this message translates to:
  /// **'正在加载更早的对话…'**
  String get chatLoadingOlder;

  /// No description provided for @chatHiddenOlder.
  ///
  /// In zh, this message translates to:
  /// **'已折叠 {count} 条更早对话 · 上滑继续展开'**
  String chatHiddenOlder(int count);

  /// No description provided for @chatLoadingHistory.
  ///
  /// In zh, this message translates to:
  /// **'正在从后端读取聊天记录'**
  String get chatLoadingHistory;

  /// No description provided for @chatEmptyHistory.
  ///
  /// In zh, this message translates to:
  /// **'后端已连接 · 暂无聊天记录'**
  String get chatEmptyHistory;

  /// No description provided for @chatHistoryError.
  ///
  /// In zh, this message translates to:
  /// **'历史加载失败 · {error}'**
  String chatHistoryError(String error);

  /// No description provided for @chatWaitingReply.
  ///
  /// In zh, this message translates to:
  /// **'已送到后端 · 正在等他回话'**
  String get chatWaitingReply;

  /// No description provided for @chatBackendError.
  ///
  /// In zh, this message translates to:
  /// **'后端连接异常 · {error}'**
  String chatBackendError(String error);

  /// No description provided for @chatBackendStatus.
  ///
  /// In zh, this message translates to:
  /// **'后端已接入 · {emotion} · 好感 {affection}'**
  String chatBackendStatus(String emotion, int affection);

  /// No description provided for @chatMobileReceived.
  ///
  /// In zh, this message translates to:
  /// **'已接收 {count} 条主动消息'**
  String chatMobileReceived(int count);

  /// No description provided for @chatTyping.
  ///
  /// In zh, this message translates to:
  /// **'正在输入'**
  String get chatTyping;

  /// No description provided for @drawerTooltip.
  ///
  /// In zh, this message translates to:
  /// **'抽屉'**
  String get drawerTooltip;

  /// No description provided for @preferencesTooltip.
  ///
  /// In zh, this message translates to:
  /// **'偏好'**
  String get preferencesTooltip;

  /// No description provided for @switchToLightTooltip.
  ///
  /// In zh, this message translates to:
  /// **'切到白天'**
  String get switchToLightTooltip;

  /// No description provided for @switchToDarkTooltip.
  ///
  /// In zh, this message translates to:
  /// **'切到夜里'**
  String get switchToDarkTooltip;

  /// No description provided for @copyAction.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copyAction;

  /// No description provided for @selectAllAction.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAllAction;

  /// No description provided for @replyAction.
  ///
  /// In zh, this message translates to:
  /// **'回复'**
  String get replyAction;

  /// No description provided for @cancelReplyTooltip.
  ///
  /// In zh, this message translates to:
  /// **'取消回复'**
  String get cancelReplyTooltip;

  /// No description provided for @imageAttachment.
  ///
  /// In zh, this message translates to:
  /// **'图片附件'**
  String get imageAttachment;

  /// No description provided for @stickerLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'表情包加载失败'**
  String get stickerLoadFailed;

  /// No description provided for @fileAttachment.
  ///
  /// In zh, this message translates to:
  /// **'文件附件'**
  String get fileAttachment;

  /// No description provided for @composerPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'对他说些什么…'**
  String get composerPlaceholder;

  /// No description provided for @attachmentTooltip.
  ///
  /// In zh, this message translates to:
  /// **'附件'**
  String get attachmentTooltip;

  /// No description provided for @releaseToSendTooltip.
  ///
  /// In zh, this message translates to:
  /// **'松开发送'**
  String get releaseToSendTooltip;

  /// No description provided for @holdToTalkTooltip.
  ///
  /// In zh, this message translates to:
  /// **'长按说话'**
  String get holdToTalkTooltip;

  /// No description provided for @waitAction.
  ///
  /// In zh, this message translates to:
  /// **'等待'**
  String get waitAction;

  /// No description provided for @sendAction.
  ///
  /// In zh, this message translates to:
  /// **'寄出'**
  String get sendAction;

  /// No description provided for @characterCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 字'**
  String characterCount(int count);

  /// No description provided for @settingsBackendNodeTitle.
  ///
  /// In zh, this message translates to:
  /// **'后端节点与用户 ID'**
  String get settingsBackendNodeTitle;

  /// No description provided for @settingsBackendNodeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{baseUrl} · 用户 {userId}'**
  String settingsBackendNodeSubtitle(String baseUrl, String userId);

  /// No description provided for @settingsEditBackendTooltip.
  ///
  /// In zh, this message translates to:
  /// **'修改后端地址'**
  String get settingsEditBackendTooltip;

  /// No description provided for @settingsRelayTitle.
  ///
  /// In zh, this message translates to:
  /// **'推送中继 ntfy'**
  String get settingsRelayTitle;

  /// No description provided for @settingsRelaySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'中继只承载新消息信号，正文会从已鉴权后端回源读取。'**
  String get settingsRelaySubtitle;

  /// No description provided for @settingsEditRelayTooltip.
  ///
  /// In zh, this message translates to:
  /// **'修改中继地址'**
  String get settingsEditRelayTooltip;

  /// No description provided for @settingsNotificationsSection.
  ///
  /// In zh, this message translates to:
  /// **'通知与主动性'**
  String get settingsNotificationsSection;

  /// No description provided for @settingsBackgroundNotificationsTitle.
  ///
  /// In zh, this message translates to:
  /// **'后台通知'**
  String get settingsBackgroundNotificationsTitle;

  /// No description provided for @settingsBackgroundNotificationsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'中继实时订阅 · 长时间断线周期补偿 · 静音/冷却'**
  String get settingsBackgroundNotificationsSubtitle;

  /// No description provided for @settingsNotificationTestTitle.
  ///
  /// In zh, this message translates to:
  /// **'通知闸门测试模式（仅调试）'**
  String get settingsNotificationTestTitle;

  /// No description provided for @settingsNotificationTestSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'仅绕过静音时段和 30 分钟冷却，不改变消息消费逻辑。'**
  String get settingsNotificationTestSubtitle;

  /// No description provided for @settingsAppearanceSection.
  ///
  /// In zh, this message translates to:
  /// **'外观与显示'**
  String get settingsAppearanceSection;

  /// No description provided for @settingsProfileTitle.
  ///
  /// In zh, this message translates to:
  /// **'角色资料'**
  String get settingsProfileTitle;

  /// No description provided for @settingsProfileSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'本机备注和头像 · 资料页有完整说明'**
  String get settingsProfileSubtitle;

  /// No description provided for @settingsOpenProfileTooltip.
  ///
  /// In zh, this message translates to:
  /// **'打开角色资料页'**
  String get settingsOpenProfileTooltip;

  /// No description provided for @settingsEditProfileNameTooltip.
  ///
  /// In zh, this message translates to:
  /// **'设置本机备注名'**
  String get settingsEditProfileNameTooltip;

  /// No description provided for @settingsImportAvatarTooltip.
  ///
  /// In zh, this message translates to:
  /// **'导入并裁切头像'**
  String get settingsImportAvatarTooltip;

  /// No description provided for @settingsResetAvatarTooltip.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认头像'**
  String get settingsResetAvatarTooltip;

  /// No description provided for @settingsThemeTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观主题'**
  String get settingsThemeTitle;

  /// No description provided for @settingsThemeBuiltInSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'信纸 · 夜间 · {count} 个颜色预设'**
  String settingsThemeBuiltInSubtitle(int count);

  /// No description provided for @settingsThemePresetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前：{name} · 共 {count} 个预设'**
  String settingsThemePresetSubtitle(String name, int count);

  /// No description provided for @themePaper.
  ///
  /// In zh, this message translates to:
  /// **'信纸'**
  String get themePaper;

  /// No description provided for @themeNight.
  ///
  /// In zh, this message translates to:
  /// **'夜间'**
  String get themeNight;

  /// No description provided for @settingsColorPresets.
  ///
  /// In zh, this message translates to:
  /// **'颜色预设 ({count})'**
  String settingsColorPresets(int count);

  /// No description provided for @settingsInfoStripTitle.
  ///
  /// In zh, this message translates to:
  /// **'对话信息栏'**
  String get settingsInfoStripTitle;

  /// No description provided for @settingsInfoStripSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'控制主页整块深绿色状态区'**
  String get settingsInfoStripSubtitle;

  /// No description provided for @settingsFontSizeTitle.
  ///
  /// In zh, this message translates to:
  /// **'正文字号'**
  String get settingsFontSizeTitle;

  /// No description provided for @settingsFontSizeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{size}px · 影响气泡和正文段落'**
  String settingsFontSizeSubtitle(int size);

  /// No description provided for @settingsShowAvatarTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示我的头像'**
  String get settingsShowAvatarTitle;

  /// No description provided for @settingsShowAvatarSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'对话气泡右侧也放小头像'**
  String get settingsShowAvatarSubtitle;

  /// No description provided for @settingsProactiveRateTitle.
  ///
  /// In zh, this message translates to:
  /// **'主动消息频率'**
  String get settingsProactiveRateTitle;

  /// No description provided for @settingsProactiveRateSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'控制后台主动提醒的大致密度'**
  String get settingsProactiveRateSubtitle;

  /// No description provided for @rateLow.
  ///
  /// In zh, this message translates to:
  /// **'少'**
  String get rateLow;

  /// No description provided for @rateMedium.
  ///
  /// In zh, this message translates to:
  /// **'适中'**
  String get rateMedium;

  /// No description provided for @rateHigh.
  ///
  /// In zh, this message translates to:
  /// **'多'**
  String get rateHigh;

  /// No description provided for @settingsNightSilentTitle.
  ///
  /// In zh, this message translates to:
  /// **'夜深时段静音'**
  String get settingsNightSilentTitle;

  /// No description provided for @settingsNightSilentSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'他在 23:30 到 06:30 不主动找你'**
  String get settingsNightSilentSubtitle;

  /// No description provided for @settingsChatContentSection.
  ///
  /// In zh, this message translates to:
  /// **'对话内容配置'**
  String get settingsChatContentSection;

  /// No description provided for @settingsChatLorebookTitle.
  ///
  /// In zh, this message translates to:
  /// **'Chat 世界书'**
  String get settingsChatLorebookTitle;

  /// No description provided for @settingsChatLorebookSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'Reality 对话使用 · 多选'**
  String get settingsChatLorebookSubtitle;

  /// No description provided for @settingsChatJailbreakTitle.
  ///
  /// In zh, this message translates to:
  /// **'Chat 破限'**
  String get settingsChatJailbreakTitle;

  /// No description provided for @settingsChatJailbreakSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'Reality 独立破限 · 多选'**
  String get settingsChatJailbreakSubtitle;

  /// No description provided for @settingsDreamLorebookTitle.
  ///
  /// In zh, this message translates to:
  /// **'Dream 世界书'**
  String get settingsDreamLorebookTitle;

  /// No description provided for @settingsDreamLorebookSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'Dream 独立 Lorebook 开关'**
  String get settingsDreamLorebookSubtitle;

  /// No description provided for @settingsDreamWorldTitle.
  ///
  /// In zh, this message translates to:
  /// **'Dream 世界层'**
  String get settingsDreamWorldTitle;

  /// No description provided for @settingsDreamWorldSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'下一次入梦时使用'**
  String get settingsDreamWorldSubtitle;

  /// No description provided for @dreamWorldRealityDerived.
  ///
  /// In zh, this message translates to:
  /// **'现实派生'**
  String get dreamWorldRealityDerived;

  /// No description provided for @dreamWorldAbo.
  ///
  /// In zh, this message translates to:
  /// **'ABO'**
  String get dreamWorldAbo;

  /// No description provided for @dreamWorldVampire.
  ///
  /// In zh, this message translates to:
  /// **'吸血鬼'**
  String get dreamWorldVampire;

  /// No description provided for @dreamWorldCat.
  ///
  /// In zh, this message translates to:
  /// **'猫'**
  String get dreamWorldCat;

  /// No description provided for @dreamWorldFlowerBud.
  ///
  /// In zh, this message translates to:
  /// **'花苞'**
  String get dreamWorldFlowerBud;

  /// No description provided for @customOption.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get customOption;

  /// No description provided for @settingsDreamJailbreakTitle.
  ///
  /// In zh, this message translates to:
  /// **'Dream 破限'**
  String get settingsDreamJailbreakTitle;

  /// No description provided for @settingsDreamJailbreakSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'Dream 独立 D0 预设'**
  String get settingsDreamJailbreakSubtitle;

  /// No description provided for @defaultOption.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get defaultOption;

  /// No description provided for @settingsBackendSaveError.
  ///
  /// In zh, this message translates to:
  /// **'后端设置读取/保存失败：{error}'**
  String settingsBackendSaveError(String error);

  /// No description provided for @settingsDiagnosticsSection.
  ///
  /// In zh, this message translates to:
  /// **'诊断'**
  String get settingsDiagnosticsSection;

  /// No description provided for @settingsCapabilitiesTitle.
  ///
  /// In zh, this message translates to:
  /// **'能力检查'**
  String get settingsCapabilitiesTitle;

  /// No description provided for @settingsCapabilitiesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'权限状态、后端连通、中继与同步状态'**
  String get settingsCapabilitiesSubtitle;

  /// No description provided for @openAction.
  ///
  /// In zh, this message translates to:
  /// **'打开'**
  String get openAction;

  /// No description provided for @settingsThinClientNotice.
  ///
  /// In zh, this message translates to:
  /// **'手机端负责聊天、通知、悬浮窗和本机显示；人格、记忆与调度仍由后端维护。'**
  String get settingsThinClientNotice;

  /// No description provided for @localDeviceLabel.
  ///
  /// In zh, this message translates to:
  /// **'本机'**
  String get localDeviceLabel;

  /// No description provided for @refreshAction.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refreshAction;

  /// No description provided for @loadingAction.
  ///
  /// In zh, this message translates to:
  /// **'正在读取…'**
  String get loadingAction;

  /// No description provided for @profileTitle.
  ///
  /// In zh, this message translates to:
  /// **'角色资料'**
  String get profileTitle;

  /// No description provided for @profileEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'{name} · 本机显示'**
  String profileEyebrow(String name);

  /// No description provided for @profileAvatarConfigured.
  ///
  /// In zh, this message translates to:
  /// **'本机头像已设置'**
  String get profileAvatarConfigured;

  /// No description provided for @profileAvatarDefault.
  ///
  /// In zh, this message translates to:
  /// **'使用默认字母头像'**
  String get profileAvatarDefault;

  /// No description provided for @profileNameAction.
  ///
  /// In zh, this message translates to:
  /// **'备注名'**
  String get profileNameAction;

  /// No description provided for @profileAvatarAction.
  ///
  /// In zh, this message translates to:
  /// **'头像'**
  String get profileAvatarAction;

  /// No description provided for @profileDefaultAction.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get profileDefaultAction;

  /// No description provided for @profileNowSection.
  ///
  /// In zh, this message translates to:
  /// **'此刻'**
  String get profileNowSection;

  /// No description provided for @profileNoActivity.
  ///
  /// In zh, this message translates to:
  /// **'暂时没有特别的动向'**
  String get profileNoActivity;

  /// No description provided for @profileMoodStatus.
  ///
  /// In zh, this message translates to:
  /// **'心情：{label}（{percent}%）'**
  String profileMoodStatus(String label, int percent);

  /// No description provided for @profileLocalNameTitle.
  ///
  /// In zh, this message translates to:
  /// **'本机备注名'**
  String get profileLocalNameTitle;

  /// No description provided for @profileDefaultCharacterName.
  ///
  /// In zh, this message translates to:
  /// **'默认角色名'**
  String get profileDefaultCharacterName;

  /// No description provided for @profileLocalNameBody.
  ///
  /// In zh, this message translates to:
  /// **'只影响这台手机里的显示：顶部栏、抽屉、偏好页和 HIM 聊天气泡。不会写回后端，也不会改核心人格配置。'**
  String get profileLocalNameBody;

  /// No description provided for @profileAvatarScopeTitle.
  ///
  /// In zh, this message translates to:
  /// **'头像作用域'**
  String get profileAvatarScopeTitle;

  /// No description provided for @profileDefaultAvatar.
  ///
  /// In zh, this message translates to:
  /// **'默认头像'**
  String get profileDefaultAvatar;

  /// No description provided for @profileAvatarScopeBody.
  ///
  /// In zh, this message translates to:
  /// **'头像保存在 App 私有目录，只作为手机端本地头像源。当前不会上传到后端，也不会同步到桌宠或其他客户端。'**
  String get profileAvatarScopeBody;

  /// No description provided for @profileRealityCardTitle.
  ///
  /// In zh, this message translates to:
  /// **'Reality 角色卡'**
  String get profileRealityCardTitle;

  /// No description provided for @profileRealityCardBody.
  ///
  /// In zh, this message translates to:
  /// **'切换后会影响主对话使用的人格卡；由后端保存并同步到其他客户端。'**
  String get profileRealityCardBody;

  /// No description provided for @profileCurrentCardLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前角色卡'**
  String get profileCurrentCardLabel;

  /// No description provided for @profileLoadCards.
  ///
  /// In zh, this message translates to:
  /// **'读取角色卡'**
  String get profileLoadCards;

  /// No description provided for @profileSyncBoundaryTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步边界'**
  String get profileSyncBoundaryTitle;

  /// No description provided for @profileSyncBoundaryValue.
  ///
  /// In zh, this message translates to:
  /// **'手机端覆盖显示'**
  String get profileSyncBoundaryValue;

  /// No description provided for @profileSyncBoundaryBody.
  ///
  /// In zh, this message translates to:
  /// **'后续如果要同步备注名到后端，建议单独做确认按钮；现在资料页保持轻客户端边界，避免误改核心配置。'**
  String get profileSyncBoundaryBody;

  /// No description provided for @profileDisplayLocationTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示位置'**
  String get profileDisplayLocationTitle;

  /// No description provided for @profileDisplayLocationValue.
  ///
  /// In zh, this message translates to:
  /// **'UI 已跟随'**
  String get profileDisplayLocationValue;

  /// No description provided for @profileDisplayLocationBody.
  ///
  /// In zh, this message translates to:
  /// **'顶部栏、抽屉、偏好页和{name}消息头像都会读取这份本机资料。用户自己的头像设置仍独立处理。'**
  String profileDisplayLocationBody(String name);

  /// No description provided for @profileFooterNotice.
  ///
  /// In zh, this message translates to:
  /// **'这页只管理手机薄客户端的外观身份。{name}的核心人格、记忆和调度仍然以后端为准。'**
  String profileFooterNotice(String name);

  /// No description provided for @activityTitle.
  ///
  /// In zh, this message translates to:
  /// **'活动'**
  String get activityTitle;

  /// No description provided for @activityEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'和他一起做点什么'**
  String get activityEyebrow;

  /// No description provided for @activityReadingTitle.
  ///
  /// In zh, this message translates to:
  /// **'一起看书'**
  String get activityReadingTitle;

  /// No description provided for @activityReadingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'上传 PDF，翻页时聊两句'**
  String get activityReadingSubtitle;

  /// No description provided for @activityGomokuTitle.
  ///
  /// In zh, this message translates to:
  /// **'五子棋'**
  String get activityGomokuTitle;

  /// No description provided for @activityGomokuSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'对战角色 AI，触屏落子'**
  String get activityGomokuSubtitle;

  /// No description provided for @activityChessTitle.
  ///
  /// In zh, this message translates to:
  /// **'国际象棋'**
  String get activityChessTitle;

  /// No description provided for @activityChessSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'对战角色 AI'**
  String get activityChessSubtitle;

  /// No description provided for @activityDreamBuildTitle.
  ///
  /// In zh, this message translates to:
  /// **'梦境预构'**
  String get activityDreamBuildTitle;

  /// No description provided for @activityDreamBuildSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'出发前先聊聊今晚想做什么梦'**
  String get activityDreamBuildSubtitle;

  /// No description provided for @activityChatPrompt.
  ///
  /// In zh, this message translates to:
  /// **'说点什么，聊聊现在的进展'**
  String get activityChatPrompt;

  /// No description provided for @saySomethingHint.
  ///
  /// In zh, this message translates to:
  /// **'说点什么…'**
  String get saySomethingHint;

  /// No description provided for @sendFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'（发送失败：{error}）'**
  String sendFailedMessage(String error);

  /// No description provided for @endAction.
  ///
  /// In zh, this message translates to:
  /// **'结束'**
  String get endAction;

  /// No description provided for @dreamBuildIntro.
  ///
  /// In zh, this message translates to:
  /// **'还没开始预构梦境。开始后可以先跟他聊聊今晚想梦到什么，结束时会把这段对话浓缩成一个种子，供入梦时参考。'**
  String get dreamBuildIntro;

  /// No description provided for @dreamBuildStart.
  ///
  /// In zh, this message translates to:
  /// **'开始预构'**
  String get dreamBuildStart;

  /// No description provided for @dreamBuildChatTitle.
  ///
  /// In zh, this message translates to:
  /// **'预构对话'**
  String get dreamBuildChatTitle;

  /// No description provided for @openChatAction.
  ///
  /// In zh, this message translates to:
  /// **'打开对话'**
  String get openChatAction;

  /// No description provided for @diaryAllFilter.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get diaryAllFilter;

  /// No description provided for @diaryTitle.
  ///
  /// In zh, this message translates to:
  /// **'日记'**
  String get diaryTitle;

  /// No description provided for @diaryEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'{name} · 私写'**
  String diaryEyebrow(String name);

  /// No description provided for @syncingStatus.
  ///
  /// In zh, this message translates to:
  /// **'同步中'**
  String get syncingStatus;

  /// No description provided for @syncedStatus.
  ///
  /// In zh, this message translates to:
  /// **'已同步'**
  String get syncedStatus;

  /// No description provided for @diarySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索 · 关键词 / 日期 / 心情'**
  String get diarySearchHint;

  /// No description provided for @retryAction.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retryAction;

  /// No description provided for @diaryLoadingList.
  ///
  /// In zh, this message translates to:
  /// **'正在从后端读取日记列表…'**
  String get diaryLoadingList;

  /// No description provided for @diaryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'他还没开始写日记。'**
  String get diaryEmpty;

  /// No description provided for @diaryNoResults.
  ///
  /// In zh, this message translates to:
  /// **'找不到对应的日记。'**
  String get diaryNoResults;

  /// No description provided for @diaryRecentRefreshError.
  ///
  /// In zh, this message translates to:
  /// **'最近刷新失败：{error}'**
  String diaryRecentRefreshError(String error);

  /// No description provided for @diaryOpenToLoad.
  ///
  /// In zh, this message translates to:
  /// **'点开条目后再读取正文。'**
  String get diaryOpenToLoad;

  /// No description provided for @diaryTapToLoad.
  ///
  /// In zh, this message translates to:
  /// **'点击读取正文'**
  String get diaryTapToLoad;

  /// No description provided for @loadingStatus.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get loadingStatus;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'无数据'**
  String get noData;

  /// No description provided for @loadFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{error}'**
  String loadFailedMessage(String error);

  /// No description provided for @gardenTitle.
  ///
  /// In zh, this message translates to:
  /// **'陪伴花园'**
  String get gardenTitle;

  /// No description provided for @gardenEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'{name} · 状态花园'**
  String gardenEyebrow(String name);

  /// No description provided for @gardenShortTitle.
  ///
  /// In zh, this message translates to:
  /// **'花园'**
  String get gardenShortTitle;

  /// No description provided for @gardenLoadingDescription.
  ///
  /// In zh, this message translates to:
  /// **'正在读取后端花园状态。'**
  String get gardenLoadingDescription;

  /// No description provided for @gardenErrorDescription.
  ///
  /// In zh, this message translates to:
  /// **'花园同步失败，稍后可以重新刷新。'**
  String get gardenErrorDescription;

  /// No description provided for @gardenLoadedDescription.
  ///
  /// In zh, this message translates to:
  /// **'已读取后端花园状态。它在你不看的时候，也在生长。'**
  String get gardenLoadedDescription;

  /// No description provided for @gardenNotLoadedDescription.
  ///
  /// In zh, this message translates to:
  /// **'还没有读取到后端花园状态。'**
  String get gardenNotLoadedDescription;

  /// No description provided for @gardenDominantMood.
  ///
  /// In zh, this message translates to:
  /// **'他现在 · 主导心境'**
  String get gardenDominantMood;

  /// No description provided for @waitingStatus.
  ///
  /// In zh, this message translates to:
  /// **'等待'**
  String get waitingStatus;

  /// No description provided for @gardenWaitingData.
  ///
  /// In zh, this message translates to:
  /// **'等待后端花园数据'**
  String get gardenWaitingData;

  /// No description provided for @gardenSyncing.
  ///
  /// In zh, this message translates to:
  /// **'正在同步花园'**
  String get gardenSyncing;

  /// No description provided for @syncFailedStatus.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get syncFailedStatus;

  /// No description provided for @gardenAutoRefresh.
  ///
  /// In zh, this message translates to:
  /// **'后端 · 每 30 秒自动刷新'**
  String get gardenAutoRefresh;

  /// No description provided for @notSyncedStatus.
  ///
  /// In zh, this message translates to:
  /// **'尚未同步'**
  String get notSyncedStatus;

  /// No description provided for @gardenRefreshTooltip.
  ///
  /// In zh, this message translates to:
  /// **'刷新花园'**
  String get gardenRefreshTooltip;

  /// No description provided for @gardenSyncingMessage.
  ///
  /// In zh, this message translates to:
  /// **'正在同步花园…'**
  String get gardenSyncingMessage;

  /// No description provided for @gardenEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无花园数据'**
  String get gardenEmpty;

  /// No description provided for @gardenWaitingSlot.
  ///
  /// In zh, this message translates to:
  /// **'等待后端返回花园槽位。'**
  String get gardenWaitingSlot;

  /// No description provided for @gardenStageSummary.
  ///
  /// In zh, this message translates to:
  /// **'{mood} 槽位最接近下一阶段 · {percent}% · 收获 {harvest} · 花瓶 {vase}'**
  String gardenStageSummary(
    String mood,
    int percent,
    String harvest,
    String vase,
  );

  /// No description provided for @dreamHeaderTitle.
  ///
  /// In zh, this message translates to:
  /// **'梦 · {name}'**
  String dreamHeaderTitle(String name);

  /// No description provided for @dreamInProgress.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get dreamInProgress;

  /// No description provided for @dreamReady.
  ///
  /// In zh, this message translates to:
  /// **'DREAM · READY'**
  String get dreamReady;

  /// No description provided for @dreamWakeAction.
  ///
  /// In zh, this message translates to:
  /// **'醒来'**
  String get dreamWakeAction;

  /// No description provided for @dreamConnectionError.
  ///
  /// In zh, this message translates to:
  /// **'梦境连接异常 · {error}'**
  String dreamConnectionError(String error);

  /// No description provided for @dreamResponding.
  ///
  /// In zh, this message translates to:
  /// **'梦在回应'**
  String get dreamResponding;

  /// No description provided for @dreamStability.
  ///
  /// In zh, this message translates to:
  /// **'稳定度'**
  String get dreamStability;

  /// No description provided for @dreamDepth.
  ///
  /// In zh, this message translates to:
  /// **'深度'**
  String get dreamDepth;

  /// No description provided for @dreamFindingEntrance.
  ///
  /// In zh, this message translates to:
  /// **'正在寻找梦境入口'**
  String get dreamFindingEntrance;

  /// No description provided for @dreamEntranceOpen.
  ///
  /// In zh, this message translates to:
  /// **'梦境入口已经打开'**
  String get dreamEntranceOpen;

  /// No description provided for @dreamEntranceDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入后，对话会暂时停在更轻、更慢的地方。这里与主对话消息流彼此独立。'**
  String get dreamEntranceDescription;

  /// No description provided for @dreamValidCount.
  ///
  /// In zh, this message translates to:
  /// **'已经做过 {count} 次有效的梦'**
  String dreamValidCount(int count);

  /// No description provided for @dreamEntering.
  ///
  /// In zh, this message translates to:
  /// **'坠入中…'**
  String get dreamEntering;

  /// No description provided for @dreamEnterAction.
  ///
  /// In zh, this message translates to:
  /// **'进入梦境'**
  String get dreamEnterAction;

  /// No description provided for @dreamComposerHint.
  ///
  /// In zh, this message translates to:
  /// **'在这儿写点什么…'**
  String get dreamComposerHint;

  /// No description provided for @dreamWaitingBehindDoor.
  ///
  /// In zh, this message translates to:
  /// **'梦在门后等待'**
  String get dreamWaitingBehindDoor;

  /// No description provided for @cancelAction.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancelAction;

  /// No description provided for @deleteAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteAction;

  /// No description provided for @saveAction.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get saveAction;

  /// No description provided for @savingAction.
  ///
  /// In zh, this message translates to:
  /// **'保存中…'**
  String get savingAction;

  /// No description provided for @closeAction.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get closeAction;

  /// No description provided for @startGameAction.
  ///
  /// In zh, this message translates to:
  /// **'开局'**
  String get startGameAction;

  /// No description provided for @groupDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除「{title}」？'**
  String groupDeleteTitle(String title);

  /// No description provided for @groupDeleteWarning.
  ///
  /// In zh, this message translates to:
  /// **'聊天记录一并清除，不可恢复。'**
  String get groupDeleteWarning;

  /// No description provided for @groupTitle.
  ///
  /// In zh, this message translates to:
  /// **'群聊'**
  String get groupTitle;

  /// No description provided for @groupEyebrow.
  ///
  /// In zh, this message translates to:
  /// **'多角色一起聊'**
  String get groupEyebrow;

  /// No description provided for @groupCreateAction.
  ///
  /// In zh, this message translates to:
  /// **'新建群聊'**
  String get groupCreateAction;

  /// No description provided for @groupEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有群聊'**
  String get groupEmpty;

  /// No description provided for @groupRosterDeleteHint.
  ///
  /// In zh, this message translates to:
  /// **'{members} · 长按删除'**
  String groupRosterDeleteHint(String members);

  /// No description provided for @groupSelectAtLeastOne.
  ///
  /// In zh, this message translates to:
  /// **'至少选择 1 位角色'**
  String get groupSelectAtLeastOne;

  /// No description provided for @groupSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'选择成员（已选 {count} 位）'**
  String groupSelectedCount(int count);

  /// No description provided for @groupNoCharacters.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用角色'**
  String get groupNoCharacters;

  /// No description provided for @groupMinResponders.
  ///
  /// In zh, this message translates to:
  /// **'N 最少回应人数：{count}'**
  String groupMinResponders(int count);

  /// No description provided for @groupMaxResponders.
  ///
  /// In zh, this message translates to:
  /// **'M 最多回应人数：{count}'**
  String groupMaxResponders(int count);

  /// No description provided for @groupCreating.
  ///
  /// In zh, this message translates to:
  /// **'建群中…'**
  String get groupCreating;

  /// No description provided for @groupConfirmCreate.
  ///
  /// In zh, this message translates to:
  /// **'确认建群'**
  String get groupConfirmCreate;

  /// No description provided for @groupSendToStart.
  ///
  /// In zh, this message translates to:
  /// **'发送消息，开始群聊'**
  String get groupSendToStart;

  /// No description provided for @groupMembersResponding.
  ///
  /// In zh, this message translates to:
  /// **'成员陆续回应中…'**
  String get groupMembersResponding;

  /// No description provided for @groupSendHint.
  ///
  /// In zh, this message translates to:
  /// **'发送消息…'**
  String get groupSendHint;

  /// No description provided for @groupKeepAtLeastOne.
  ///
  /// In zh, this message translates to:
  /// **'至少保留 1 位成员'**
  String get groupKeepAtLeastOne;

  /// No description provided for @groupSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'群设置'**
  String get groupSettingsTitle;

  /// No description provided for @groupManagingCount.
  ///
  /// In zh, this message translates to:
  /// **'成员管理（已选 {count} 位）'**
  String groupManagingCount(int count);

  /// No description provided for @groupDreamEnterAction.
  ///
  /// In zh, this message translates to:
  /// **'入梦'**
  String get groupDreamEnterAction;

  /// No description provided for @groupDreamTitle.
  ///
  /// In zh, this message translates to:
  /// **'群聊梦境'**
  String get groupDreamTitle;

  /// No description provided for @groupDreamEntering.
  ///
  /// In zh, this message translates to:
  /// **'坠入中…'**
  String get groupDreamEntering;

  /// No description provided for @groupDreamEnterFailed.
  ///
  /// In zh, this message translates to:
  /// **'后端没有允许这次入梦'**
  String get groupDreamEnterFailed;

  /// No description provided for @groupDreamSendToStart.
  ///
  /// In zh, this message translates to:
  /// **'发送消息，开始群聊梦境'**
  String get groupDreamSendToStart;

  /// No description provided for @groupDreamMembersResponding.
  ///
  /// In zh, this message translates to:
  /// **'角色们陆续回应中…'**
  String get groupDreamMembersResponding;

  /// No description provided for @groupDreamSendHint.
  ///
  /// In zh, this message translates to:
  /// **'在梦中说些什么…'**
  String get groupDreamSendHint;

  /// No description provided for @groupDreamExitAction.
  ///
  /// In zh, this message translates to:
  /// **'醒来'**
  String get groupDreamExitAction;

  /// No description provided for @groupDreamExitConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确定要醒来吗？'**
  String get groupDreamExitConfirmTitle;

  /// No description provided for @groupDreamExitConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'退出后本轮群聊梦境立即结束，无法继续。'**
  String get groupDreamExitConfirmBody;

  /// No description provided for @groupDreamBlockedHint.
  ///
  /// In zh, this message translates to:
  /// **'群聊梦境进行中，现实对话暂时锁定'**
  String get groupDreamBlockedHint;

  /// No description provided for @readingDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除《{title}》？'**
  String readingDeleteTitle(String title);

  /// No description provided for @irreversibleWarning.
  ///
  /// In zh, this message translates to:
  /// **'此操作不可撤销。'**
  String get irreversibleWarning;

  /// No description provided for @readingInProgress.
  ///
  /// In zh, this message translates to:
  /// **'阅读中'**
  String get readingInProgress;

  /// No description provided for @readingTogetherTitle.
  ///
  /// In zh, this message translates to:
  /// **'一起看书'**
  String get readingTogetherTitle;

  /// No description provided for @readingChatTitle.
  ///
  /// In zh, this message translates to:
  /// **'看书聊天'**
  String get readingChatTitle;

  /// No description provided for @readingLibrary.
  ///
  /// In zh, this message translates to:
  /// **'书库'**
  String get readingLibrary;

  /// No description provided for @readingAdding.
  ///
  /// In zh, this message translates to:
  /// **'添加中…'**
  String get readingAdding;

  /// No description provided for @readingAddPdf.
  ///
  /// In zh, this message translates to:
  /// **'添加 PDF'**
  String get readingAddPdf;

  /// No description provided for @readingEmptyLibrary.
  ///
  /// In zh, this message translates to:
  /// **'书库还是空的，先添加一本 PDF 吧'**
  String get readingEmptyLibrary;

  /// No description provided for @readingBookPages.
  ///
  /// In zh, this message translates to:
  /// **'{pages} 页 · 长按删除'**
  String readingBookPages(String pages);

  /// No description provided for @readingPageStatus.
  ///
  /// In zh, this message translates to:
  /// **'第 {current} 页 / 共 {total} 页'**
  String readingPageStatus(String current, String total);

  /// No description provided for @readingLoadingPage.
  ///
  /// In zh, this message translates to:
  /// **'加载页面内容…'**
  String get readingLoadingPage;

  /// No description provided for @readingPreviousPage.
  ///
  /// In zh, this message translates to:
  /// **'← 上一页'**
  String get readingPreviousPage;

  /// No description provided for @readingNextPage.
  ///
  /// In zh, this message translates to:
  /// **'下一页 →'**
  String get readingNextPage;

  /// No description provided for @chessTitle.
  ///
  /// In zh, this message translates to:
  /// **'国际象棋'**
  String get chessTitle;

  /// No description provided for @chessIntro.
  ///
  /// In zh, this message translates to:
  /// **'和他下一局国际象棋。你执白先行，点棋子选中，再点目标格落子。'**
  String get chessIntro;

  /// No description provided for @chessGameOver.
  ///
  /// In zh, this message translates to:
  /// **'对局结束：{result}'**
  String chessGameOver(String result);

  /// No description provided for @chessTurn.
  ///
  /// In zh, this message translates to:
  /// **'当前走子方：{side}'**
  String chessTurn(String side);

  /// No description provided for @whiteSide.
  ///
  /// In zh, this message translates to:
  /// **'白方'**
  String get whiteSide;

  /// No description provided for @blackSide.
  ///
  /// In zh, this message translates to:
  /// **'黑方'**
  String get blackSide;

  /// No description provided for @gameChatTitle.
  ///
  /// In zh, this message translates to:
  /// **'棋局闲聊'**
  String get gameChatTitle;

  /// No description provided for @gomokuTitle.
  ///
  /// In zh, this message translates to:
  /// **'五子棋'**
  String get gomokuTitle;

  /// No description provided for @gomokuIntro.
  ///
  /// In zh, this message translates to:
  /// **'和他下一局五子棋。你先手，触屏落子。'**
  String get gomokuIntro;

  /// No description provided for @drawResult.
  ///
  /// In zh, this message translates to:
  /// **'平局'**
  String get drawResult;

  /// No description provided for @gomokuWinner.
  ///
  /// In zh, this message translates to:
  /// **'{stone} 获胜'**
  String gomokuWinner(String stone);

  /// No description provided for @gomokuTurn.
  ///
  /// In zh, this message translates to:
  /// **'当前落子方：{stone}'**
  String gomokuTurn(String stone);

  /// No description provided for @blackStone.
  ///
  /// In zh, this message translates to:
  /// **'黑棋'**
  String get blackStone;

  /// No description provided for @whiteStone.
  ///
  /// In zh, this message translates to:
  /// **'白棋'**
  String get whiteStone;

  /// No description provided for @boardLoading.
  ///
  /// In zh, this message translates to:
  /// **'棋盘加载中…'**
  String get boardLoading;

  /// No description provided for @themePresetsTitle.
  ///
  /// In zh, this message translates to:
  /// **'颜色预设'**
  String get themePresetsTitle;

  /// No description provided for @themePresetsDescription.
  ///
  /// In zh, this message translates to:
  /// **'本机可保存多个预设；浏览器可导出颜色 mod。'**
  String get themePresetsDescription;

  /// No description provided for @newAction.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get newAction;

  /// No description provided for @themeNoCustomPresets.
  ///
  /// In zh, this message translates to:
  /// **'还没有自定义预设'**
  String get themeNoCustomPresets;

  /// No description provided for @themeBundledReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'mods/ 内置 · 只读'**
  String get themeBundledReadOnly;

  /// No description provided for @themeLocalPreset.
  ///
  /// In zh, this message translates to:
  /// **'{base}底色 · 本机预设'**
  String themeLocalPreset(String base);

  /// No description provided for @themeCopyEdit.
  ///
  /// In zh, this message translates to:
  /// **'复制并编辑'**
  String get themeCopyEdit;

  /// No description provided for @editAction.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get editAction;

  /// No description provided for @themeResetColors.
  ///
  /// In zh, this message translates to:
  /// **'重置颜色'**
  String get themeResetColors;

  /// No description provided for @themeExportMod.
  ///
  /// In zh, this message translates to:
  /// **'导出 mod'**
  String get themeExportMod;

  /// No description provided for @themeDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除颜色预设？'**
  String get themeDeleteTitle;

  /// No description provided for @themeDeleteWarning.
  ///
  /// In zh, this message translates to:
  /// **'“{name}”会从本机删除，此操作无法撤销。'**
  String themeDeleteWarning(String name);

  /// No description provided for @themeExportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已下载颜色 mod；请手动放进项目 mods/ 文件夹。'**
  String get themeExportSuccess;

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败'**
  String get exportFailed;

  /// No description provided for @themeEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑颜色预设'**
  String get themeEditTitle;

  /// No description provided for @themePresetNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'预设名称'**
  String get themePresetNameLabel;

  /// No description provided for @themeComponentColors.
  ///
  /// In zh, this message translates to:
  /// **'组件颜色'**
  String get themeComponentColors;

  /// No description provided for @themeFreeColor.
  ///
  /// In zh, this message translates to:
  /// **'自由选色'**
  String get themeFreeColor;

  /// No description provided for @themeHue.
  ///
  /// In zh, this message translates to:
  /// **'色相 {value}°'**
  String themeHue(int value);

  /// No description provided for @themeOpacity.
  ///
  /// In zh, this message translates to:
  /// **'透明度 {value}%'**
  String themeOpacity(int value);

  /// No description provided for @themeApplyRgbTooltip.
  ///
  /// In zh, this message translates to:
  /// **'应用 RGB'**
  String get themeApplyRgbTooltip;

  /// No description provided for @previewLabel.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get previewLabel;

  /// No description provided for @themeCharacterPreview.
  ///
  /// In zh, this message translates to:
  /// **'角色消息与正文颜色'**
  String get themeCharacterPreview;

  /// No description provided for @themeUserPreview.
  ///
  /// In zh, this message translates to:
  /// **'用户消息颜色'**
  String get themeUserPreview;

  /// No description provided for @themeDefaultName.
  ///
  /// In zh, this message translates to:
  /// **'我的配色'**
  String get themeDefaultName;

  /// No description provided for @themeNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建颜色预设'**
  String get themeNewTitle;

  /// No description provided for @nameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get nameLabel;

  /// No description provided for @themeLightBase.
  ///
  /// In zh, this message translates to:
  /// **'信纸底色'**
  String get themeLightBase;

  /// No description provided for @themeDarkBase.
  ///
  /// In zh, this message translates to:
  /// **'夜间底色'**
  String get themeDarkBase;

  /// No description provided for @createAction.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get createAction;

  /// No description provided for @avatarCropTitle.
  ///
  /// In zh, this message translates to:
  /// **'裁切头像'**
  String get avatarCropTitle;

  /// No description provided for @avatarCropHelp.
  ///
  /// In zh, this message translates to:
  /// **'拖动调整位置，双指或手势缩放。保存后只作为手机端本地头像。'**
  String get avatarCropHelp;

  /// No description provided for @resetAction.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get resetAction;

  /// No description provided for @closeTooltip.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get closeTooltip;

  /// No description provided for @themeCustomPaletteTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义色盘'**
  String get themeCustomPaletteTitle;

  /// No description provided for @themeEditingRole.
  ///
  /// In zh, this message translates to:
  /// **'正在修改：{role}'**
  String themeEditingRole(String role);

  /// No description provided for @themePreviewBody.
  ///
  /// In zh, this message translates to:
  /// **'这套颜色会应用到聊天、抽屉和设置组件。'**
  String get themePreviewBody;

  /// No description provided for @themeSidebarPreview.
  ///
  /// In zh, this message translates to:
  /// **'侧边栏背景 / 文字图标 / 选中态'**
  String get themeSidebarPreview;

  /// No description provided for @themeUserBubblePreview.
  ///
  /// In zh, this message translates to:
  /// **'用户气泡也会跟着变。'**
  String get themeUserBubblePreview;

  /// No description provided for @noOptions.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用项'**
  String get noOptions;

  /// No description provided for @attachmentSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'附加内容'**
  String get attachmentSheetTitle;

  /// No description provided for @attachmentDocument.
  ///
  /// In zh, this message translates to:
  /// **'文档'**
  String get attachmentDocument;

  /// No description provided for @attachmentDocumentSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'txt / md / docx · 5MB 内'**
  String get attachmentDocumentSubtitle;

  /// No description provided for @attachmentImage.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get attachmentImage;

  /// No description provided for @attachmentImageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'可多选 · 走后端视觉识别'**
  String get attachmentImageSubtitle;

  /// No description provided for @attachmentRecording.
  ///
  /// In zh, this message translates to:
  /// **'录音'**
  String get attachmentRecording;

  /// No description provided for @attachmentRecordingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'长按说话 · 转写 · 待接入'**
  String get attachmentRecordingSubtitle;

  /// No description provided for @themeRoleSurface.
  ///
  /// In zh, this message translates to:
  /// **'页面底色'**
  String get themeRoleSurface;

  /// No description provided for @themeRoleSurfaceSoft.
  ///
  /// In zh, this message translates to:
  /// **'输入栏底色'**
  String get themeRoleSurfaceSoft;

  /// No description provided for @themeRoleSurfaceDeep.
  ///
  /// In zh, this message translates to:
  /// **'深层底色'**
  String get themeRoleSurfaceDeep;

  /// No description provided for @themeRoleSurfaceEdge.
  ///
  /// In zh, this message translates to:
  /// **'边框线'**
  String get themeRoleSurfaceEdge;

  /// No description provided for @themeRoleInk1.
  ///
  /// In zh, this message translates to:
  /// **'主文字'**
  String get themeRoleInk1;

  /// No description provided for @themeRoleInk2.
  ///
  /// In zh, this message translates to:
  /// **'次文字'**
  String get themeRoleInk2;

  /// No description provided for @themeRoleInk3.
  ///
  /// In zh, this message translates to:
  /// **'弱文字'**
  String get themeRoleInk3;

  /// No description provided for @themeRoleInk4.
  ///
  /// In zh, this message translates to:
  /// **'淡线条'**
  String get themeRoleInk4;

  /// No description provided for @themeRoleCharacter.
  ///
  /// In zh, this message translates to:
  /// **'角色主色/焦点'**
  String get themeRoleCharacter;

  /// No description provided for @themeRoleCharacterDeep.
  ///
  /// In zh, this message translates to:
  /// **'顶部/侧边栏'**
  String get themeRoleCharacterDeep;

  /// No description provided for @themeRoleCharacterSoft.
  ///
  /// In zh, this message translates to:
  /// **'选中项/柔底'**
  String get themeRoleCharacterSoft;

  /// No description provided for @themeRoleCharacterOn.
  ///
  /// In zh, this message translates to:
  /// **'侧边栏文字'**
  String get themeRoleCharacterOn;

  /// No description provided for @themeRoleDanger.
  ///
  /// In zh, this message translates to:
  /// **'危险提示'**
  String get themeRoleDanger;

  /// No description provided for @themeRoleWarn.
  ///
  /// In zh, this message translates to:
  /// **'提醒提示'**
  String get themeRoleWarn;

  /// No description provided for @themeRoleOk.
  ///
  /// In zh, this message translates to:
  /// **'正常提示'**
  String get themeRoleOk;

  /// No description provided for @themeRoleSend.
  ///
  /// In zh, this message translates to:
  /// **'发送按钮'**
  String get themeRoleSend;

  /// No description provided for @themeRoleUserBubble.
  ///
  /// In zh, this message translates to:
  /// **'用户气泡'**
  String get themeRoleUserBubble;

  /// No description provided for @themeRoleUserBubbleText.
  ///
  /// In zh, this message translates to:
  /// **'用户气泡文字'**
  String get themeRoleUserBubbleText;

  /// No description provided for @themeRoleScrim.
  ///
  /// In zh, this message translates to:
  /// **'遮罩颜色'**
  String get themeRoleScrim;

  /// No description provided for @backendInvalidAddress.
  ///
  /// In zh, this message translates to:
  /// **'后端地址格式不对'**
  String get backendInvalidAddress;

  /// No description provided for @tokenSetTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置访问 Token'**
  String get tokenSetTitle;

  /// No description provided for @tokenReplaceTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置 / 更换 Token'**
  String get tokenReplaceTitle;

  /// No description provided for @tokenHelp.
  ///
  /// In zh, this message translates to:
  /// **'填后端签发的 mobile token（emt_ 开头）；旧 admin secret 仍可用但不建议。Token 只保存在 Android 本机私有存储中，不会打包进应用。'**
  String get tokenHelp;

  /// No description provided for @tokenRequiredError.
  ///
  /// In zh, this message translates to:
  /// **'请填写访问 Token'**
  String get tokenRequiredError;

  /// No description provided for @saveFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String saveFailedMessage(String error);

  /// No description provided for @deviceAdminRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先启用“陪伴锁屏确认”的设备管理器权限'**
  String get deviceAdminRequired;

  /// No description provided for @accessibilityAuthorized.
  ///
  /// In zh, this message translates to:
  /// **'陪伴操作助手已授权'**
  String get accessibilityAuthorized;

  /// No description provided for @shoppingAppMissing.
  ///
  /// In zh, this message translates to:
  /// **'没有找到 {label}，先手动安装或确认包名'**
  String shoppingAppMissing(String label);

  /// No description provided for @orderBubbleShown.
  ///
  /// In zh, this message translates to:
  /// **'已弹出 {label} 购物车确认悬浮窗'**
  String orderBubbleShown(String label);

  /// No description provided for @overlayPermissionRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先允许“显示在其他应用上层”，回来后再点一次'**
  String get overlayPermissionRequired;

  /// No description provided for @screenPushFailed.
  ///
  /// In zh, this message translates to:
  /// **'屏幕上下文推送失败：{error}'**
  String screenPushFailed(String error);

  /// No description provided for @accessibilityRequiredForScreen.
  ///
  /// In zh, this message translates to:
  /// **'请先开启无障碍服务，才能读取屏幕上下文'**
  String get accessibilityRequiredForScreen;

  /// No description provided for @screenContextEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂时没有可读的屏幕上下文'**
  String get screenContextEmpty;

  /// No description provided for @behaviorTestQueued.
  ///
  /// In zh, this message translates to:
  /// **'已写入主动行为测试：{label}'**
  String behaviorTestQueued(String label);

  /// No description provided for @behaviorTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'主动行为测试失败：{error}'**
  String behaviorTestFailed(String error);

  /// No description provided for @profileNameHint.
  ///
  /// In zh, this message translates to:
  /// **'留空则显示后端角色名'**
  String get profileNameHint;

  /// No description provided for @restoreDefaultAction.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get restoreDefaultAction;

  /// No description provided for @avatarSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'头像保存失败'**
  String get avatarSaveFailed;

  /// No description provided for @backendNodeTitle.
  ///
  /// In zh, this message translates to:
  /// **'后端节点'**
  String get backendNodeTitle;

  /// No description provided for @backendNodeHelp.
  ///
  /// In zh, this message translates to:
  /// **'插线调试用 127.0.0.1；脱线使用电脑局域网 IP。'**
  String get backendNodeHelp;

  /// No description provided for @userIdLabel.
  ///
  /// In zh, this message translates to:
  /// **'用户 ID'**
  String get userIdLabel;

  /// No description provided for @userIdHint.
  ///
  /// In zh, this message translates to:
  /// **'QQ 号或后端约定的 uid，仅限字母数字下划线短横线'**
  String get userIdHint;

  /// No description provided for @invalidAddressError.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效地址'**
  String get invalidAddressError;

  /// No description provided for @userIdInvalidError.
  ///
  /// In zh, this message translates to:
  /// **'仅支持字母、数字、下划线、短横线'**
  String get userIdInvalidError;

  /// No description provided for @saveReconnectAction.
  ///
  /// In zh, this message translates to:
  /// **'保存并重连'**
  String get saveReconnectAction;

  /// No description provided for @relayDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'推送中继（ntfy）'**
  String get relayDialogTitle;

  /// No description provided for @relayAddressLabel.
  ///
  /// In zh, this message translates to:
  /// **'中继地址'**
  String get relayAddressLabel;

  /// No description provided for @relayTopicHint.
  ///
  /// In zh, this message translates to:
  /// **'例：mychar-wake-a1b2c3（当作密码，用随机串）'**
  String get relayTopicHint;

  /// No description provided for @relayTokenLabel.
  ///
  /// In zh, this message translates to:
  /// **'token（可选）'**
  String get relayTokenLabel;

  /// No description provided for @relayTokenHint.
  ///
  /// In zh, this message translates to:
  /// **'中继服务无鉴权时留空'**
  String get relayTokenHint;

  /// No description provided for @relayHelp.
  ///
  /// In zh, this message translates to:
  /// **'需与后端 config.yaml 的 relay_base_url/relay_topic/relay_token 三项一致。留空 topic 会关闭中继实时唤醒，退化为周期补偿轮询。'**
  String get relayHelp;

  /// No description provided for @relayTopicInvalidError.
  ///
  /// In zh, this message translates to:
  /// **'仅支持小写字母、数字、/ _ -，且不超过 128 字符'**
  String get relayTopicInvalidError;

  /// No description provided for @untrustedAddressError.
  ///
  /// In zh, this message translates to:
  /// **'未信任该地址'**
  String get untrustedAddressError;

  /// No description provided for @dreamLeaveTitle.
  ///
  /// In zh, this message translates to:
  /// **'要走了吗'**
  String get dreamLeaveTitle;

  /// No description provided for @dreamStayFallback.
  ///
  /// In zh, this message translates to:
  /// **'再待一会儿吧。'**
  String get dreamStayFallback;

  /// No description provided for @dreamLeaveAction.
  ///
  /// In zh, this message translates to:
  /// **'还是要走'**
  String get dreamLeaveAction;

  /// No description provided for @dreamStayAction.
  ///
  /// In zh, this message translates to:
  /// **'留下'**
  String get dreamStayAction;

  /// No description provided for @fileTypeUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'后端当前只支持 txt / md / docx'**
  String get fileTypeUnsupported;

  /// No description provided for @fileTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'后端文件上限是 5MB'**
  String get fileTooLarge;

  /// No description provided for @fileFailureLabel.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get fileFailureLabel;

  /// No description provided for @imageTypeUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'后端当前只支持 jpg / png / gif / webp / heic / bmp'**
  String get imageTypeUnsupported;

  /// No description provided for @imageTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'后端图片上限是单张 10MB'**
  String get imageTooLarge;

  /// No description provided for @imageCountPreview.
  ///
  /// In zh, this message translates to:
  /// **'📎 {count}张图片：{names}{suffix}'**
  String imageCountPreview(int count, String names, String suffix);

  /// No description provided for @imageFailureLabel.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get imageFailureLabel;

  /// No description provided for @meituanName.
  ///
  /// In zh, this message translates to:
  /// **'美团'**
  String get meituanName;

  /// No description provided for @taobaoName.
  ///
  /// In zh, this message translates to:
  /// **'淘宝'**
  String get taobaoName;

  /// No description provided for @capabilityTitle.
  ///
  /// In zh, this message translates to:
  /// **'能力检查'**
  String get capabilityTitle;

  /// No description provided for @capabilityRefreshTooltip.
  ///
  /// In zh, this message translates to:
  /// **'重新检测'**
  String get capabilityRefreshTooltip;

  /// No description provided for @capabilityLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取系统状态…'**
  String get capabilityLoading;

  /// No description provided for @capabilityUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'暂时读不到状态，稍后再试。'**
  String get capabilityUnavailable;

  /// No description provided for @capabilityNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'通知权限'**
  String get capabilityNotificationTitle;

  /// No description provided for @capabilityNotificationSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'允许系统通知，后台主动消息才能弹出来。'**
  String get capabilityNotificationSubtitle;

  /// No description provided for @enabledStatus.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get enabledStatus;

  /// No description provided for @disabledStatus.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get disabledStatus;

  /// No description provided for @enableAction.
  ///
  /// In zh, this message translates to:
  /// **'去开启'**
  String get enableAction;

  /// No description provided for @configureAction.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get configureAction;

  /// No description provided for @authorizeAction.
  ///
  /// In zh, this message translates to:
  /// **'去授权'**
  String get authorizeAction;

  /// No description provided for @authorizedStatus.
  ///
  /// In zh, this message translates to:
  /// **'已豁免'**
  String get authorizedStatus;

  /// No description provided for @capabilityBatteryTitle.
  ///
  /// In zh, this message translates to:
  /// **'电池优化豁免'**
  String get capabilityBatteryTitle;

  /// No description provided for @capabilityBatteryEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已允许后台持续运行；仍建议检查厂商自启动与后台白名单。'**
  String get capabilityBatteryEnabled;

  /// No description provided for @capabilityBatteryDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未豁免：息屏或 Doze 时后台轮询可能暂停。'**
  String get capabilityBatteryDisabled;

  /// No description provided for @capabilityOverlayTitle.
  ///
  /// In zh, this message translates to:
  /// **'悬浮窗权限'**
  String get capabilityOverlayTitle;

  /// No description provided for @capabilityOverlaySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'显示在桌面和其他 App 上层，用于短句提醒和确认。'**
  String get capabilityOverlaySubtitle;

  /// No description provided for @capabilityAccessibilityTitle.
  ///
  /// In zh, this message translates to:
  /// **'无障碍服务'**
  String get capabilityAccessibilityTitle;

  /// No description provided for @capabilityAccessibilitySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'读取当前 App、窗口标题和可见文字摘要；不上传截图。'**
  String get capabilityAccessibilitySubtitle;

  /// No description provided for @capabilityScreenContextTitle.
  ///
  /// In zh, this message translates to:
  /// **'屏幕上下文'**
  String get capabilityScreenContextTitle;

  /// No description provided for @capabilityScreenContextEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启：仅上传经过本机过滤的非敏感文本摘要。'**
  String get capabilityScreenContextEnabled;

  /// No description provided for @capabilityScreenContextDisabled.
  ///
  /// In zh, this message translates to:
  /// **'默认关闭；能力页仍可读取经过本机过滤的快照。'**
  String get capabilityScreenContextDisabled;

  /// No description provided for @capabilityDeviceAdminTitle.
  ///
  /// In zh, this message translates to:
  /// **'设备管理器锁屏'**
  String get capabilityDeviceAdminTitle;

  /// No description provided for @capabilityDeviceAdminSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'授权后才能执行 lockNow，每次仍由界面确认。'**
  String get capabilityDeviceAdminSubtitle;

  /// No description provided for @capabilityBackgroundServiceTitle.
  ///
  /// In zh, this message translates to:
  /// **'后台通知服务'**
  String get capabilityBackgroundServiceTitle;

  /// No description provided for @switchEnabledStatus.
  ///
  /// In zh, this message translates to:
  /// **'开关已开'**
  String get switchEnabledStatus;

  /// No description provided for @capabilityRelayTitle.
  ///
  /// In zh, this message translates to:
  /// **'中继连接状态'**
  String get capabilityRelayTitle;

  /// No description provided for @capabilityGateTitle.
  ///
  /// In zh, this message translates to:
  /// **'通知闸门状态'**
  String get capabilityGateTitle;

  /// No description provided for @testingStatus.
  ///
  /// In zh, this message translates to:
  /// **'测试中'**
  String get testingStatus;

  /// No description provided for @normalStatus.
  ///
  /// In zh, this message translates to:
  /// **'正常'**
  String get normalStatus;

  /// No description provided for @capabilityBackendTitle.
  ///
  /// In zh, this message translates to:
  /// **'adb reverse / 后端连通'**
  String get capabilityBackendTitle;

  /// No description provided for @detectingStatus.
  ///
  /// In zh, this message translates to:
  /// **'检测中'**
  String get detectingStatus;

  /// No description provided for @connectedStatus.
  ///
  /// In zh, this message translates to:
  /// **'已接入'**
  String get connectedStatus;

  /// No description provided for @detectAction.
  ///
  /// In zh, this message translates to:
  /// **'检测'**
  String get detectAction;

  /// No description provided for @notConnectedStatus.
  ///
  /// In zh, this message translates to:
  /// **'未接通'**
  String get notConnectedStatus;

  /// No description provided for @capabilityEditBackendTooltip.
  ///
  /// In zh, this message translates to:
  /// **'修改后端节点'**
  String get capabilityEditBackendTooltip;

  /// No description provided for @capabilityDetectBackendTooltip.
  ///
  /// In zh, this message translates to:
  /// **'检测后端连通'**
  String get capabilityDetectBackendTooltip;

  /// No description provided for @capabilityBackendLastError.
  ///
  /// In zh, this message translates to:
  /// **'最近连接错误：{error}'**
  String capabilityBackendLastError(String error);

  /// No description provided for @capabilityBackendNotice.
  ///
  /// In zh, this message translates to:
  /// **'能力页只显示手机端可验证的状态；adb reverse 本身在电脑侧执行，手机端通过 127.0.0.1 后端是否可达来判断。'**
  String get capabilityBackendNotice;

  /// No description provided for @relayConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get relayConnected;

  /// No description provided for @relayConnecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中'**
  String get relayConnecting;

  /// No description provided for @relayStopped.
  ///
  /// In zh, this message translates to:
  /// **'已停止'**
  String get relayStopped;

  /// No description provided for @relayError.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get relayError;

  /// No description provided for @relayUnconfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get relayUnconfigured;

  /// No description provided for @syncStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步状态'**
  String get syncStatusTitle;

  /// No description provided for @readingStatus.
  ///
  /// In zh, this message translates to:
  /// **'读取中'**
  String get readingStatus;

  /// No description provided for @failedStatus.
  ///
  /// In zh, this message translates to:
  /// **'失败：{error}'**
  String failedStatus(String error);

  /// No description provided for @pendingSyncStatus.
  ///
  /// In zh, this message translates to:
  /// **'待同步'**
  String get pendingSyncStatus;

  /// No description provided for @pollingStatus.
  ///
  /// In zh, this message translates to:
  /// **'轮询中'**
  String get pollingStatus;

  /// No description provided for @activatedStatus.
  ///
  /// In zh, this message translates to:
  /// **'已激活'**
  String get activatedStatus;

  /// No description provided for @pendingActivationStatus.
  ///
  /// In zh, this message translates to:
  /// **'待激活'**
  String get pendingActivationStatus;

  /// No description provided for @syncChatStatus.
  ///
  /// In zh, this message translates to:
  /// **'聊天记录：{status}'**
  String syncChatStatus(String status);

  /// No description provided for @syncGardenStatus.
  ///
  /// In zh, this message translates to:
  /// **'花园状态：{status}'**
  String syncGardenStatus(String status);

  /// No description provided for @syncMobileStatus.
  ///
  /// In zh, this message translates to:
  /// **'主动消息：{status}{received}'**
  String syncMobileStatus(String status, String received);

  /// No description provided for @syncReceivedSuffix.
  ///
  /// In zh, this message translates to:
  /// **' · 已接收 {count} 条'**
  String syncReceivedSuffix(int count);

  /// No description provided for @syncLatestMessage.
  ///
  /// In zh, this message translates to:
  /// **'最近一条：{content}'**
  String syncLatestMessage(String content);

  /// No description provided for @screenSnapshotEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无屏幕快照'**
  String get screenSnapshotEmpty;

  /// No description provided for @screenDebugTitle.
  ///
  /// In zh, this message translates to:
  /// **'屏幕上下文调试'**
  String get screenDebugTitle;

  /// No description provided for @readAction.
  ///
  /// In zh, this message translates to:
  /// **'读取'**
  String get readAction;

  /// No description provided for @pushAction.
  ///
  /// In zh, this message translates to:
  /// **'推送'**
  String get pushAction;

  /// No description provided for @screenWindow.
  ///
  /// In zh, this message translates to:
  /// **'窗口：{value}'**
  String screenWindow(String value);

  /// No description provided for @screenVisible.
  ///
  /// In zh, this message translates to:
  /// **'可见：{value}'**
  String screenVisible(String value);

  /// No description provided for @screenClickable.
  ///
  /// In zh, this message translates to:
  /// **'可点：{value}'**
  String screenClickable(String value);

  /// No description provided for @behaviorTestTitle.
  ///
  /// In zh, this message translates to:
  /// **'主动行为测试'**
  String get behaviorTestTitle;

  /// No description provided for @behaviorTestDescription.
  ///
  /// In zh, this message translates to:
  /// **'写入后端 mobile queue，并立刻轮询一次；悬浮/确认类会在前台直接弹。'**
  String get behaviorTestDescription;

  /// No description provided for @behaviorOverlayTestMessage.
  ///
  /// In zh, this message translates to:
  /// **'（测试）我在屏幕边等你一下。'**
  String get behaviorOverlayTestMessage;

  /// No description provided for @behaviorLockTestMessage.
  ///
  /// In zh, this message translates to:
  /// **'（测试）要我替你锁屏吗？点确认才会执行。'**
  String get behaviorLockTestMessage;

  /// No description provided for @behaviorTakeoutTestMessage.
  ///
  /// In zh, this message translates to:
  /// **'（测试）要不要打开外卖页看一眼？不会自动下单。'**
  String get behaviorTakeoutTestMessage;

  /// No description provided for @behaviorNotificationTestMessage.
  ///
  /// In zh, this message translates to:
  /// **'（测试）这是一条普通主动消息。'**
  String get behaviorNotificationTestMessage;

  /// No description provided for @notificationLabel.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get notificationLabel;

  /// No description provided for @overlayLabel.
  ///
  /// In zh, this message translates to:
  /// **'悬浮'**
  String get overlayLabel;

  /// No description provided for @lockConfirmLabel.
  ///
  /// In zh, this message translates to:
  /// **'锁屏确认'**
  String get lockConfirmLabel;

  /// No description provided for @takeoutConfirmLabel.
  ///
  /// In zh, this message translates to:
  /// **'外卖确认'**
  String get takeoutConfirmLabel;

  /// No description provided for @backgroundDeliveryTitle.
  ///
  /// In zh, this message translates to:
  /// **'后台交付测试'**
  String get backgroundDeliveryTitle;

  /// No description provided for @backgroundDeliveryDescription.
  ///
  /// In zh, this message translates to:
  /// **'不经过后端，直接测试手机端后台通知 / 存在感悬浮 / 工具确认分流。'**
  String get backgroundDeliveryDescription;

  /// No description provided for @normalNotificationLabel.
  ///
  /// In zh, this message translates to:
  /// **'普通通知'**
  String get normalNotificationLabel;

  /// No description provided for @presenceOverlayLabel.
  ///
  /// In zh, this message translates to:
  /// **'存在感悬浮'**
  String get presenceOverlayLabel;

  /// No description provided for @lockRequestLabel.
  ///
  /// In zh, this message translates to:
  /// **'锁屏请求'**
  String get lockRequestLabel;

  /// No description provided for @takeoutRequestLabel.
  ///
  /// In zh, this message translates to:
  /// **'外卖请求'**
  String get takeoutRequestLabel;

  /// No description provided for @behaviorDecisionTitle.
  ///
  /// In zh, this message translates to:
  /// **'行为裁决状态'**
  String get behaviorDecisionTitle;

  /// No description provided for @behaviorDecisionEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没读取。刷新后会显示后端最近一次行为裁决为什么弹或为什么没弹。'**
  String get behaviorDecisionEmpty;

  /// No description provided for @readFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'读取失败：{error}'**
  String readFailedMessage(String error);

  /// No description provided for @fieldTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get fieldTime;

  /// No description provided for @fieldReason.
  ///
  /// In zh, this message translates to:
  /// **'原因'**
  String get fieldReason;

  /// No description provided for @fieldEvent.
  ///
  /// In zh, this message translates to:
  /// **'事件'**
  String get fieldEvent;

  /// No description provided for @fieldApp.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get fieldApp;

  /// No description provided for @fieldNarrative.
  ///
  /// In zh, this message translates to:
  /// **'叙事'**
  String get fieldNarrative;

  /// No description provided for @fieldScreen.
  ///
  /// In zh, this message translates to:
  /// **'屏幕'**
  String get fieldScreen;

  /// No description provided for @fieldReply.
  ///
  /// In zh, this message translates to:
  /// **'回复'**
  String get fieldReply;

  /// No description provided for @backendDiagnosticsTitle.
  ///
  /// In zh, this message translates to:
  /// **'后端 / 资产诊断'**
  String get backendDiagnosticsTitle;

  /// No description provided for @backendDiagnosticsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'点击“读取”拉取后端节点、数据目录、模型、角色卡、世界书、破限和梦境配置。'**
  String get backendDiagnosticsEmpty;

  /// No description provided for @diagnosticBackendNode.
  ///
  /// In zh, this message translates to:
  /// **'后端节点'**
  String get diagnosticBackendNode;

  /// No description provided for @diagnosticDataPath.
  ///
  /// In zh, this message translates to:
  /// **'数据目录'**
  String get diagnosticDataPath;

  /// No description provided for @diagnosticNoPermission.
  ///
  /// In zh, this message translates to:
  /// **'无权限（mobile token 预期行为）'**
  String get diagnosticNoPermission;

  /// No description provided for @diagnosticMetaMode.
  ///
  /// In zh, this message translates to:
  /// **'元模式'**
  String get diagnosticMetaMode;

  /// No description provided for @diagnosticDangerMode.
  ///
  /// In zh, this message translates to:
  /// **'危险模式'**
  String get diagnosticDangerMode;

  /// No description provided for @diagnosticSafeMode.
  ///
  /// In zh, this message translates to:
  /// **'安全模式'**
  String get diagnosticSafeMode;

  /// No description provided for @diagnosticModel.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get diagnosticModel;

  /// No description provided for @diagnosticShortTermRounds.
  ///
  /// In zh, this message translates to:
  /// **'短期轮数'**
  String get diagnosticShortTermRounds;

  /// No description provided for @diagnosticCharacterCard.
  ///
  /// In zh, this message translates to:
  /// **'角色卡'**
  String get diagnosticCharacterCard;

  /// No description provided for @diagnosticLorebook.
  ///
  /// In zh, this message translates to:
  /// **'世界书'**
  String get diagnosticLorebook;

  /// No description provided for @diagnosticJailbreak.
  ///
  /// In zh, this message translates to:
  /// **'破限'**
  String get diagnosticJailbreak;

  /// No description provided for @diagnosticEntries.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String diagnosticEntries(int count);

  /// No description provided for @diagnosticDream.
  ///
  /// In zh, this message translates to:
  /// **'梦境'**
  String get diagnosticDream;

  /// No description provided for @diagnosticDreamLorebook.
  ///
  /// In zh, this message translates to:
  /// **'梦境世界书'**
  String get diagnosticDreamLorebook;

  /// No description provided for @enabledShortStatus.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get enabledShortStatus;

  /// No description provided for @disabledShortStatus.
  ///
  /// In zh, this message translates to:
  /// **'未启用'**
  String get disabledShortStatus;

  /// No description provided for @diagnosticDreamLayer.
  ///
  /// In zh, this message translates to:
  /// **'梦境层'**
  String get diagnosticDreamLayer;

  /// No description provided for @diagnosticDreamJailbreak.
  ///
  /// In zh, this message translates to:
  /// **'梦境破限'**
  String get diagnosticDreamJailbreak;

  /// No description provided for @diagnosticPhoneControlTool.
  ///
  /// In zh, this message translates to:
  /// **'手机自动化 · 角色授权'**
  String get diagnosticPhoneControlTool;

  /// No description provided for @diagnosticPhoneControlVision.
  ///
  /// In zh, this message translates to:
  /// **'手机自动化 · 视觉模型'**
  String get diagnosticPhoneControlVision;

  /// No description provided for @phoneControlTestTitle.
  ///
  /// In zh, this message translates to:
  /// **'手机自动化测试'**
  String get phoneControlTestTitle;

  /// No description provided for @phoneControlTestDescription.
  ///
  /// In zh, this message translates to:
  /// **'跳过 LLM 判断和聊天内二次确认，直接发起一次手机自动化任务；仍然要先在后端开启危险模式，安全模式下会直接拒绝。'**
  String get phoneControlTestDescription;

  /// No description provided for @phoneControlTestHint.
  ///
  /// In zh, this message translates to:
  /// **'任务描述，例如：帮我点杯奶茶'**
  String get phoneControlTestHint;

  /// No description provided for @phoneControlTestButton.
  ///
  /// In zh, this message translates to:
  /// **'发起测试任务'**
  String get phoneControlTestButton;

  /// No description provided for @phoneControlTestEmptyTask.
  ///
  /// In zh, this message translates to:
  /// **'先写清楚要测试的任务'**
  String get phoneControlTestEmptyTask;

  /// No description provided for @capabilityLastPollNone.
  ///
  /// In zh, this message translates to:
  /// **'最近周期补偿：暂无'**
  String get capabilityLastPollNone;

  /// No description provided for @capabilityLastPoll.
  ///
  /// In zh, this message translates to:
  /// **'最近周期补偿：{time}'**
  String capabilityLastPoll(String time);

  /// No description provided for @capabilityLastErrorNone.
  ///
  /// In zh, this message translates to:
  /// **'最近错误原因：无'**
  String get capabilityLastErrorNone;

  /// No description provided for @capabilityLastError.
  ///
  /// In zh, this message translates to:
  /// **'最近错误原因：{error}'**
  String capabilityLastError(String error);

  /// No description provided for @capabilityNativeRelayRunning.
  ///
  /// In zh, this message translates to:
  /// **'原生中继服务正在运行'**
  String get capabilityNativeRelayRunning;

  /// No description provided for @capabilityNativeRelayStopped.
  ///
  /// In zh, this message translates to:
  /// **'原生中继服务未运行；前台由 Flutter 每 5 秒读取主动消息'**
  String get capabilityNativeRelayStopped;

  /// No description provided for @capabilityGateTestOn.
  ///
  /// In zh, this message translates to:
  /// **'测试模式已开启：仅绕过静音时段和 30 分钟冷却'**
  String get capabilityGateTestOn;

  /// No description provided for @capabilityGateTestOff.
  ///
  /// In zh, this message translates to:
  /// **'测试模式关闭：静音时段 23:30–06:30，普通通知间隔 30 分钟'**
  String get capabilityGateTestOff;

  /// No description provided for @noneStatus.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get noneStatus;

  /// No description provided for @capabilityGateSummary.
  ///
  /// In zh, this message translates to:
  /// **'{mode}。\n被吞计数：{count} / 最近原因：{reason}'**
  String capabilityGateSummary(String mode, int count, String reason);

  /// No description provided for @capabilityOverlayLastError.
  ///
  /// In zh, this message translates to:
  /// **'{base}\n权限已授予，但最近一次弹窗失败{time}：{error}'**
  String capabilityOverlayLastError(String base, String time, String error);

  /// No description provided for @capabilitySignalNone.
  ///
  /// In zh, this message translates to:
  /// **'最近信号时间：暂无'**
  String get capabilitySignalNone;

  /// No description provided for @capabilitySignalTime.
  ///
  /// In zh, this message translates to:
  /// **'最近信号时间：{time}'**
  String capabilitySignalTime(String time);

  /// No description provided for @capabilityHeartbeatNone.
  ///
  /// In zh, this message translates to:
  /// **'最近中继心跳：暂无'**
  String get capabilityHeartbeatNone;

  /// No description provided for @capabilityHeartbeatTime.
  ///
  /// In zh, this message translates to:
  /// **'最近中继心跳：{time}'**
  String capabilityHeartbeatTime(String time);

  /// No description provided for @capabilityRelayLastError.
  ///
  /// In zh, this message translates to:
  /// **'\n最近中继错误：{error}'**
  String capabilityRelayLastError(String error);

  /// No description provided for @capabilityRelayConfigWarning.
  ///
  /// In zh, this message translates to:
  /// **'\n已连接不等于后端已配置；请检查后端 relay_base_url / relay_topic 与此处完全一致。'**
  String get capabilityRelayConfigWarning;

  /// No description provided for @capabilityLoopbackHint.
  ///
  /// In zh, this message translates to:
  /// **'{url} · 真机调试依赖 adb reverse tcp:8080 tcp:8080'**
  String capabilityLoopbackHint(String url);

  /// No description provided for @capabilityRemoteHint.
  ///
  /// In zh, this message translates to:
  /// **'{url} · 局域网/VPN/内网穿透需可达'**
  String capabilityRemoteHint(String url);

  /// No description provided for @notEnabledStatus.
  ///
  /// In zh, this message translates to:
  /// **'未开启'**
  String get notEnabledStatus;

  /// No description provided for @sandboxSuffix.
  ///
  /// In zh, this message translates to:
  /// **'  ⚠ 沙盒'**
  String get sandboxSuffix;

  /// No description provided for @diagnosticReadError.
  ///
  /// In zh, this message translates to:
  /// **'{label}：读取失败 — {message}'**
  String diagnosticReadError(String label, String message);

  /// No description provided for @backgroundTestPresenceMessage.
  ///
  /// In zh, this message translates to:
  /// **'我在这里。你不想说话也没关系。'**
  String get backgroundTestPresenceMessage;

  /// No description provided for @backgroundTestLockMessage.
  ///
  /// In zh, this message translates to:
  /// **'已经很晚了。要我替你锁一下屏吗？'**
  String get backgroundTestLockMessage;

  /// No description provided for @backgroundTestTakeoutMessage.
  ///
  /// In zh, this message translates to:
  /// **'你还没吃东西。要不要我帮你打开外卖页看一眼？'**
  String get backgroundTestTakeoutMessage;

  /// No description provided for @backgroundTestDefaultMessage.
  ///
  /// In zh, this message translates to:
  /// **'我刚才给你发了一句话，回来再看也可以。'**
  String get backgroundTestDefaultMessage;

  /// No description provided for @checkingStatus.
  ///
  /// In zh, this message translates to:
  /// **'检测中'**
  String get checkingStatus;

  /// No description provided for @notRunStatus.
  ///
  /// In zh, this message translates to:
  /// **'未运行'**
  String get notRunStatus;

  /// No description provided for @chatTodayLine.
  ///
  /// In zh, this message translates to:
  /// **'今日 · {date} · {time}'**
  String chatTodayLine(String date, String time);

  /// No description provided for @moodNeutral.
  ///
  /// In zh, this message translates to:
  /// **'平静'**
  String get moodNeutral;

  /// No description provided for @moodGentle.
  ///
  /// In zh, this message translates to:
  /// **'温柔'**
  String get moodGentle;

  /// No description provided for @moodThinking.
  ///
  /// In zh, this message translates to:
  /// **'在想事情'**
  String get moodThinking;

  /// No description provided for @moodHappy.
  ///
  /// In zh, this message translates to:
  /// **'开心'**
  String get moodHappy;

  /// No description provided for @moodSad.
  ///
  /// In zh, this message translates to:
  /// **'有点难过'**
  String get moodSad;

  /// No description provided for @moodSurprised.
  ///
  /// In zh, this message translates to:
  /// **'有点惊讶'**
  String get moodSurprised;

  /// No description provided for @moodAngry.
  ///
  /// In zh, this message translates to:
  /// **'有点生气'**
  String get moodAngry;

  /// No description provided for @moodSleepy.
  ///
  /// In zh, this message translates to:
  /// **'困困的'**
  String get moodSleepy;

  /// No description provided for @moodYandere.
  ///
  /// In zh, this message translates to:
  /// **'情绪很浓'**
  String get moodYandere;

  /// No description provided for @oemBackgroundGuide.
  ///
  /// In zh, this message translates to:
  /// **'厂商后台白名单参考：\n小米：设置 → 应用设置 → 应用管理 → {appName} → 省电策略/自启动 → 无限制并开启自启动\nOPPO：设置 → 应用 → 自启动/耗电管理 → {appName} → 允许后台运行\nvivo：设置 → 电池 → 后台耗电管理 → {appName} → 允许后台高耗电\n华为：设置 → 应用和服务 → 应用启动管理 → {appName} → 手动管理并允许后台活动'**
  String oemBackgroundGuide(String appName);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
