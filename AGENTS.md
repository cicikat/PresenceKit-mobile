# AGENTS.md - PresenceKit-mobile 工作入口

> 每次开始任务前先读。本文档描述 PresenceKit-mobile 仓库（本文件所在目录即仓库根，可整体改名/移盘）的真实边界、当前实现和文档入口。

## ⚠ 禁止照抄的参考目录

`docs/reference/desktop-jsx/`（app.jsx / chrome.jsx / design-canvas.jsx 等）是**桌面端 React/JSX 设计稿**，仅作视觉参考。

- 不属于本 Flutter 项目的源代码
- 禁止把其中的组件结构、状态管理或任何实现逻辑复制到 `lib/` 或 `android/`
- 全仓代码检索时请明确排除该目录（`--glob '!docs/reference/**'`）

## 项目定位

`PresenceKit-mobile` 是陪伴系统的 Flutter 手机薄客户端。核心人格、记忆、调度、主动触发、花园和日记数据仍在后端仓库 `Emerald-presence`（通常与本仓库同级）；本仓库负责移动端 UI、Android 原生能力和 mobile channel 消息收发。

当前实际状态：

- Flutter 主界面已经实现主对话、资料、日记、花园、能力检查、后端节点设置和主题编辑。
- `lib/main.dart` 已完成重构，现在只有约 164 行入口代码；之前提到的 8k+ 行已拆分完毕。
- `lib/pages/app_shell.dart` 当前约 1499 行，已迁出连接、聊天、设备、Dream、Garden、Diary 的领域状态与 Timer；仍保留组合根、路由以及 profile/theme/capability/settings 等 UI 协调。结构债状态见 `cc-tasks/07-app_shell结构债审计与拆分.md`。
- `lib/pages/chat_page.dart`、`lib/widgets/api_service.dart`、`lib/services/message_bubble.dart` **已废弃/不再使用**，上述路径已不存在或为空壳。
- 主对话发送消息与 Emerald-client 桌面端一致，走 `POST /desktop/chat`；聊天历史只读 `/chat-log/*`。
- Dream 是独立页面和消息流，走 `GET /dream/state`、`POST /dream/enter|chat|exit`。
- 主动消息前台走 `GET /mobile/poll` 每 5 秒轮询；后台由 Android `MobileNotificationService` 订阅 ntfy SSE signal，并在中继断线时用 `AlarmManager` 做非阻塞 poll 补偿。
- Android 原生侧负责通知、前台服务、悬浮窗、无障碍屏幕上下文、设备管理器锁屏和文件/图片选择。
- 多端 sensor 协议草案已归档到 `docs/protocols/sensor-event-protocol.md`。
- 鉴权已从单一 admin secret 升级为 scoped token（SEC-AUTH-2）：本 app 应使用后端签发的
  `mobile` profile token（`emt_` 开头，scope 不含 hardware/admin），旧 admin secret 仍等价
  admin scope 可继续用但不建议；401=token 无效，403=scope 不足，429=认证失败限流。详见
  `docs/backend/integration.md` 鉴权节。

不在本项目范围内的事：

- 不修改后端仓库 `Emerald-presence`，除非用户明确把后端也纳入任务。
- 不修改 `Emerald-client`，它只是桌面客户端和文档组织参考。
- 不把手机端变成记忆或人格的 single source of truth。

## 代码根目录

本文件所在目录即仓库根。所有路径一律相对仓库根书写，不依赖盘符或上级目录名。

## 必读文档

| 任务类型 | 必读文档 |
|---|---|
| 理解项目全貌 | `ARCHITECTURE.md` |
| 找文档入口 | `docs/README.md` |
| 改 Flutter UI / 状态 | `docs/mobile/flutter-structure.md` |
| 改 Android 原生能力 | `docs/android/native-capabilities.md` |
| 改后端接口 / mobile channel | `docs/backend/integration.md` |
| 改 sensor / 多端协议 | `docs/protocols/sensor-event-protocol.md` |
| 查风险和技术债 | `docs/known-issues.md` |
| 跑构建、测试、安装 | `docs/quality/testing-and-dev.md` |

## 当前目录结构

