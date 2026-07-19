import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/locale_controller.dart';
import 'l10n/l10n.dart';
import 'pages/app_shell.dart';

export 'models/app_models.dart';
export 'app_constants.dart';
export 'controllers/locale_controller.dart';
export 'l10n/l10n.dart';
export 'pages/app_shell.dart';
export 'widgets/activity_widgets.dart';
export 'widgets/capability_widgets.dart';
export 'widgets/chat_widgets.dart';
export 'widgets/chess_widgets.dart';
export 'widgets/common_widgets.dart';
export 'widgets/diary_widgets.dart';
export 'widgets/drawer_widgets.dart';
export 'widgets/dream_widgets.dart';
export 'widgets/garden_widgets.dart';
export 'widgets/gomoku_widgets.dart';
export 'widgets/group_widgets.dart';
export 'widgets/profile_widgets.dart';
export 'widgets/reading_widgets.dart';
export 'widgets/settings_editor_widgets.dart';
export 'widgets/settings_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) => AppErrorFallback(details: details);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFFECE3D0),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final localeController = LocaleController();
  await localeController.load();
  runApp(MyApp(localeController: localeController));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.localeController});

  final LocaleController? localeController;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final LocaleController _localeController;
  late final bool _ownsLocaleController;

  @override
  void initState() {
    super.initState();
    _ownsLocaleController = widget.localeController == null;
    _localeController = widget.localeController ?? LocaleController();
    if (!_localeController.loaded) {
      unawaited(_localeController.load());
    }
  }

  @override
  void dispose() {
    if (_ownsLocaleController) _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _localeController,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => context.l10n.appTitle,
        locale: _localeController.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: (locales, supportedLocales) {
          final preferred = locales?.firstOrNull;
          if (preferred?.languageCode == 'en') return const Locale('en');
          if (preferred?.languageCode == 'zh') {
            return const Locale('zh');
          }
          return const Locale('zh');
        },
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'serif',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F3A2E)),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFFECE3D0),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFFF7F0E1),
            border: OutlineInputBorder(),
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Color(0xFF1F3A2E),
            selectionColor: Color(0x553E705A),
            selectionHandleColor: Color(0xFF1F3A2E),
          ),
        ),
        home: CompanionApp(localeController: _localeController),
      ),
    );
  }
}

class AppErrorFallback extends StatefulWidget {
  const AppErrorFallback({super.key, required this.details});

  final FlutterErrorDetails details;

  @override
  State<AppErrorFallback> createState() => _AppErrorFallbackState();
}

class _AppErrorFallbackState extends State<AppErrorFallback> {
  int _retryCount = 0;

  void _retry() {
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    setState(() => _retryCount += 1);
  }

  void _backHome() {
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    if (navigator == null) return;
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final errorText = widget.details.exceptionAsString();
    final l10n = context.l10n;
    return Material(
      color: const Color(0xFFECE3D0),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 36,
                    color: Color(0xFF8B3A2B),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.appErrorTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF2A1F18),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorText,
                    key: ValueKey(_retryCount),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF5A4A3A)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _backHome,
                          icon: const Icon(Icons.home_outlined),
                          label: Text(l10n.backHome),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(l10n.retry),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
