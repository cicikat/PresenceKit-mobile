# Android 原生能力

## v1 credential storage

`SharedPreferences("yexuan_memery")` is the compatibility name and must not be renamed. It still holds ordinary settings: backend URL, owner ID, relay URL/topic, language, and notification settings. `adminToken` (access token) and `relayToken` are sensitive and are no longer retained as plaintext there.

`AndroidKeystoreCredentialStore` encrypts values in private app preferences using a non-exportable Android Keystore key (AES-GCM on Android 6.0+, Android Keystore RSA compatibility on older supported versions). Its migration state machine is: secure value wins and removes redundant legacy plaintext; otherwise legacy is written securely and cleared only after a committed write; a failed secure write preserves the legacy value. Replacement and deletion also operate on secure storage first. Generic MethodChannel failures never include the token value. Both Flutter foreground calls and `MobileNotificationService` use this same path, so an upgraded installation keeps working without re-entering its token.

Android 原生层位于 `android/app/src/main/kotlin/com/presencekit/mobile/`。

## MainActivity.kt

职责：

- 注册兼容旧安装契约的 `MethodChannel('presence_mobile/settings')`；Dart 侧通过 `PlatformSettingsChannel` 共享该通道。`yexuan_memery` 仅是历史 `SharedPreferences` 存储名，不是当前 channel 名。
- 读写兼容键 `SharedPreferences("yexuan_memery")`：后端节点、owner id、可信私网 HTTP origin、屏幕上下文上传开关、主题、备注名、后台通知开关、头像和 Flutter 语言偏好。admin/relay token 不再作为明文保存在这些键中，而由 `BackendSecurityPolicy` 委托 `AndroidKeystoreCredentialStore` 管理；语言通过 `getAppLanguage` / `setAppLanguage` 读写 `appLanguage`，只接受 `system`、`zh-CN`、`en-US`。该存储名有意不随项目改名。
- 检查通知、悬浮窗、设备管理器、无障碍权限；通知权限只在能力检查页显式请求，或用户首次开启后台通知时请求。
- 检查并引导用户授予电池优化豁免；能力页同时提供常见 OEM 自启动/后台白名单路径。
- 启动/停止 `MobileNotificationService` 和 `FloatingBubbleService`。
- 处理图片、单文件、多图片选择。
- 打开美团/淘宝，并向无障碍服务发起短窗口购物车请求。

生命周期：

- `onCreate()` 只进入沉浸式全屏，不主动弹通知权限；权限请求由能力检查页或后台通知开关触发。
- `onResume()` 无条件停止原生服务和中继订阅，由 Flutter 前台每 5 秒轮询。通知点击会以一次性
  `pendingOpenLatestMessage` 标记传给 Flutter；Flutter 在凭证恢复后消费它，完成 catch-up 并定位最新消息。
- `onStop()` 只有在后台通知开关开启、访问凭证存在且后端 origin 可信时，才启动后台前台服务。
- `isBackgroundNotificationServiceRunning` 直接读取 `MobileNotificationService.isServiceRunning`
  的进程内生命周期真值，不再用 SharedPreferences 历史标记判断服务是否仍在运行。

## Dart 设备门面与 MethodChannel 边界

Flutter 不在页面中直接调用平台通道：`SettingsStore`、`VoiceService`、`DeviceControlService`、`ScreenSensorService`、`RelayStatusService` 五个门面统一包装 `AppSettingsStore`，由 `ConnectionController` 和 `DeviceController` 注入使用。`AppSettingsStore` 仍保留全部 legacy 方法作为兼容实现，后续新增能力应先落到对应门面。

## BackendSecurityPolicy.kt 与 SensorAccess.kt

- `BackendSecurityPolicy` 负责 HTTPS/loopback/Tailscale/RFC1918 origin 与 relay URL 校验，拒绝公网明文和自动重定向绕过。
- `SensorAccess` 负责电量、步数和录音能力的 Android 读取；Flutter `DeviceController` 以 30 分钟周期上报电量/步数，不把屏幕正文写入长期记忆。

## MobileNotificationService.kt

职责：

- 作为前台服务在应用后台保持 ntfy SSE 中继订阅；应用回前台时停止。
- 中继未配置时只执行一次非阻塞补偿拉取后退出；订阅失败或连续断线 1 分钟后，通过
  `AlarmManager` 安排非阻塞补偿拉取，之后每 15 分钟一次。SSE 保持连接时也每 15 分钟执行一次
  受鉴权安全 poll，限制单个 relay signal 丢失造成的 durable queue 延迟；应用回前台后取消。
- 中继收到 signal-only payload 时立即请求 `/mobile/poll?limit=20&after=<lastAckedSeq>` 拉取正文；
  旧式含 `content` payload 也会忽略正文并强制回源。连续 signal 会合并为串行 poll，不直接投递空消息。
