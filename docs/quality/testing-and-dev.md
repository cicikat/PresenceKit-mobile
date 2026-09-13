# 测试与开发

## 梦境与生活记录 UI（2026-09-13）

本轮生成中英文本地化；静态分析零问题，梦境、生活记录、设置通道、聊天交互和本地化定向回归 77 项通过。覆盖等待回复时发送按钮保留/草稿恢复、描写统一缩进与透明底、隐藏用户时间、识别字段导入/未知内容保留、明确导入后覆盖备注并通过原 save 保存。Dev debug APK 构建通过，未安装真机；视觉与触摸验收待进行。

## 梦境醒来与逐字显示（2026-09-13）

- `flutter gen-l10n`、`flutter analyze --no-pub` 通过，零问题；全量 `flutter test --no-pub` 186 项通过。
- 新增梦境控制器/组件 6 项回归和请求层 1 项回归，覆盖关闭/归档确认、失败保留与重试、迟到响应、段落串行与点击推进、五种叙述样式逐字显示及重建不重播。
- 使用本机 Android Studio JBR 构建 `flutter build apk --debug --flavor dev --no-pub` 成功，产物 `build/app/outputs/flutter-apk/app-dev-debug.apk`；日志见本机 `build/dream-all-tests.log`、`build/dream-analyze.log`、`build/dream-build.log`。未安装真机或发布正式包。
- 三面与调用链核对见 [dream-wake-and-reveal.md](../mobile/dream-wake-and-reveal.md)，真实后端/手机体验验收仍为 observe。

## 聊天情况与资料设置（2026-09-12）

- `flutter gen-l10n`、`flutter analyze --no-pub` 通过；全量 Flutter 173 项通过，最后清理独立资料路由与处理未来日期后，日历/设置/请求/通道/结构 68 项定向回归通过。
- 覆盖 366 天闰年、连续天数未知边界、过期响应不覆盖、503 不伪装零数据、Bearer/char_id/date 查询、点选日详情、日周月年切换、390px 日夜布局和配色偏好读写；既有生活记录测试新增校正窗口背景、输入框填色及文字对比度断言。
- Java 21 构建 `flutter build apk --debug --flavor dev --no-pub` 通过，产物 `build/app/outputs/flutter-apk/app-dev-debug.apk`；未进行正式发布或替换手机已安装版本。
- 离屏日夜图见本机 `build/calendar-day.png`、`build/calendar-night.png`，为合成统计及测试字体；真实后端数据、设备触摸与重启恢复仍待验收。完整日志为 `build/calendar-tests.log`、`build/calendar-final-tests.log`、`build/calendar-build.log`。

## 工单 19（2026-09-12）

- flutter gen-l10n、flutter analyze --no-pub 通过；全量 Flutter 166 项通过。最后补齐夜间分类标签配色后，生活记录 12 项定向测试再次通过。覆盖自己回复、输入框获焦后复制/全选不弹键盘、可见全选及字效、通知已被原生 ack 后重读历史、日夜图片槽位、紧凑思考与卡片布局/对比度。
- Java 21（Android Studio jbr）执行 Android :app:testDevDebugUnitTest --tests com.presencekit.mobile.LifeRecordsTest，20 项通过；覆盖成功同步/merge/重启后图片仍在、删除清图、隔离与队列。首次使用 PATH Java 26 在 Gradle 启动失败，切换本机既有 JDK 21 后通过。
- Dev debug APK 构建通过；未发布、未修改发行版本或安装真机。adb devices 当前为空。build/review 保存测试日志和测试字体的离屏布局图；实际相册/OEM/通知/日夜背景迁移仍需真机。
- 第 7 项旧图恢复保持 open：旧版已经删掉本机源图，后端尚无下载接口。本轮修复后续图片保留，不声称复原旧图片；后端识别失败未修改，证据见 known-issues 与 cc-tasks/19-mobile-interaction-fixes.md。

2026-09-11 外观与历史刷新：Flutter analyze 零问题，全量 159 项测试通过；默认夜间配色调整后主题/界面 15 项通过。正式身份 1.0.1+39 真机覆盖安装成功，系统文件保存器成功导出“夜”JSON，已有背景/角色资料保留。随后 1.0.1+40 同签名覆盖安装成功，侧栏实测显示 1.0.1+40、用户占位和无群聊入口，已恢复夜间模式；包含导出色值作为默认夜间配置。没有对外发布。字体文件导入、JSON 导入及思考真实后端读取未完成真机全链路验收，不能以自动测试代替。

## 设置 UI 与 Dream 设置对齐（2026-09-11）

