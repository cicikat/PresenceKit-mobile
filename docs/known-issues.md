# 已知问题与技术债

> 修复前请先对照代码确认问题仍存在；修复后在本文件改状态或移到已修复区。

## 已收缩：手机端不再持有 admin 全权 token

**位置**：`lib/services/backend_client.dart`、`android/app/src/main/kotlin/com/example/yexuan_memery/MobileNotificationService.kt`、
`docs/backend/integration.md`

后端 SEC-AUTH-2（`Emerald-presence/cc-tasks/21-鉴权分层-scoped-tokens.md`）落地后，手机端应
换装 `mobile` profile scoped token（`emt_` 开头；scope：chat/state.read/memory.read/activity/
persona/sensor.write，不含 hardware/admin），不再需要旧的全权 admin secret。存储键、
MethodChannel、prefs 结构不变，只是填入的凭证值收敛为最小权限 token；旧 admin secret 仍可用
但不建议。`GET /system/data-path` 需要 admin scope，mobile token 下预期 403，能力检查页已识别
为中性状态而非故障。

**状态**：已修复（手机端侧）。见 `cc-tasks/round-鉴权分层-scoped-tokens-移动端.md`。

## 已修复：Android 后台常驻长轮询

**位置**：`android/app/src/main/kotlin/com/example/yexuan_memery/MobileNotificationService.kt`

Android 后台已改为 ntfy SSE 实时主路径；不再维持 `wait=55` 常驻长轮询。中继明确订阅失败
或连续断开 15 分钟后，通过 `AlarmManager` 执行非阻塞补偿拉取，之后最多每 6 小时一次，
中继恢复即取消。

**状态**：已修复。中继重连仍使用 1-60 秒指数退避；能力检查页展示中继状态、最近信号时间、
最近中继心跳和最近周期补偿。

## 已修复：无障碍屏幕上下文本机敏感过滤

**位置**：`lib/main.dart`、`android/app/src/main/kotlin/com/example/yexuan_memery/YexuanAccessibilityService.kt`、`MobileNotificationService.kt`

原生采集层现在会过滤密码输入框，验证码、银行、支付、医疗类页级关键词，以及敏感 App/包名。屏幕上下文上传使用独立开关 `screenContextUploadEnabled`，默认关闭；正文上传另使用默认空的 App 白名单，未勾选 App 只上报包名/App 名。

**状态**：已修复。过滤页面只保留 `isBlocked` 和 `blockedReason`，不保留标题、正文、包名或 App 名；Flutter 前台和 Android 后台都会跳过上传。

**后续建议**：结合实际安装应用继续扩充包名黑名单，并为过滤策略补充自动化测试。

## 已修复：公网 HTTP 和自动重定向可能绕过 origin 边界

**位置**：`lib/main.dart`、`android/app/src/main/kotlin/com/example/yexuan_memery/BackendSecurityPolicy.kt`、`MobileNotificationService.kt`

自定义明文 origin 现在只允许用户确认过的 RFC1918 私网精确 IPv4；公网 HTTP 即使曾保存过也不会放行。loopback、Tailscale `100.64.0.0/10` 和 HTTPS 仍可使用。

**状态**：已修复。Flutter 前台请求与 Android 后台请求均关闭自动重定向，`3xx` 不会绕过 origin 校验。

## 已修复：鉴权 token 硬编码

**位置**：`lib/main.dart`、`android/app/src/main/kotlin/com/example/yexuan_memery/MobileNotificationService.kt`

访问凭证已从 Flutter 和 Android 原生源码移除。首次启动时由用户手动填写，并保存到 legacy `SharedPreferences("yexuan_memery", MODE_PRIVATE)`；后台服务每轮重新读取。

**状态**：已修复访问凭证硬编码。owner/user id 仍固定为自用配置，未纳入本次最小补丁。

**后续建议**：如需分发，继续把 owner/user id 改成用户配置，并评估 Android Keystore 加密存储。当前尚未接入 Keystore。

## 已修复：`/upload/ingest` 请求未附带 `Authorization` header

**位置**：`lib/main.dart` `BackendClient.uploadFiles()`

`BackendClient.uploadFile(s)` 已增加 token 参数，`/upload/ingest` 请求会设置 `Authorization: Bearer <token>`。

**状态**：已修复。

## P2：外卖/购物悬浮窗仍显示硬编码示例订单

**位置**：`android/app/src/main/kotlin/com/example/yexuan_memery/FloatingBubbleService.kt`

`addOrderContent()` 固定展示“香菇滑鸡饭、白灼时蔬、姜茶、红包、合计 39.00”等示例内容，没有消费后端 behavior 或 message 中的真实建议。

**影响**：真实主动行为触发时，用户可能误以为后端已经完成选品；这与“不自动加购、不自动支付”的安全边界容易混淆。

**建议**：在未接真实购物车/推荐数据前，只显示普通确认文案；不要展示具体商品和价格。

## 已修复：Flutter 主体代码过度集中在 `lib/main.dart`

**位置**：`lib/main.dart` → 已拆分

原 8k+ 行 `main.dart` 已完成拆分：`lib/pages/app_shell.dart`（主状态/页面）、`lib/services/backend_client.dart`（HTTP 封装）、`lib/models/app_models.dart`（数据模型）、`lib/widgets/*.dart`（UI 组件）。现 `main.dart` 仅约 64 行入口。

**状态**：已修复。

## P2：`foreground_mobile_delivery_contract_test.dart` 编译失败（与本次鉴权改动无关）

**位置**：`test/foreground_mobile_delivery_contract_test.dart:94`、
`lib/services/backend_client.dart` `BackendClient.pollMobile()`