- 屏幕上下文上传开关开启时，每次周期补偿前将原生层过滤后的快照推送到 `/sensor/realtime`。
- 周期补偿调用 `/mobile/activate` 后请求 `/mobile/poll?limit=20&after=<lastAckedSeq>`，不使用
  `wait=55` 常驻长轮询；消费并持久化 `seenMobileMessageIds` 后调用 `/mobile/ack`，ack 成功后才推进共享游标。
- 中继与轮询共用 generation 裁决和同一条 `message.id` 去重、behavior、通知闸门消费管线；
  中继接管时会打断在途轮询并丢弃旧 generation 结果，避免双重弹出。
- 根据 behavior metadata 决定悬浮窗或普通通知。
- 普通通知受静音时段和 30 分钟冷却控制。
- 普通通知标题使用 `cachedCharacterDisplayName`（Flutter 侧 `resolveCharacterDisplayName()` 的结果，
  由 `AppSettingsStore.cacheCharacterDisplayName()` 经 `MethodChannel` 写入，取不到时回退中性占位），
  不再固定显示应用名；API 28+ 用 `Notification.MessagingStyle` 让头像出现在左侧、更贴近聊天气泡观感，
  头像直接读 `MainActivity.avatarFile()`（`filesDir/profile_avatar.png`，Service 与 Activity 共享同一
  `filesDir`，无需额外传值）；低于 API 28 退回 `BigTextStyle` + `setLargeIcon()`，头像仍显示但在右侧。
- 弹窗正文只显示 `content` 按 `\n+` 切出的第一段（对齐桌面端"一段一个气泡"的切法），超过 25 字
  截断并加"…"（两行 × 15 字算下来是 30，但实测 30 会挤成三行，留了余量压到 25）；展开态也是同一份
  裁过的文本，不会露出完整多段回复。已静默收取的条数不再拼进这条弹窗，能力检查页和常驻前台状态栏
  已经展示。
- 能力检查页展示被静音/冷却拦截的累计计数和最近原因；测试模式默认关闭，开启时只绕过静音与冷却闸门，不改变消息消费逻辑。

注意：

- 服务每轮轮询前通过 `BackendSecurityPolicy.adminToken()` 读取访问凭证；缺失时停止服务。该策略优先使用 Android Keystore，并对旧 `SharedPreferences` token 执行安全迁移。
- 服务每轮请求前校验后端 origin；不可信 HTTP 不会建立连接，也不会发送凭证。
- 中继订阅使用独立的 `relayBaseUrl`、`relayTopic`、`relayToken`，复用 origin 信任策略，
  通过 `/<topic>/sse` 接收 ntfy 事件。
- 服务关闭自动重定向；`3xx` 不会绕过 origin 校验。
- 中继重连从 1 秒开始指数退避，最长 60 秒，成功后重置；SSE 90 秒无心跳会触发重连。
- 服务单写 `lastBackgroundPollAt`、`lastBackgroundError`、中继连接状态、最近中继心跳和最近信号时间；
  能力检查页只读展示。
- `seenMobileMessageIds` 是上述单写约定的有意例外：服务在 `consumeMobileMessage()` 写，Flutter
  在 `_pollMobile()` 经 MethodChannel 写，依赖前后台时序互斥；这不是 bug。未来可选统一为
  MethodChannel 合并写，当前不据此重构。
- `lastAckedSeq` 同样由 Flutter 前台与后台服务共用，依赖同一前后台时序互斥；双方只做单调递增写入，
  且严格遵守“先持久化消息去重记录，再 ack，最后持久化游标”。
- 当前 `specialUse` 前台服务不受 Android 15 `dataSync` 配额限制。`onTimeout` 仅作为防御路径保留：
  若未来 manifest 错误改回受限类型，会使中继和轮询 generation 失效、断开连接并安排恢复轮询。

## FloatingBubbleService.kt

职责：

- 用 `TYPE_APPLICATION_OVERLAY` 显示可拖动浮窗。
- 模式包括普通短句、锁屏确认、外卖/购物确认、手机自动化任务确认（`control`）。
- 锁屏模式只有用户点击确认后才调用 `DevicePolicyManager.lockNow()`。
- 购物模式会打开目标 App，并请求无障碍服务寻找“购物车”。
- `control` 模式展示任务描述，用户点“开始”后调用 `PhoneControlService.start()` 转交循环协调服务并关闭浮窗；点“取消”只关闭浮窗，不触发任何操作。

安全边界：

- 不自动支付。
- 不自动提交订单。
- 不自动确认收货。
- 不读取截图或 OCR（`control` 模式的截屏/读屏由 `YexuanAccessibilityService` 采集，见下）。
- `control` 任务必须用户在浮窗上点击“开始”才会转交 `PhoneControlService`；不会自动开始执行。

## YexuanAccessibilityService.kt

职责：