- `flutter gen-l10n`、`flutter analyze --no-pub` 通过，0 issues。
- 全量 `flutter test --no-pub` 152 项通过；最后收尾后相关 widget、请求、本地化与结构测试 25 项再次通过。覆盖顶部连接配置、折叠分组、320px 展开无溢出、动态 Dream 资产与多选/上下文字段 PATCH。
- `flutter build apk --debug --flavor dev --no-pub` 通过，产物为 `build/app/outputs/flutter-apk/app-dev-debug.apk`。未发布正式包或安装设备。
- 390×844 设置首页已通过离屏渲染检查；真实设备的权限往返、后台/夜间提醒和后端在线保存仍须联调，不能将静态 UI 检查作为真机证明。

## 生活记录前端验收（2026-09-11）

- `flutter gen-l10n`、`flutter analyze --no-pub` 通过，0 issues。
- `flutter test --no-pub test/life_records_test.dart test/localization_contract_test.dart test/widget_test.dart test/method_channel_contract_test.dart test/chat_recovery_upload_test.dart test/chat_interaction_regression_test.dart`：71 项通过。本功能 9 项覆盖本机日期/分类/条目查询、离线降级、分页、跨 owner 迟到响应、保存成功但刷新失败不重复创建、落盘失败、双语页面及金额币种校验；同时回归既有聊天图片/重试、壳层、抽屉和 settings channel。
- Android 目录执行 `gradlew.bat :app:testDevDebugUnitTest --tests com.presencekit.mobile.LifeRecordsTest --tests com.presencekit.mobile.BackendSecurityPolicyTest --tests com.presencekit.mobile.CredentialMigrationTest --console=plain`：22 项通过（生活记录 15、安全策略 2、凭据迁移 5）。使用 Robolectric 4.16 / API 28 验证 SQLite、源图恢复、相同请求重试、顺序编辑/删除、错 ack、冲突、拒绝后的校正、容量限制、后台 capability 和过期编辑器，不等同 OEM 真机验收。
- `flutter build apk --debug --flavor dev --no-pub` 成功，产物 `build/app/outputs/flutter-apk/app-dev-debug.apk`。未升级发布版本、未使用正式签名、未发布或安装到手机。
- 本机没有已连接 Android 设备或已配置 AVD。后端 `/life-records/*` 待接入；实际 OCR、角色查询、相机授权/回收、断网恢复、Doze/强停/重启和跨端删除列工单 17 的 I1–I4 未勾选项。
- 首轮测试曾发现请求首次发送/重试的 JSON 字段顺序不一致及旧 Flutter 的 dropdown 参数不兼容，均已修复后重跑通过；不将失败运行计作通过。

## 外观跟进验证（2026-09-09）

- 图片预览宽高各缩小 50%，附言独立气泡；删除仿导航条和空草稿占位行，系统底部安全区按实际 inset 填色。
- `flutter analyze --no-pub`：0 issues；`flutter test --no-pub test/chat_interaction_regression_test.dart test/widget_test.dart test/chat_recovery_upload_test.dart`：21 项通过。检查了缩小后的预览尺寸、附言气泡颜色/位置、原图查看，以及实际 App 壳在 0/24/48px 底部 inset 和 300px 键盘下的输入栏位置。
- `flutter build apk --debug --flavor dev --no-pub` 通过；更新 `build/app/outputs/flutter-apk/app-dev-debug.apk`。未安装到真机。

## 本轮验证（2026-09-09：聊天交互修复）

- `flutter gen-l10n`、`flutter analyze --no-pub` 通过，静态分析 0 issues。
- `flutter test --no-pub`：131 项通过。新增 12 项回归包含短列表双向边缘拖动、长列表底部上拉、离线启动后的手动恢复与合并刷新、原附件重试、原图查看、legacy data URI、裁切手势/像素边界、窄屏/横向小窗布局和键盘/弹窗背景几何稳定。
- `flutter build apk --debug --flavor dev --no-pub` 通过，产物 `build/app/outputs/flutter-apk/app-dev-debug.apk`。Kotlin 跨盘增量缓存报错后 fallback 编译成功，不影响最终 APK 产出。
- 这是 Dev 调试包，没有发布正式 APK、修改发行版本或安装到手机。真机补验：列表底部继续上拉松手、断网恢复、双指裁切、输入法/系统自由小窗切换、相册多图发送及点击原图。
- 历史原图跨重启读取仍为 open，见 `docs/known-issues.md`，不属于本轮已通过的 UI 原图显示范围。

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

# 协议 fixture 测试默认读取同级 Emerald-presence 仓库；非同级布局可显式指定
$env:PRESENCEKIT_PROTOCOL_FIXTURES='D:\path\to\Emerald-presence\tests\protocol_fixtures\v1'
flutter test test/protocol_fixtures_test.dart

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

