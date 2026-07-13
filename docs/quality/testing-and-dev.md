# 测试与开发

## 常用命令

> 以下命令在仓库根目录执行。`flutter`/`adb` 不在 PATH 时，SDK 位置以
> `android/local.properties` 的 `flutter.sdk`、`sdk.dir` 为准（机器本地文件，不入库）。

```powershell
# Flutter 分析
$env:DART_SUPPRESS_ANALYTICS='true'
$env:APPDATA="$PWD\.tool-home"
flutter analyze

# Flutter 测试
$env:DART_SUPPRESS_ANALYTICS='true'
$env:APPDATA="$PWD\.tool-home"
flutter test

# Debug APK（ANDROID_HOME 按本机 SDK 位置设置，或省略让 gradle 读 local.properties）
$env:DART_SUPPRESS_ANALYTICS='true'
$env:APPDATA="$PWD\.tool-home"
flutter build apk --debug
```

## ADB 调试

```powershell
adb reverse tcp:8080 tcp:8080
adb install build\app\outputs\flutter-apk\app-debug.apk
```

也可以用根目录：

```text
mobile_dev_control.bat
```


## 电脑浏览器预览

Flutter Web 已可编译。双击仓库根目录的 `电脑浏览器预览.bat`，脚本会探测 Flutter SDK、执行 `flutter pub get`，然后启动 Chrome 开发预览；如果 Chrome 不在 Flutter 设备列表中，则自动回退到 Edge（默认端口 `5353`）。也可以在命令行附加 Flutter 参数；脚本会把参数原样传给 `flutter run`。

浏览器预览覆盖 Flutter 页面布局和交互；通知、悬浮窗、无障碍、设备管理器、录音、文件选择等 Android 原生能力在电脑浏览器中没有真实实现。若要加载后端数据，浏览器还需要后端允许来自 `http://localhost:5353` 的 CORS 请求；否则仍可预览静态页面，但网络请求会被浏览器拦截。

## 当前测试覆盖

`test/` 下共 10 个文件，按覆盖内容分组如下（逐文件列出实际断言范围，而不是笼统的"能不能覆盖某个大类"）：

### UI / 模型基础

- `widget_test.dart`：
  - `PromptAssets.fromJson`、`DreamSettings.fromJson` 的纯函数单测。
  - `MyApp` smoke test：启动后主界面出现文案 "TA"、输入框文案"对他说些什么…"。
  - `SystemSettingsSheet`：访问 Token 入口排在能力检查之前，点击"更换"触发回调。
  - `DreamPage`：保留独立作曲框和"醒来"退出按钮。

### 后端请求层

- `backend_client_error_test.dart`：`BackendClient.debugExtractError` 纯函数在 401/403/429/其他状态码、有/无 JSON body 时的文案分支。
- `backend_client_request_test.dart`（新增）：用实现 `dart:io` `HttpClient`/`HttpClientRequest`/`HttpClientResponse` 接口的假对象（不依赖真实 socket）驱动 `BackendClient._request` 端到端路径——
  - base url 拼接（GET/POST 请求命中 `baseUrl + path`，带 `Authorization: Bearer` 头）；
  - 空 token / 不受信 base url 在发请求前就被拒绝；
  - 200 且 body 是 JSON object 时正常解析，body 不是 object 时报错；
  - 非 200 响应按状态码走 `_extractError`（403 带 detail、401 固定文案）；
  - socket 异常 / 超时 / 响应体不是合法 JSON 三条异常路径分别映射到对应的中文提示。
  - `BackendClient` 为此增加了 `httpClientFactory` 构造参数（默认仍是 `HttpClient.new`），只做了测试驱动的最小可注入性改动，不改变生产行为。

### mobile poll 生命周期

- `foreground_mobile_delivery_contract_test.dart`：
  - `BackendChatResponse.fromJson` 的 `msg_id`/`turn_id` 解析与回退。
  - 前台投递：收到消息先持久化 `seenMobileMessageIds` 再按批次最大 seq ack，并推进游标。
  - ack 网络调用失败时消息仍展示、游标不推进、重试时 `after` 仍为旧值。
  - 同步回复（`sendChat` 返回）与随后 poll 回来的同一条消息按 id 对账去重，不按内容指纹误判。
