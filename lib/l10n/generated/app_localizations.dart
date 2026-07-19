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
