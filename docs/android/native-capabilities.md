# Android 原生能力

Android 原生层位于 `android/app/src/main/kotlin/com/example/yexuan_memery/`。

## MainActivity.kt

职责：

- 注册 legacy `MethodChannel('yexuan_memery/settings')`。
- 读写 legacy `SharedPreferences("yexuan_memery")`：后端节点、访问凭证、可信私网 HTTP origin、屏幕上下文上传开关、主题、备注名、后台通知开关、头像。
- 请求和检查通知、悬浮窗、设备管理器、无障碍权限。
- 检查并引导用户授予电池优化豁免；能力页同时提供常见 OEM 自启动/后台白名单路径。
- 启动/停止 `MobileNotificationService` 和 `FloatingBubbleService`。
- 处理图片、单文件、多图片选择。
- 打开美团/淘宝，并向无障碍服务发起短窗口购物车请求。

生命周期：

- `onCreate()` 请求通知权限并进入沉浸式全屏。
- `onResume()` 无条件停止原生服务和中继订阅，由 Flutter 前台每 5 秒轮询。
- `onStop()` 只有在后台通知开关开启、访问凭证存在且后端 origin 可信时，才启动后台前台服务。

## MobileNotificationService.kt

职责：

- 作为前台服务在应用后台保持 ntfy SSE 中继订阅；应用回前台时停止。
- 中继未配置时只执行一次非阻塞补偿拉取后退出；订阅失败或连续断线 15 分钟后，通过
  `AlarmManager` 安排非阻塞补偿拉取，之后最多每 6 小时一次，中继恢复后取消。
- 中继收到 signal-only payload 时立即请求 `/mobile/poll?limit=20&after=<lastAckedSeq>` 拉取正文；
  旧式含 `content` payload 也会忽略正文并强制回源。连续 signal 会合并为串行 poll，不直接投递空消息。
- 屏幕上下文上传开关开启时，每次周期补偿前将原生层过滤后的快照推送到 `/sensor/realtime`。
- 周期补偿调用 `/mobile/activate` 后请求 `/mobile/poll?limit=20&after=<lastAckedSeq>`，不再使用
  `wait=55`；消费并持久化 `seenMobileMessageIds` 后调用 `/mobile/ack`，ack 成功后才推进共享游标。
- 中继与轮询共用 generation 裁决和同一条 `message.id` 去重、behavior、通知闸门消费管线；
  中继接管时会打断在途轮询并丢弃旧 generation 结果，避免双重弹出。
- 根据 behavior metadata 决定悬浮窗或普通通知。
- 普通通知受静音时段和 30 分钟冷却控制。
- 能力检查页展示被静音/冷却拦截的累计计数和最近原因；测试模式默认关闭，开启时只绕过静音与冷却闸门，不改变消息消费逻辑。

注意：

- 服务每轮轮询前从 legacy `SharedPreferences("yexuan_memery", MODE_PRIVATE)` 重新读取访问凭证；缺失时停止服务。当前尚未接入 Android Keystore。
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
- 模式包括普通短句、锁屏确认、外卖/购物确认。
- 锁屏模式只有用户点击确认后才调用 `DevicePolicyManager.lockNow()`。
- 购物模式会打开目标 App，并请求无障碍服务寻找“购物车”。

安全边界：

- 不自动支付。
- 不自动提交订单。
- 不自动确认收货。
- 不读取截图或 OCR。

## YexuanAccessibilityService.kt

职责：

- 采集当前 `packageName`、`appLabel`、`className`、`windowTitle`、`visibleText`、`clickableText`。
- 在短窗口内查找“购物车”节点并点击节点或可点击父节点。
- 无障碍事件只记录脏标记和包名；不在事件回调中遍历节点树。
- 屏幕上下文仅在上传或能力页调试请求时按需采集，统一投递到服务 Handler 串行执行；5 秒内复用上一份完整快照。

隐私边界：

- 当前采集的是可见文本和可点击文本摘要。
- 原生采集层先过滤密码输入框、验证码/校验码/动态码/密码关键词，银行卡/转账/支付、病历/处方/挂号/医保/诊断等页级关键词，以及支付宝、微信、云闪付、银行、医疗/健康/挂号类应用或包名。
- 被过滤页面只保留 `isBlocked` 和 `blockedReason`；不保留标题、正文、包名或 App 名。
- 独立上传开关 `screenContextUploadEnabled` 默认关闭。关闭时前台定时上传、后台轮询前上传和手动推送均禁止，原生上传采集入口也不会遍历节点树；能力页调试入口单独放行，仍可查看过滤后的本机快照。
- 屏幕正文上传使用默认空的 App 白名单 `screenTextUploadAllowedPackages`。未勾选的 App 只上报包名和 App 名，不采集或上传窗口标题、可见正文、可点击正文。
- 白名单 App 仍需经过原有敏感 App、密码节点和页级敏感关键词二次拦截；加入白名单不代表支付、医疗等敏感页面可上传。

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

`android:usesCleartextTraffic="true"` 仍用于本机/LAN HTTP 调试，但应用层会在 Flutter 和 Android 后台服务建立请求前校验 origin，并关闭自动重定向。允许 loopback、Tailscale `100.64.0.0/10`、HTTPS，以及用户明确确认过的 RFC1918 私网精确 IPv4 HTTP origin；公网 HTTP 会直接拒绝。
