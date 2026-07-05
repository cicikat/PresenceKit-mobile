import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'models/background_status.dart';
import 'models/capability_status.dart';
import 'models/screen_context.dart';
import 'services/app_settings_store.dart';
import 'services/backend_client.dart';

part 'models/app_models.dart';
part 'pages/app_shell.dart';
part 'widgets/common_widgets.dart';
part 'widgets/capability_widgets.dart';
part 'widgets/chat_widgets.dart';
part 'widgets/diary_widgets.dart';
part 'widgets/dream_widgets.dart';
part 'widgets/drawer_widgets.dart';
part 'widgets/garden_widgets.dart';
part 'widgets/profile_widgets.dart';
part 'widgets/settings_editor_widgets.dart';
part 'widgets/settings_widgets.dart';

const String _defaultBackendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      title: '叶瑄 · AI 陪伴',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'serif',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F3A2E)),
      ),
      home: const YexuanCompanionApp(),
    );
  }
}