`pollMobile()` 已带 `waitSeconds` 具名参数，但该测试文件里的 `_ForegroundBackendClient`
覆写签名缺少这个参数，导致 `invalid_override` 编译错误，使这个测试文件整体加载失败
（`flutter analyze` / `flutter test` 均可见）。发现于施工
`cc-tasks/round-鉴权分层-scoped-tokens-移动端.md` 时跑 `flutter test` 全量回归，与本轮鉴权改动
无关，本轮未修复。

**建议**：给 `_ForegroundBackendClient.pollMobile` 补上 `int waitSeconds = 0` 参数（可忽略取值）
使其匹配基类签名。

## P2：本机 Flutter tester 在加载测试套件前断开

**位置**：`flutter test`

当前环境多次运行 `flutter test` 时，Flutter tester 在执行任何测试用例前报
`HttpException: Connection closed before full header was received`，目标为本机随机
`127.0.0.1` 端口。`flutter analyze` 与 Debug APK 构建均可正常完成。

**影响**：新增 widget test 可以通过静态分析编译，但当前无法在这台机器上实际执行断言。

**建议**：排查本机回环连接、防火墙、安全软件与 Flutter SDK tester 进程；修复后重新运行完整测试。

## 已修复：系统设置内更换 Token 触发 Flutter 路由断言

**位置**：`lib/main.dart` `_openSystemSettings()` / `_openAdminTokenSettings()`

Token 弹窗保存后已经通过父 State 更新 `_adminToken`，系统设置底部页仍额外调用
`sheetSetState()`，导致弹窗关闭与底部页重建叠在同一帧，触发
`_dependents.isEmpty` 断言。现已移除多余刷新，并为原生 Token 保存失败增加弹窗内错误提示。

## 已修复：手机主对话回复双发

**位置**：`lib/main.dart` `_sendToBackend()` / `_pollMobile()`

手机主对话改用 `/desktop/chat` 后，后端同步响应与 mobile channel 可能携带同一条助手回复。手机前台此前会分别追加两次，而桌面客户端已有自己的同步响应 / WebSocket 去重逻辑，因此只有手机出现双发。现已为 Flutter 前台增加 45 秒短时回复指纹去重，同一回复无论先从同步响应还是 `/mobile/poll` 到达，都只显示一次。

## P2：后台服务状态由 SharedPreferences 标记，可能与真实服务状态漂移

**位置**：`MainActivity.kt`、`MobileNotificationService.kt`

能力检查页读取 `backgroundNotificationServiceRunning` 判断后台服务运行状态。这个值由服务启动/销毁和 Activity resume 写入，不是系统进程状态查询。

**当前缓解**：保留运行标记作为近似状态，并在能力检查页展示服务单写的中继心跳、最近周期补偿
和最近错误原因。服务被系统杀掉后，运行标记仍可能短暂漂移。

## P3：Android applicationId 仍是模板包名

**位置**：`android/app/build.gradle.kts`

当前 `namespace` 和 `applicationId` 是 `com.example.yexuan_memery`，文件里也保留 Flutter 模板 TODO。

**影响**：仅适合本机内测；正式分发、权限说明、通知渠道和后续升级都应使用稳定包名。

**建议**：正式打包前统一迁移 applicationId、namespace、签名和渠道名称。

## P3：release 仍使用 debug signing

**位置**：`android/app/build.gradle.kts`

`release` buildType 当前使用 `signingConfigs.getByName("debug")`。

**影响**：只能用于自用内测，不适合发布或长期安装升级。

**建议**：建立私有 release keystore，并把密钥路径/密码放到本机未入库配置。

## P3：通知权限在 Activity 创建时主动弹出

**位置**：`android/app/src/main/kotlin/com/example/yexuan_memery/MainActivity.kt`

`onCreate()` 直接调用 `requestNotificationPermission()`。

**影响**：首次启动时用户可能还没理解后台通知能力，就看到系统权限请求，授权转化和信任感都可能受影响。

**建议**：改成能力检查页或首次开启后台通知时请求。

## P3：设备重启后后台通道不自恢复（R3 复查遗留）

**位置**：`android/app/src/main/AndroidManifest.xml`

无 `RECEIVE_BOOT_COMPLETED` receiver。重启后 relay 服务和 `AlarmManager` 补偿闹钟全部消失，直到用户手动打开 App。

**影响**：重启后整夜收不到主动消息，且无任何提示。

**当前缓解**：能力页已分别显示最近中继心跳和最近周期补偿时间，让重启后的失活可被察觉。

**建议**：自用阶段可接受；要根治则加 boot receiver 重排补偿闹钟。

## 已修复：前台 behavior 路径废弃后的死代码（R3 复查遗留）

**位置**：`lib/services/app_settings_store.dart`、`MainActivity.kt`、`MobileNotificationService.kt` `onTimeout()`

前台改为"忽略 behavior 系统投递语义"后，无调用方的 Dart wrapper 和 MethodChannel handler
已经删除。FGS 改为 `specialUse` 后，`onTimeout()` 不应触发，但它是 Android 平台回调，仍作为未来
manifest 错配时的防御性关闭与恢复路径保留，并已加注释说明。

**状态**：已修复。前台不再暴露 behavior 浮窗投递入口；后台 behavior 映射仍由
`MobileNotificationService` 独占。

## 已修复：relay 全文 content 路径仍保留（R3 复查遗留）

**位置**：`MobileNotificationService.kt` `consumeRelayEvent()`

后端契约已确认并实现 signal-only。Android 现在无论 relay payload 是否意外带 `content`，都忽略
其中正文并强制通过已鉴权 `/mobile/poll` 回源，不再存在 relay 正文直投路径。

**状态**：已修复。中继仍能看到 topic 和信号元数据，但看不到由手机端消费的消息正文或 behavior。
