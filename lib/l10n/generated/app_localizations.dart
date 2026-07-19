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
