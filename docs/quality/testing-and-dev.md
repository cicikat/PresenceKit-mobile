# 测试与开发

## v1 签名与凭据测试

```powershell
# Dev 调试包不需要正式签名 keystore。
flutter build apk --debug --flavor dev

# 没有 android/key.properties 或其引用的 keystore 时，该命令必须失败。
flutter build apk --release --flavor prod

# Kotlin 凭据迁移策略测试（在 android/ 目录执行）。
.\gradlew.bat testDebugUnitTest
```

`CredentialMigrationTest` 覆盖 legacy 到 secure 的成功迁移与明文清理、安全写入失败时保留明文、secure 优先级、幂等性、token 替换和删除。Android Keystore 的真实操作及已安装应用恢复，仍需按 `docs/v1-release-readiness.md` 的真机流程验收。

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
flutter build apk --debug --flavor dev
```

## Dev/Test 与正式包

打包入口：`AA2` 构建并安装 Dev 调试 APK；`AA1` 只构建正式发行 APK；`AA3` 在全部发行验证通过后构建正式发行 APK，并只安装到一台已授权的 Android 设备。

项目使用 Android product flavor：`dev` 与 `prod`。

- `flutter run --flavor dev`：日常开发，安装为 `com.presencekit.mobile.dev`，显示名为 `PresenceKit Dev`。
- `AA2打包测试包并给手机.bat`：构建并复制 Dev debug APK 到 `dist/dev/PresenceKit-mobile-dev.apk`，然后自动安装到唯一已授权的 Android 手机；没有设备、设备未授权或连接多个设备时明确失败，不读取正式 `android/key.properties`。
- `AA1打包发行包.bat`：只构建正式发行 APK，使用 `prod` flavor 和固定 release signing identity。
- `AA3打包发行包并传给手机.bat`：使用与 AA1 相同的正式校验流程，验证通过后安装到唯一已授权的 Android 设备。

Dev 与正式包可以同时安装；Android 会按 applicationId 隔离应用数据、SharedPreferences、Keystore、通知 channel 和组件权限。Dev 数据不能作为正式升级迁移证据。正式 `v0.2.2 → v1` 升级必须使用正式发行包，并按 `docs/v1-release-readiness.md` 的同一 signing identity 真机流程验证。

Android Studio 可在 Flutter Run Configuration 的 Flavor 字段选择 `dev` 或 `prod`；VS Code 可选择仓库提供的 `PresenceKit Dev` / `PresenceKit Prod` Flutter 启动配置。

## ADB 调试

```powershell
adb reverse tcp:8080 tcp:8080
adb install build\app\outputs\flutter-apk\app-dev-debug.apk
```

也可以用根目录：

```text
mobile_dev_control.bat
```


## 电脑浏览器预览

Flutter Web 已可编译。双击仓库根目录的 `电脑浏览器预览.bat`，脚本会探测 Flutter SDK、执行 `flutter pub get`，然后启动 Chrome 开发预览；如果 Chrome 不在 Flutter 设备列表中，则自动回退到 Edge（默认端口 `5353`）。也可以在命令行附加 Flutter 参数；脚本会把参数原样传给 `flutter run`。

浏览器预览覆盖 Flutter 页面布局和交互；通知、悬浮窗、无障碍、设备管理器、录音、文件选择等 Android 原生能力在电脑浏览器中没有真实实现。若要加载后端数据，浏览器还需要后端允许来自 `http://localhost:5353` 的 CORS 请求；否则仍可预览静态页面，但网络请求会被浏览器拦截。

颜色预设在浏览器中使用 localStorage 持久化；设置页的“导出 mod”会下载纯颜色 JSON。
浏览器不会直接写仓库。需要手动把下载的 `*.mobile-theme.json` 放入根目录 `mods/`，
再执行下一次 APK 构建。完整契约见 `docs/mobile/color-mods.md`。

## 当前测试覆盖

截至 2026-08-10，`test/` 下有 17 个 Dart 测试文件，`android/app/src/test/` 下有 1 个 Kotlin 单元测试文件。下面先列出完整清单，再按覆盖内容说明实际断言范围；文件数量是源码盘点，不代表本轮已执行通过。

完整 Dart 清单：

- `android_relay_signal_contract_test.dart`
- `app_shell_structure_test.dart`
- `backend_client_error_test.dart`
- `backend_client_request_test.dart`
- `background_status_test.dart`
- `chat_reveal_test.dart`
- `foreground_mobile_delivery_contract_test.dart`
- `locale_controller_test.dart`
- `localization_contract_test.dart`
- `method_channel_contract_test.dart`
- `mobile_catchup_state_test.dart`
- `mobile_poll_lifecycle_test.dart`
- `no_hardcoded_qq_number_test.dart`
- `profile_status_controller_test.dart`
- `sticker_message_test.dart`
- `theme_controller_test.dart`
- `widget_test.dart`

Kotlin 单元测试：`android/app/src/test/kotlin/com/presencekit/mobile/CredentialMigrationTest.kt`。

### UI / 模型基础

