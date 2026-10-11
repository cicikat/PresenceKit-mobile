# 34 — 微信布局参考校准

范围：仅手机 messenger 呈现，依据用户深浅两张截图；无跨端影响，不改接口、持久化格式或通知。

- [x] 校准日夜颜色、标题、头像、气泡比例与尖角；保留字号/透明度偏好。
- [x] 校准输入栏布局，录音、附件、发送和草稿保持可用。
- [x] 静态分析、相关回归、深浅 Flutter 渲染图目检。
- [ ] 真机 OEM 字体、系统安全区、软键盘及触摸验收（无设备时 not-run）。

手机状态栏由系统绘制，不复制参考的时间、电池、热点和未读计数；会话内容及头像仍使用真实数据。

证据：conversation_presentation.dart / chat_scene.dart / chat_widgets.dart；layout_render_test.dart 深浅渲染目检；messenger_composer_test.dart 表情/附件/发送/录音回归；共 35 项相关测试通过。最终修改的 5 个 Dart 文件静态分析零问题。

用户追加规格：
- [x] 引用条独立于正文气泡，显示可证实的原发送者；未知作者不猜测。
- [x] 相邻聊天消息间隔达到 10 分钟时显示一次日期＋时间，忽略技术行；补边界回归。

追加验收：messenger_display_test.dart 的 9/10 分钟、跨午夜、旧日期、倒序和引用作者歧义回归通过。35 项相关回归通过；最终引用纯文本补验 messenger 渲染测试通过，深浅截图已目检。adb devices 无设备，真机项 not-run。

最新 dev debug APK 构建成功：`build/app/outputs/flutter-apk/app-dev-debug.apk`；SHA-256 `96F443D0B7D3079E22D58EF5482CADEE8461D94EEE07FE1D7353D43CA0AFED29`。未安装/未发布。