- 采集当前 `packageName`、`appLabel`、`className`、`windowTitle`、`visibleText`、`clickableText`。
- 在短窗口内查找“购物车”节点并点击节点或可点击父节点。
- 无障碍事件只记录脏标记和包名；不在事件回调中遍历节点树。
- 屏幕上下文仅在上传或能力页调试请求时按需采集，统一投递到服务 Handler 串行执行；5 秒内复用上一份完整快照。
- 手机自动化（phone_control）通用观察/执行原语，供 `PhoneControlService` 调用（companion object 公开
  静态方法，内部通过 `Handler.post` + `CountDownLatch` 从后台线程同步等待主线程结果）：
  - `capturePhoneControlObservation()`：采集当前 `packageName`/`screenTitle`/可操作节点树（最多
    120 个、深度 14，仅含可见且可点击/可编辑/可滚动/可聚焦、且有文本或辅助描述的节点）、屏幕分辨率，
    以及 API 30+ 的 `takeScreenshot()` JPEG（Base64），低版本或截屏失败时截图字段为 `null`。
  - `performTapAtRatio(xRatio, yRatio)` / `performTypeAtRatio(xRatio, yRatio, text)` /
    `performScroll(direction)`：按归一化比例坐标执行点击/输入/滚动，`dispatchGesture` 回调链路
    经过重构避免主线程自等待死锁（详见类内注释）。
  - `isSensitiveObservation(packageName, texts)`：复用被动屏幕采集已有的敏感包名/App 名/文案关键词表，
    供 `PhoneControlService` 做本地二次拦截，与后端 `sensitive_filter.py` 各自独立判断。

隐私边界：

- 当前采集的是可见文本和可点击文本摘要。
- 原生采集层先过滤密码输入框、验证码/校验码/动态码/密码关键词，银行卡/转账/支付、病历/处方/挂号/医保/诊断等页级关键词，以及支付宝、微信、云闪付、银行、医疗/健康/挂号类应用或包名。
- 被过滤页面只保留 `isBlocked` 和 `blockedReason`；不保留标题、正文、包名或 App 名。
- 独立上传开关 `screenContextUploadEnabled` 默认关闭。关闭时前台定时上传、后台轮询前上传和手动推送均禁止，原生上传采集入口也不会遍历节点树；能力页调试入口单独放行，仍可查看过滤后的本机快照。
- 2026-07 移除了按 App 的文本上传白名单（`screenTextUploadAllowedPackages` 及配套 UI/MethodChannel/Dart 门面已全部删除）。`screenContextUploadEnabled` 开启后即上传完整窗口标题/可见正文/可点击正文，唯一闸是这一个主开关；敏感 App、密码节点和页级敏感关键词三道内容拦截不受影响，仍然独立生效。

## PhoneControlService.kt

手机自动化（"computer use 手机版"）循环协调服务，协议契约见
`docs/protocols/phone-control-protocol.md`。由 `FloatingBubbleService` 的 `control` 模式浮窗在用户
点击"开始"后通过 `PhoneControlService.start(context, taskId, task)` 启动，`specialUse` 前台服务。

循环（每步）：

1. `YexuanAccessibilityService.capturePhoneControlObservation()` 采集观察（包名/标题/节点树/截图）。
2. 本地 `isSensitiveObservation()` 先过一遍——命中即以 `need_confirmation` 结束循环，不发请求。
3. `POST /phone_control/step` 上报观察 + 上一步动作/结果，取回下一步动作。
4. `status=continue`：动作再过一次本地敏感词校验（`isSensitiveAction()`，检查 `text` 字段），
   命中同样直接结束；未命中则按 `action.type`（`tap`/`type`/`scroll`）执行，
   `target_node_id` 优先从当轮观察的节点坐标换算比例，取不到才退化到 `target_point`。
5. `status=done/need_confirmation/refused`，或步数超过 20，或收到取消，循环结束。

安全边界（与后端 `sensitive_filter.py` 相互独立，任一方拦截即停，不是"后端说了算"）：

- 命中敏感页面（观察侧或动作侧）一律停到 `need_confirmation`，从不自动点击确认/支付/提交类按钮——
  这类按钮本身也会被关键词表命中。
- 一次只允许一个任务在跑；新任务到来时若已有任务在运行，直接丢弃，不排队、不打断。
- 前台常驻通知带"取消"按钮（`BroadcastReceiver` 监听 `ACTION_CANCEL`，按 `task_id` 匹配），随时可中断；
  循环结束（无论何种终态）都会发一条独立的结果通知，并停止前台服务。
- 步数上限（20）、单步间隔（600ms）均为客户端本地节流，与后端 `task_state.py` 的步数/超时上限各自独立。

## Manifest 权限

`AndroidManifest.xml` 当前声明：

- `INTERNET`
- `POST_NOTIFICATIONS`
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_DATA_SYNC`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
- `SYSTEM_ALERT_WINDOW`
- Accessibility service
- Device admin receiver

`android:usesCleartextTraffic="true"` 仍用于本机/LAN HTTP 调试，但应用层会在 Flutter 和 Android 后台服务建立请求前校验 origin，并关闭自动重定向。允许 loopback、Tailscale `100.64.0.0/10`、HTTPS，以及用户明确确认过的 RFC1918 私网精确 IPv4 或 Tailscale MagicDNS `*.ts.net` HTTP origin；公网 HTTP 会直接拒绝。