- `widget_test.dart`：
  - `PromptAssets.fromJson`、`DreamSettings.fromJson` 的纯函数单测。
  - `MyApp` smoke test：启动后主界面出现文案 "TA"、输入框文案"对他说些什么…"。
  - `SystemSettingsSheet`：访问 Token 入口排在能力检查之前，点击"更换"触发回调。
  - `DreamPage`：保留独立作曲框和"醒来"退出按钮。
- `theme_controller_test.dart`：多预设保存/恢复、旧单色盘迁移、重置/删除和颜色 mod 往返解析。
- `locale_controller_test.dart`：默认跟随系统、持久化恢复、未知值回退，以及 `中文 → English → 中文` 即时切换和存储往返。
- `localization_contract_test.dart`：中英文 ARB 消息 key 完全一致、所有翻译非空，以及 `l10n.yaml` 保持生成输出与未翻译报告配置。


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
  - 语言偏好：`getAppLanguage` / `setAppLanguage` 的通道方法名和 `value` 参数。
  - `PlatformSettingsChannel` 为此保留了 `debugForceChannelAvailable` 测试钩子：`flutter test` 始终以宿主 OS（如 Windows）运行，`Platform.isAndroid` 恒为 `false`，不加这个测试钩子的话所有方法在测试里都会被早退守卫直接短路，永远走不到 channel 调用。生产环境该值恒为 `false`，不影响真机行为。
- `no_hardcoded_qq_number_test.dart`：扫描 `lib/`、`android/`、`docs/`、`test/` 下的文本文件，确保真实 QQ 号不会被提交进仓库（与 `Emerald-presence` 后端仓库的同名测试各自独立，是镜像关系，不是重复）。
- `app_shell_structure_test.dart`：守住 `app_shell.dart` 当前 1499 行基线，并断言历史 `part` 结构不再回到入口。

### 仍未覆盖（真实缺口，不是文档没写）

- `presence_mobile/settings` 通道里除上述三类之外的方法（`Backend`/`RelayBaseUrl`/`RelayToken`/`RelayTopic`/`OwnerUserId`、自定义主题、头像与文件选取、可信明文域名等）暂无契约测试。
- `BackendClient.uploadFiles`（multipart 上传）、`fetchDiagnostics`（并发聚合多个只读端点）、`updatePromptAssets`/`updateDreamSettings`（PATCH 分支）没有针对请求层的专门测试，只在别处被间接调用。
- Android 原生代码（Kotlin）本身的运行时行为（通知闸门、无障碍采集、悬浮窗确认、设备管理器锁屏）完全没有测试；`android_relay_signal_contract_test.dart` 只是对源码文本做字符串断言，不是真实运行 Kotlin 代码。这类覆盖需要 Android instrumented test，`flutter test` 覆盖不到。
- 后台原生 poll 与前台 `_pollMobile` 的交接时机（`isBackgroundNotificationServiceRunning() == true` 时前台跳过 poll）目前只在 Dart 侧假设为真，没有场景化测试验证切换瞬间的行为。

## 上一次本机验证记录（2026-07-19；非本轮结果）

本轮只更新文档，未重新执行以下命令；这些结果不能作为 2026-08-10 的最新通过证据。

- `flutter analyze`：通过，0 issues。
- `flutter test test/localization_contract_test.dart test/locale_controller_test.dart test/method_channel_contract_test.dart test/widget_test.dart`：Flutter tester 启动阶段持续无输出，未进入任何断言后人工终止；与本机既有 tester 回环环境故障属于同一测试器不可用边界，不能记为测试通过或断言失败。
- `flutter build web --no-pub`：通过，产物为 `build/web`。
- `flutter build apk --debug --flavor dev`：通过，产物为 `build/app/outputs/flutter-apk/app-dev-debug.apk`。

## CI、发布与真机边界

`.github/workflows/ci.yml` 当前执行 `flutter pub get`、`flutter gen-l10n`、`flutter analyze` 和 `flutter test`，但没有执行 `android/gradlew.bat testDebugUnitTest`，也没有 Android instrumented test job。因此 CI 不覆盖 Kotlin 原生运行时、通知权限、无障碍、悬浮窗、设备管理器、Doze、进程被杀或重启恢复。

`.github/workflows/release.yml` 当前仍执行无 flavor 的 `flutter build apk --release`，而 `android/app/build.gradle.kts` 定义了 `dev` / `prod` flavor。正式发布应以 `prod` flavor 和实际生成的产物路径为准；在 workflow 对齐前，不得把该 release job 的产物当作正式包验收证据。这是 CI 配置缺口，不是 Flutter 单测缺口。

仍需补充或保留为发布前人工验收的范围：

- Android instrumented test：通知闸门、无障碍过滤、悬浮窗确认、设备管理器锁屏、Keystore 迁移与安装后恢复；
- 后台 relay 在 Doze、进程被杀、设备重启、网络断开/恢复时的真机矩阵；
- 前台 poll 与后台服务交接瞬间的场景化测试；
- 正式签名包的安装、同包升级、替换/删除凭据和失败回滚；
- `/mobile/chat`、poll/ack 与后端、桌面端固定 commit 的跨仓协议兼容测试。