```text
lib/
  main.dart                         # 薄入口、根 MaterialApp；part 已移除
  models/app_models.dart            # 数据模型（BackendChatResponse 等）
  controllers/                      # connection/chat/device/dream/garden/diary 领域控制器
  pages/app_shell.dart              # 组合根/路由/生命周期协调，禁止继续增加领域状态
  services/backend_client.dart      # 所有 HTTP 封装，约 507 行
  services/app_settings_store.dart  # legacy MethodChannel 兼容实现
  services/platform_settings_channel.dart # 共享 presence_mobile/settings 通道
  services/device_services.dart      # 五个设备域门面
  widgets/capability_widgets.dart   # 能力检查页
  widgets/chat_widgets.dart
  widgets/common_widgets.dart
  widgets/diary_widgets.dart
  widgets/dream_widgets.dart
  widgets/drawer_widgets.dart
  widgets/garden_widgets.dart
  widgets/profile_widgets.dart
  widgets/settings_editor_widgets.dart
  widgets/settings_widgets.dart
android/app/src/main/
  AndroidManifest.xml
  kotlin/com/presencekit/mobile/
    MainActivity.kt                 # MethodChannel、权限、文件选择、服务入口
    BackendSecurityPolicy.kt       # 后端/中继 origin 安全校验
    SensorAccess.kt                 # 电量、步数和录音能力
    MobileNotificationService.kt    # 后台中继 signal/poll 补偿和通知闸门
    FloatingBubbleService.kt        # 悬浮窗、锁屏确认、订单确认
    YexuanAccessibilityService.kt   # 屏幕上下文采集、购物车辅助点击
    YexuanDeviceAdminReceiver.kt    # 设备管理器锁屏 receiver
docs/
  README.md
  known-issues.md
  overview/
  mobile/
  android/
  backend/
  protocols/
  quality/
```

## 后端连接信息

- 后端项目：`Emerald-presence` 仓库（通常与本仓库同级）
- 默认节点：`http://127.0.0.1:8080`
- 插线调试：`adb reverse tcp:8080 tcp:8080`
- 主对话发消息：`POST /desktop/chat`
- Dream：`GET /dream/state`、`POST /dream/enter`、`POST /dream/chat`、`POST /dream/exit`
- 主动消息：`POST /mobile/activate`、`GET /mobile/poll`
- 花园：`GET /garden/state`
- 日记：`GET /diary/list`、`GET /diary/{date}`
- 聊天日志：`GET /chat-log/dates`、`GET /chat-log/{date}`
- 屏幕上下文：`POST /sensor/realtime`
- 主动行为状态：`GET /sensor/behavior/status`

## 强制规则

1. 后端仍是业务真值。手机端只展示、输入、上报客观上下文和执行用户确认后的本机动作。
2. 涉及锁屏、悬浮窗、无障碍辅助点击、截图/OCR/支付等高风险能力时，必须保留明确授权和确认。
3. 屏幕上下文默认按实时/短期上下文处理，不要在手机端主动写长期记忆。
4. 改 `MethodChannel('presence_mobile/settings')` 或 legacy `SharedPreferences('yexuan_memery')` 时，Dart 的 `AppSettingsStore`、`PlatformSettingsChannel` 和 Android `MainActivity.kt` 必须同步；`yexuan_memery` 是历史存储名，不是当前 channel 名。
5. 改 mobile channel 字段时，同时更新 `docs/backend/integration.md` 和 `docs/protocols/mobile-channel.md`。
6. 改 Android 权限、前台服务或无障碍行为时，同步更新 `docs/android/native-capabilities.md`。
7. 发现未修问题先记到 `docs/known-issues.md`，标明影响、证据和建议方向。
8. 新领域功能必须新建 `lib/controllers/<domain>_controller.dart` 和对应 widget 文件；禁止向
   `lib/pages/app_shell.dart` 增加领域状态字段、Timer 或成组业务方法。跨域依赖通过构造注入，
   `app_shell.dart` 最终只保留组合根、路由和生命周期协调。

## 启动与调试

```powershell
# 插线调试后端转发（adb 路径见 android/local.properties 的 sdk.dir，或直接用 PATH 里的 adb）
adb reverse tcp:8080 tcp:8080

# Flutter 分析
flutter analyze

# Flutter 测试
flutter test

# Debug APK
flutter build apk --debug
```

若 `flutter`/`adb` 不在 PATH：SDK 位置以 `android/local.properties` 里的 `flutter.sdk` 和 `sdk.dir` 为准（机器本地文件，不入库）。根目录的 `mobile_dev_control.bat` 和 `AA1打包安装到手机.bat` 会自动按 local.properties → 环境变量 → PATH 的顺序探测，无需改脚本。

## Codex 施工协作约定（与 `CLAUDE.md` 同步）

1. **用中文回复。**
2. **默认自主推进、替用户拍板**，不要逐项确认；只在不可逆决策（删数据、改契约、对外发布）时提问。
3. **不要全仓 grep**，先按 AGENTS.md / 架构文档定位到具体文件再精准搜索。
4. **交付物一次性批量输出**，多个工单/提示词要标注哪些可并行、哪些有前置依赖，减少一来一回。
5. **小步 commit，无需确认**：每完成一个独立修复并验收通过（测试过/验证过）就直接 `git add` + `git commit`（信息一行即可），不必等我说"commit一下"、不要为此专门提问确认。当场固化，不留过夜、不攒大坨。这是预先授权，覆盖"仅在用户明确要求时才 commit"的默认行为。
