# 测试与开发

## 常用命令

```powershell
# Flutter 分析
$env:DART_SUPPRESS_ANALYTICS='true'
$env:APPDATA='D:\ai\yexuan_memery\.tool-home'
D:\soft3\flutter\bin\flutter.bat analyze

# Flutter 测试
$env:DART_SUPPRESS_ANALYTICS='true'
$env:APPDATA='D:\ai\yexuan_memery\.tool-home'
D:\soft3\flutter\bin\flutter.bat test

# Debug APK
$env:DART_SUPPRESS_ANALYTICS='true'
$env:APPDATA='D:\ai\yexuan_memery\.tool-home'
$env:ANDROID_HOME='D:\soft3\AndroidSDK'
$env:ANDROID_SDK_ROOT='D:\soft3\AndroidSDK'
D:\soft3\flutter\bin\flutter.bat build apk --debug
```

## ADB 调试

```powershell
D:\soft3\AndroidSDK\platform-tools\adb.exe reverse tcp:8080 tcp:8080
D:\soft3\AndroidSDK\platform-tools\adb.exe install build\app\outputs\flutter-apk\app-debug.apk
```

也可以用根目录：

```text
mobile_dev_control.bat
```

## 当前测试覆盖

`test/widget_test.dart` 只有一个 smoke test：

- 启动 `MyApp`。
- 检查主界面出现“叶瑄”。
- 检查输入框文案“对他说些什么…”。

它不能覆盖：

- 后端接口解析。
- mobile poll 生命周期。
- Android MethodChannel。
- 后台服务通知闸门。
- 无障碍屏幕上下文。
- 悬浮窗确认动作。

后续重构 `lib/main.dart` 前，建议先补模型解析和 `BackendClient` 的单元测试。
