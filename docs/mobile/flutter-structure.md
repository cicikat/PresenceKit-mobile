# Flutter 结构

## 入口和状态

原 `lib/main.dart` 单文件已拆分完毕，现在只有约 64 行入口代码（`MyApp` + `main()`），通过 `part` 引入以下文件：

| 文件 | 职责 |
|---|---|
| `lib/models/app_models.dart` | 数据模型（`BackendChatResponse`、`GardenState`、`BackendDiagnostics` 等） |
| `lib/pages/app_shell.dart` | 主状态容器 `YexuanCompanionApp`，管理路由、轮询、消息、花园、日记等 |
| `lib/widgets/capability_widgets.dart` | 能力检查页及后端/资产诊断卡片 |
| `lib/widgets/chat_widgets.dart` | 聊天相关 UI 组件 |
| `lib/widgets/common_widgets.dart` | 公共组件（`YxPalette`、`YxPrefs`、`YxTag` 等） |
| `lib/widgets/diary_widgets.dart` | 日记页面组件 |
| `lib/widgets/dream_widgets.dart` | Dream 页面组件 |
| `lib/widgets/drawer_widgets.dart` | 侧边栏组件 |
| `lib/widgets/garden_widgets.dart` | 花园页面组件 |
| `lib/widgets/profile_widgets.dart` | 资料页面组件 |
| `lib/widgets/settings_editor_widgets.dart` | 提示词资产编辑组件 |
| `lib/widgets/settings_widgets.dart` | 通用设置组件 |

独立服务文件（不参与 `part`，普通 import）：

- `lib/services/backend_client.dart`：封装所有后端 HTTP 请求（约 507 行）。
- `lib/services/app_settings_store.dart`：封装 Android MethodChannel 和本地持久化。

主要对象：

- `MyApp`：MaterialApp、主题和首页。
- `AppSettingsStore`：封装 Android MethodChannel。
- `BackendClient`：封装后端 HTTP。
- `YexuanCompanionApp`：主状态容器，管理路由、轮询、消息、花园、日记、后端节点、主题和头像。
- `YxPalette` / `YxPrefs`：主题和偏好。
- `ChatMessage`、`HistoryEntry`、`ChatLogDay`、`GardenState`、`DiaryListItem`、`MobilePollMessage` 等：后端数据模型。
- `BackendDiagnostics` 及子类：能力检查页"后端/资产诊断"卡片所用的只读后端状态快照。

当前路由：

- `AppRoute.chat`：主对话。
- `AppRoute.dream`：Dream 独立对话；使用 `/dream/*`，不与主对话消息列表混合。
- `AppRoute.profile`：资料页。
- `AppRoute.diary`：日记页。
- `AppRoute.garden`：花园页。
- `AppRoute.activity`：活动入口（阅读、五子棋、国际象棋）。
- `AppRoute.group`：独立群聊列表与会话。

## 生命周期

启动后：

1. 读取本机后端节点、访问凭证、可信私网 HTTP origin、屏幕上下文上传开关、备注名、头像、主题和后台通知开关。
2. 仅在访问凭证存在时加载聊天历史、花园状态。
3. 仅在访问凭证存在时调 `/mobile/activate`。
4. 仅在访问凭证存在时开启 5 秒 mobile poll；原生后台服务仍在退出过程中时暂时跳过。
5. 仅在访问凭证存在时开启 30 秒花园刷新。
6. 仅在独立上传开关开启时，每 45 秒上报经过本机过滤的非敏感屏幕上下文。

退后台：

- Flutter 停止前台 mobile poll。
- Android `MainActivity.onStop()` 仅在后台通知开启、访问凭证存在且 origin 可信时启动后台前台服务。

回前台：

- Android 无条件停止原生后台服务和中继订阅。
- Flutter 重新激活 mobile channel，并恢复 5 秒 mobile poll；主动消息直接进入会话流，不触发系统通知或悬浮窗。

## UI 组件分布

当前 UI 已按领域拆到 `lib/widgets/`，由 `lib/main.dart` 通过 Dart `part` 挂载，包括：

- 主壳：`YexuanCompanionApp` 位于 `lib/pages/app_shell.dart`；`YxDrawer`、`NavPill`、`PageHeader` 等位于对应 widgets 文件。
- 聊天：`ChatScene`、`ChatTopBar`、`Composer`、`HimMessage`、`YouMessage`、`TypingHimMessage`。
- Dream：`DreamPage`、`DreamStateStrip`、`DreamEntrance`、`DreamComposer`；复用聊天消息气泡布局。
- 设置：`SettingsSheet`、`ThemePaletteSheet`、`CapabilitySheet`；`SettingsSheet` 通过后端接口分别编辑 Reality 和 Dream 的世界书/破限配置，`CapabilitySheet` 管理默认空的屏幕正文上传 App 白名单。
- 资料：`ProfilePage`、`AvatarCropDialog`；`ProfilePage` 可通过 `/settings/prompt-assets` 切换 Reality 角色卡。
- 日记：`DiaryPage`、`DiaryCard`、`DiaryDialog`。
- 花园：`GardenPage`、`PlantCard`、`PlantPainter`。
- 活动与群聊：`ActivityHomePage`、阅读/五子棋/国际象棋页面和群聊页面，分别位于 `activity_widgets.dart`、`reading_widgets.dart`、`gomoku_widgets.dart`、`chess_widgets.dart`、`group_widgets.dart`。

## 后续结构约定

当前拆分已完成；后续较大改动遵循现有目录职责，优先保持 `part` 内的状态所有权和安全闸门不变。若要改为独立 library/import，应单列重构并补足测试：

1. `lib/models/`：纯数据模型和解析。
2. `lib/services/backend_client.dart`：后端 HTTP。
3. `lib/services/app_settings_store.dart`：MethodChannel。
4. `lib/pages/`：chat/profile/diary/garden/capability。
5. `lib/widgets/`：通用按钮、标签、头像、消息气泡、抽屉。

现有测试除 widget smoke test 外，已覆盖 mobile poll 生命周期、MethodChannel 契约、后台投递契约、后端请求/错误和中继 signal 契约；仍应在大重构前补齐受影响领域的测试。
