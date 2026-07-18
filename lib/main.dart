import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/app_shell.dart';

export 'models/app_models.dart';
export 'app_constants.dart';
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '陪伴',
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
      home: const CompanionApp(),
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
                  const Text(
                    '页面出了点问题',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
                          label: const Text('回到主界面'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('重试'),
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