- `mobile_poll_lifecycle_test.dart`（新增，补前一份文件未覆盖的两块）：
  - ack **网络调用成功但游标持久化失败**（`saveLastAckedMobileSeq` 抛错）时，内存态和下一轮 poll 的 `after` 参数都不能推进——区别于"ack 网络调用本身失败"的既有用例。
  - 同一条消息（同 id/同 seq）在后续 poll 批次里被再次投递时，按 id 去重，不会重复展示。
- `background_status_test.dart`：`RelayConnectionStatus.connected` 的新鲜度窗口（3 分钟心跳）判定。
- `android_relay_signal_contract_test.dart`：直接读取 `MobileNotificationService.kt` 源码文本，断言中继信号事件（`signal` 字段）会转入认证 poll、旧版 `content` 字段负载不会被直接投递。这是"源码文本契约"，不是运行时行为测试。

### Android MethodChannel

- `method_channel_contract_test.dart`（新增）：用 `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler` mock 平台侧，覆盖 `presence_mobile/settings` 通道里"最缺"的三类方法——
  - 后台服务启停：`start/stopBackgroundNotifications`、`isBackgroundNotificationServiceRunning`、`getBackgroundPollStatus`、`getRelayConnectionStatus`、`getNotificationGateStatus`、`debugBackgroundDelivery`；
  - 无障碍：`isAccessibilityServiceEnabled`、`requestAccessibilityPermission`、`captureScreenContext`（ForUpload）；
  - 悬浮窗：`canDrawOverlays`、`showFloatingBubble`/`showOrderBubble`、`hideFloatingBubble`、`isDeviceAdminActive`、`requestDeviceAdmin`、`lockScreen`、`openShoppingApp`。
  - 每个方法验证：调用的方法名、参数形状（如 `{'target': ...}`）、返回值如何被 `AppSettingsStore` 解析成 Dart 模型、以及平台侧抛 `PlatformException` 时的兜底值。
  - `PlatformSettingsChannel` 为此保留了 `debugForceChannelAvailable` 测试钩子：`flutter test` 始终以宿主 OS（如 Windows）运行，`Platform.isAndroid` 恒为 `false`，不加这个测试钩子的话所有方法在测试里都会被早退守卫直接短路，永远走不到 channel 调用。生产环境该值恒为 `false`，不影响真机行为。
- `no_hardcoded_qq_number_test.dart`：扫描 `lib/`、`android/`、`docs/`、`test/` 下的文本文件，确保真实 QQ 号不会被提交进仓库（与 `Emerald-presence` 后端仓库的同名测试各自独立，是镜像关系，不是重复）。
- `app_shell_structure_test.dart`：守住 `app_shell.dart` 当前 1499 行基线，并断言历史 `part` 结构不再回到入口。

### 仍未覆盖（真实缺口，不是文档没写）

- `presence_mobile/settings` 通道里除上述三类之外的方法（`Backend`/`RelayBaseUrl`/`RelayToken`/`RelayTopic`/`OwnerUserId`、自定义主题、头像与文件选取、可信明文域名等）暂无契约测试。
- `BackendClient.uploadFiles`（multipart 上传）、`fetchDiagnostics`（并发聚合多个只读端点）、`updatePromptAssets`/`updateDreamSettings`（PATCH 分支）没有针对请求层的专门测试，只在别处被间接调用。
- Android 原生代码（Kotlin）本身的运行时行为（通知闸门、无障碍采集、悬浮窗确认、设备管理器锁屏）完全没有测试；`android_relay_signal_contract_test.dart` 只是对源码文本做字符串断言，不是真实运行 Kotlin 代码。这类覆盖需要 Android instrumented test，`flutter test` 覆盖不到。
- 后台原生 poll 与前台 `_pollMobile` 的交接时机（`isBackgroundNotificationServiceRunning() == true` 时前台跳过 poll）目前只在 Dart 侧假设为真，没有场景化测试验证切换瞬间的行为。

## 最近一次本机验证（2026-07-13）

- `flutter analyze`：通过，0 issues。
- `flutter test`：未进入任何断言即因本机 Flutter tester 回环连接 `HttpException: Connection closed before full header was received` 失败；这是环境故障，不能记为测试通过。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
