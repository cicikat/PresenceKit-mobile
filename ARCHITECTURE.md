# ARCHITECTURE.md - Emerald-mobile 架构总览

`Emerald-mobile` 是陪伴系统的 Android 优先移动客户端。它连接 Emerald-presence（旧名 qq-st-bot）后端，提供手机聊天、后台主动消息、屏幕上下文上报、悬浮提醒和用户确认后的本机动作。

## 系统边界

```text
┌──────────────────────────────┐
│ Emerald-presence（旧名 qq-st-bot）│
│ 人格 / 记忆 / 调度 / 行为裁决 │
│ HTTP mobile + sensor APIs    │
└──────────────┬───────────────┘
               │ HTTP on 127.0.0.1:8080 or LAN IP
               ▼
┌──────────────────────────────┐
│ Emerald-mobile Flutter        │
│ 主对话 / 资料 / 日记 / 花园    │
│ 前台主动消息轮询 / 能力检查 / 设置 │
└──────────────┬───────────────┘
               │ MethodChannel presence_mobile/settings
               │ SharedPreferences yexuan_memery (legacy storage)
               ▼
┌──────────────────────────────┐
│ Android native layer          │
│ 通知 / 前台服务 / 悬浮窗        │
│ 无障碍上下文 / 锁屏确认         │
└──────────────────────────────┘
```

原则：后端做判断，手机端做展示和本机能力执行。手机端可以上报“当前 App、可见文字、可点文字”等客观事实，但不直接扮演角色、不直接决定主动行为规则。

## 当前实现快照

Flutter 入口 `lib/main.dart` 约 164 行：

- `main()` 设置沉浸式系统 UI 后挂载 `MyApp`。
- `MyApp` 使用 Material 3 和 serif 风格主题，首页是 `CompanionApp`。
- `main.dart` 是薄入口，声明全局错误兜底和根 MaterialApp；历史 `part` 挂载已移除。
- `pages/app_shell.dart` 中的 `CompanionApp` 负责组合根、路由和生命周期；连接、聊天、设备、Dream、花园、日记状态由 `controllers/` 持有。
- `services/platform_settings_channel.dart` 持有 `MethodChannel('presence_mobile/settings')`；`services/app_settings_store.dart` 是兼容实现，五个设备门面负责按域调用。
- `services/backend_client.dart` 直接用 `dart:io` `HttpClient` 调后端 HTTP。
- `models/` 保存数据/config 定义，`widgets/` 按聊天、能力、设置、日记、花园等领域保存 Flutter UI。

Dart `part` 结构已移除，models/services/controllers/pages/widgets 通过普通 import 建立独立 library 边界。controller 与设备门面已接入，剩余 UI 协调结构债见工单 07。

Android 原生入口是 `MainActivity.kt`：

- 当前 Android namespace/applicationId 为 `com.presencekit.mobile`，Dart package 为
  `presencekit_mobile`。Kotlin 源码位于 `android/app/src/main/kotlin/com/presencekit/mobile/`。
- `presence_mobile/settings` MethodChannel 与 `SharedPreferences("yexuan_memery")` 仅作为历史兼容契约；前者是当前 channel 名，后者是历史存储名
  契约保留，不代表当前项目名；未经数据迁移不得改名。

- 持久化后端节点、访问凭证、可信私网 HTTP origin、屏幕上下文上传开关、主题、备注名、头像和后台通知开关到 legacy `SharedPreferences("yexuan_memery")`。
- 提供通知、悬浮窗、设备管理器、无障碍权限检查和跳转。
- 提供图片/文件选择、头像保存、屏幕上下文采集和打开购物 App。
- `onStop()` 仅在后台通知开启、访问凭证存在且 origin 可信时启动 `MobileNotificationService`；
  `onResume()` 无条件停止原生服务和中继订阅。

后台主动消息由 `MobileNotificationService.kt` 负责：

- 启动前台服务通知。
- 应用后台以 ntfy SSE 为主动消息实时主路径。
- 中继只推送 signal；收到 signal 后立即通过 `/mobile/poll?limit=20&after=<lastAckedSeq>` 拉取正文，
  即使收到旧式含 `content` payload 也忽略正文并强制回源。
- 中继订阅失败或连续断开 15 分钟后，通过 `AlarmManager` 执行一次非阻塞 `/mobile/poll?limit=20&after=<lastAckedSeq>`
  补偿；之后最多每 6 小时一次，中继恢复即取消。
- 收到 mobile channel 消息后优先根据 behavior metadata 映射悬浮窗；否则走普通通知。
- 普通通知受 23:30-06:30 静音和 30 分钟冷却控制。
- `seenMobileMessageIds` 是有意的前后台时序互斥双写：后台服务在 `consumeMobileMessage()` 写，
  Flutter 前台在 `_pollMobile()` 经 MethodChannel 写；这不是 bug。未来可选统一为 MethodChannel
  合并写，当前不据此重构。

悬浮行为由 `FloatingBubbleService.kt` 和 `YexuanAccessibilityService.kt` 配合：

- 悬浮短句：显示可拖动浮窗，可回到聊天。
- 锁屏确认：用户点击确认后才调用设备管理器 `lockNow()`。
- 外卖/购物确认：打开美团/淘宝并请求无障碍服务在短窗口内寻找“购物车”节点。
- 当前不会自动支付、提交订单或确认收货。

## 通信路径

### 用户发消息

