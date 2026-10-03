import 'package:flutter/services.dart';

import 'platform_settings_channel.dart';

/// 通过系统「另存为」对话框把角色发送的文本文件保存到用户选择的位置。
/// 复用 settings 通道的 exportThemeJson（文本内容 + 可选 mime，上限 256KB 字符串）。
class ChatArtifactSaver {
  const ChatArtifactSaver();

  bool get available => PlatformSettingsChannel.available;

  /// 用户取消或系统拒绝时返回 false。
  Future<bool> saveText({
    required String filename,
    required String mime,
    required String text,
  }) async {
    if (!available) return false;
    try {
      return await PlatformSettingsChannel.channel.invokeMethod<bool>(
            'exportThemeJson',
            {'name': filename, 'json': text, 'mime': mime.split(';').first},
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