`.github/workflows/ci.yml` 当前执行 `flutter pub get`、`flutter gen-l10n`、`flutter analyze` 和 `flutter test`，但没有执行 `android/gradlew.bat testDebugUnitTest`。独立的 `.github/workflows/android-instrumented.yml` 会在 API 35 模拟器执行 `connectedDevDebugAndroidTest`，覆盖部分 Android 框架级契约；它不覆盖 OEM 权限页面、真实通知投递、Doze、进程被杀、设备重启或网络恢复等真机生命周期场景。

`.github/workflows/release.yml` 当前使用 `prod` flavor，并在构建前接受 Android SDK license、安装项目要求的 `ndk;30.0.14904198`；它要求四个 GitHub Actions signing secrets（`ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`），构建后校验 `com.presencekit.mobile`，并将 APK 上传为 Actions artifact。它仍不会自动把 APK 挂到 GitHub Release，正式 Release 的 APK 附件仍需按发行指南手动上传。该 workflow 支持 tag push 和 `workflow_dispatch`，可用已存在的 v1 tag 重跑。

仍需补充或保留为发布前人工验收的范围：

- Android instrumented test：通知闸门、无障碍过滤、悬浮窗确认、设备管理器锁屏、Keystore 迁移与安装后恢复；
- 后台 relay 在 Doze、进程被杀、设备重启、网络断开/恢复时的真机矩阵；
- 前台 poll 与后台服务交接瞬间的场景化测试；
- 正式签名包的安装、同包升级、替换/删除凭据和失败回滚；
- `/mobile/chat`、poll/ack 与后端、桌面端固定 commit 的跨仓协议兼容测试。

## Inline typography validation (2026-09-09)

Flutter analyze --no-pub passed with zero issues. Focused widget/controller/protocol tests passed (67 tests), including style ratios/accent, grapheme reveal, paragraph slicing, malformed-copy fallback, HTTP/poll dedup, catch-up/ack and existing upload/sticker paths. Backend focused delivery tests passed (48 tests). Dev debug APK is built with the existing dev flavor; no production signing/version/release changes or device installation are part of this task. Physical-device visual verification remains pending.

## 聊天时间与自动补传修复（2026-09-11）

- `flutter gen-l10n`、`flutter analyze --no-pub` 通过；全量 Flutter 测试 154 项通过。新增场景覆盖保存撞上同步忙、缓存读取失败仍触发上传。
- Android `:app:testDevDebugUnitTest --tests com.presencekit.mobile.LifeRecordsTest` 19 项通过，覆盖多条/连续校正一次补传、断网后相同请求自动重试、仅前台模式恢复、后台停止后保留剩余队列；Java 21 运行。
- 真机正式版 1.0.1+37 的 3 条记录未上传，观测确认后端 enabled=false。经用户授权，只通过管理面 API 将 enabled 改为 true，保留其他三项设置，GET 回读 effective=true；两张图片收到回执；剩余一次修改冲突仍保留，两次识别任务均 failed / ValidationError，未冒充识别成功。

- 正式包 `1.0.1+38` 构建成功；已核对历史 keystore 与手机已安装 APK、候选 APK 的 certificate SHA-256 一致，`adb install -r` 覆盖成功，侧栏显示 1.0.1+38。原设置、连接、头像、背景与记录队列保留。未对外发布。
- 真机验证“设置 → 外观与显示 → 显示聊天时间”：中文可见、关闭后消息时间隐藏、强停重启仍关闭、重新开启后恢复显示；验收后恢复默认开启。
- 最后重新生成本地化后，相关本地化/通道测试 41 项通过。断网连续重试与后台取消有 Android 自动测试；真实 Doze/断网恢复/新图保存即传矩阵未完成，不能用这次旧包补传证明新包所有后台场景。


## 按需截图三端接入（2026-09-12，partial）

详见仓库 `docs/screen-observation-2026-09-12.md`。后端 `observe_user_screen` 通过独立 HTTP poll/result 请求活跃电脑或手机的新截图，UUID/凭据绑定、20 秒 TTL、30 秒设备新鲜度和本地授权均参与门控；图像只在内存中处理。

管理面提供全局开关、effective state 与 `/perception/screen/status` 无正文观测；电脑视觉观察页、手机系统配置页各有独立本地授权，默认关闭。全局开启时自主工具继承启用，显式工具禁用优先；角色消息继续走原通知/免打扰链路。桌面 IPC 新增可选 onDemandEnabled；手机使用专用 screen_observation 通道与无障碍 worker，不改 mobile poll/ack/relay。

实现及构建/定向测试通过，真实双设备、锁屏、OEM 后台及 VLM/消息联合验收保持 open。管理面既有国际化测试 3 项失败保持 open，详见施工记录，不能将静态检查作为真实设备验收。