```text
Composer
  -> _sendMessage()
  -> BackendClient.sendChat()
  -> POST /desktop/chat
  <- { reply, affection, level, emotion }
  -> _appendHimReplySegments()
  -> ChatScene 渲染消息
```

### Dream 独立对话

```text
DreamPage
  -> GET /dream/state
  -> POST /dream/enter
  -> POST /dream/chat
  -> POST /dream/exit
```

Dream 消息只保留在 Dream 页面当前会话中，不写入主对话消息列表；离开 Dream 页面时会调用退出接口。

### 前台主动消息

```text
Timer 5s
  -> 确认 Android 后台服务未运行
  -> BackendClient.pollMobile()
  -> GET /mobile/poll?limit=20&after=<lastAckedSeq>
  <- [{ content, behavior, ... }]
  -> 追加 him 消息
  -> 不触发系统通知或悬浮窗
```

### 后台主动消息

```text
MainActivity.onStop()
  -> MobileNotificationService
  -> ntfy SSE 实时订阅
  -> 收到 signal 后 GET /mobile/poll?limit=20&after=<lastAckedSeq>
  -> 连续断开 15 分钟后 AlarmManager 周期补偿
  -> POST /sensor/realtime（仅补偿前且独立开关开启、快照非敏感）
  -> GET /mobile/poll?limit=20&after=<lastAckedSeq>（非阻塞）
  -> behavior overlay 或普通系统通知
```

### 屏幕上下文

```text
YexuanAccessibilityService
  -> captureScreenContext()
  -> packageName / appLabel / windowTitle / visibleText / clickableText
  -> 独立上传开关开启且快照非敏感时：
     Flutter 前台每 45 秒 POST /sensor/realtime
     Android 后台周期补偿前 POST /sensor/realtime
```

## 目录职责

| 路径 | 职责 |
|---|---|
| `lib/main.dart` | Flutter 薄入口、根 MaterialApp |
| `lib/pages/app_shell.dart` | 组合根、顶层路由、生命周期和跨域 UI 协调 |
| `lib/models/` | App 数据/config、能力状态和屏幕上下文模型 |
| `lib/services/platform_settings_channel.dart` | 共享 Android `presence_mobile/settings` 通道 |
| `lib/services/app_settings_store.dart` | legacy MethodChannel 方法的兼容实现 |
| `lib/services/device_services.dart` | Settings/Voice/Device/Screen/Relay 五个域门面 |
| `lib/services/backend_client.dart` | 后端 HTTP、上传、mobile channel 和 sensor API |
| `lib/widgets/` | 按领域拆分的页面展示和可复用 Flutter 组件 |
| `android/app/src/main/AndroidManifest.xml` | 权限、Activity、Service、Accessibility、DeviceAdmin 声明 |
| `android/app/src/main/kotlin/.../MainActivity.kt` | MethodChannel 和原生能力入口 |
| `android/app/src/main/kotlin/.../MobileNotificationService.kt` | ntfy SSE、中继断线周期补偿、通知、静音/冷却闸门 |
| `android/app/src/main/kotlin/.../FloatingBubbleService.kt` | 系统悬浮窗 UI 和确认动作 |
| `android/app/src/main/kotlin/.../YexuanAccessibilityService.kt` | 屏幕上下文采集和购物车辅助点击 |
| `docs/` | 项目文档和问题归档 |

## 当前主要风险

- Flutter 已形成独立 library/import 边界；连接、聊天、设备、Dream、Garden、Diary controller 已落地。app shell 仍有 profile/theme/capability/settings UI 协调待继续下沉。
- owner/user id 已可在连接设置中配置；访问凭证和 owner id 仍由 legacy `SharedPreferences("yexuan_memery")` 本机存储，尚未接入 Android Keystore。
- 无障碍敏感过滤已接入，但仍需结合实际安装应用持续扩充包名和页级关键词，并补自动化测试。
- 中继与补偿队列仍依赖后端落实 A1 同 id、补偿 TTL/容量上限和发布失败告警。
- HTTP origin 已限制为 HTTPS、loopback、Tailscale 或用户确认过的 RFC1918 精确 IPv4 origin；前后台请求拒绝自动重定向。
- 外卖/购物悬浮窗仍有硬编码示例订单内容，容易误导真实行为。

完整列表见 `docs/known-issues.md`。

## Controller 与页面状态边界

| Controller | 当前拥有的状态/副作用 | 页面入口 |
|---|---|---|
| `ConnectionController` | backend URL、token、owner id、可信 origin、中继配置、BackendClient 重建 | 节点设置/能力检查 |
| `ChatController` | 历史双源、分页、发送、附件、去重、mobile poll/ack、聊天滚动 | `ChatScene` 直接监听 |
| `DeviceController` | 锁屏/悬浮窗/购物、语音、屏幕上下文、45 秒屏幕与 30 分钟传感器 Timer | 能力检查/输入框 |
| `DreamController` / `GardenController` / `DiaryController` | 各自页面状态与刷新/轮询 | 对应页面直接监听 |
| `ThemeController` | 多颜色预设、旧单色盘迁移、内置 mod、Web 持久化与导出 | 设置页颜色预设管理器 |

`app_shell.dart` 仍是组合根，不得新增领域字段、Timer 或成组业务方法；当前未下沉的 profile、theme、capability/settings、附件和弹窗协调列为工单 07 后续结构债。
