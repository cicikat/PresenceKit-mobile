# `lib/main.dart` 拆分计划

> 清单快照：2026-06-12，基于当前工作区约 9.9k 行的 `lib/main.dart`。本文只建立目标结构和搬移顺序，不搬任何业务逻辑。

## 完成状态

**状态：已完成结构拆分。**

- `lib/main.dart` 已从约 9.9k 行降到 64 行，只保留 imports/parts、默认后端节点、`main()` 和 `MyApp`。
- 顶层路由、状态与生命周期挂载已整体移到 `lib/pages/app_shell.dart`。
- `AppSettingsStore` 与 `BackendClient` 已移到 `lib/services/`。
- 数据/config 定义已移到 `lib/models/`。
- 页面展示和可复用 UI 已按领域移到 `lib/widgets/`。
- 为严格保持私有符号、状态所有权和 UI 行为，本轮机械拆分使用 Dart `part`；后续若要改为独立 library/import，应作为单独重构并补足测试。
- 三个空且目录归属错误的旧占位文件已删除。

最终验证：

```text
flutter test       5/5 passed
flutter analyze    No issues found
flutter build apk  Debug APK built successfully
```

通知、浮窗、采集的设备链路手测未执行：运行 `adb devices -l` 时没有连接设备或模拟器，`adb reverse` 返回 `no devices/emulators found`。

最终 Flutter 结构：

```text
lib/
  main.dart
  models/
    app_models.dart
    background_status.dart
    capability_status.dart
    screen_context.dart
  pages/
    app_shell.dart
  services/
    app_settings_store.dart
    backend_client.dart
  widgets/
    capability_widgets.dart
    chat_widgets.dart
    common_widgets.dart
    diary_widgets.dart
    drawer_widgets.dart
    dream_widgets.dart
    garden_widgets.dart
    profile_widgets.dart
    settings_editor_widgets.dart
    settings_widgets.dart
```

## 保护基线

搬移前基线命令：

```powershell
$env:NO_PROXY="localhost,127.0.0.1,::1"
$env:DART_SUPPRESS_ANALYTICS="true"
$env:APPDATA="D:\ai\yexuan_memery\.tool-home"
D:\soft3\flutter\bin\flutter.bat test --reporter expanded test\widget_test.dart
```

结果：5 个测试全部通过。

第一次在受限执行环境中运行时，`flutter test` 和 `flutter doctor -v` 都在 Flutter 工具启动阶段无输出超时；同一测试命令在允许 Flutter 工具链完整访问的环境中约 10 秒通过。没有发现需要修改的测试或业务代码。

后续每一批搬移都必须至少重新运行上述测试。模型和 `BackendClient` 拆出时，应先补对应解析、请求边界和 origin 拒绝路径的单元测试；现有 widget smoke test 不足以单独保护大拆分。

## 目标结构与命名

遵循 `docs/mobile/flutter-structure.md` 的现有约定，使用小写 snake_case 文件名，并按职责放入：

```text
lib/
  main.dart
  models/       # 数据结构、解析、轻量展示值对象
  services/     # HTTP、MethodChannel、生命周期和轮询协调
  pages/        # 路由级页面和页面专属 sheet/dialog
  widgets/      # 可复用展示组件
```

上述目标目录均已投入使用；原有空壳文件已经删除。

## 依赖方向

目标依赖应保持单向：

```text
main.dart
  -> pages
  -> services
  -> models

pages
  -> widgets
  -> services（通过回调或明确注入）
  -> models

widgets
  -> models / Flutter

services
  -> models / Dart IO / MethodChannel

models
  -> Dart / 最少量 Flutter 类型
```

Android 原生仍是通知、后台长轮询/中继、悬浮窗、无障碍和 origin 安全判断的执行端。Dart 拆分不能复制这套逻辑，也不能改变 `MethodChannel('yexuan_memery/settings')` 契约。

## 入口与顶层辅助清单

| 当前符号 | 职责 | 建议目标 |
|---|---|---|
| `main()` | Flutter 初始化、沉浸式系统 UI、启动 `MyApp` | 最终保留在 `main.dart` |
| `MyApp` | `MaterialApp`、基础主题和根页面 | 最终保留在 `main.dart` |
| `_formatDateTime`、`_weekdayLabel`、`_formatTodayLine`、`_formatDiaryDate`、`_gardenSummary` | 时间/日期与花园展示文本格式化 | 按调用域移到共享 formatter 或对应页面；禁止复制实现 |

## Model 清单

| 当前类/符号 | 职责与直接依赖 | 建议目标 |
|---|---|---|
| `CapabilityStatus` | 能力检查聚合；依赖 `BackgroundPollStatus`、`RelayConnectionStatus`、`NotificationGateStatus`、`ScreenTextUploadAppOption` | `models/capability_status.dart` |
| `BackgroundPollStatus`、`RelayConnectionStatus`、`NotificationGateStatus` | 解析 Android MethodChannel 状态 | `models/background_status.dart` |
| `ScreenTextUploadAppOption`、`ScreenContextSnapshot` | 屏幕上下文平台解析和安全上传 payload；后者依赖时间与集合处理 | `models/screen_context.dart` |
| `PickedUploadFile` | 文件名与 `Uint8List` | `models/picked_upload_file.dart` |
| `BehaviorDecisionStatus` | `/sensor/behavior/status` 解析；展示时间依赖 `_formatDateTime` | `models/behavior_decision_status.dart` |
| `_BehaviorTestSpec` | 能力检查页的调试选项，不是后端 model | 保持 `pages/capability_page.dart` 私有 |
| `AppRoute`、`AppRouteLabel` | App 内路由与显示名 | `models/app_route.dart` |
| `YxPrefs` | UI 偏好值对象 | `models/yx_prefs.dart` |
| `YxPalette` | 主题值对象和 JSON 序列化；依赖 Flutter `Color` | `models/yx_palette.dart` |
| `ChatMessage`、`AttachmentPlaceholder` | 主对话展示消息和附件占位解析 | `models/chat_models.dart` |
| `DreamState`、`DreamChatResponse`、`DreamSettings` | Dream 状态、回复和设置解析 | `models/dream_models.dart` |
| `PromptAssetOption`、`PromptAssets` | Reality prompt assets 配置解析 | `models/prompt_assets.dart` |
| `ChatLogEntry`、`ChatLogDay`、`ChatLogDates` | `/chat-log/*` 解析；`ChatLogDay` 依赖 `ChatLogEntry` | `models/chat_log.dart` |
| `GardenState`、`GardenSlot` | `/garden/state` 解析；`GardenState` 依赖 `GardenSlot` | `models/garden_models.dart` |
| `DiaryListItem`、`DiaryDetail` | `/diary/*` 解析 | `models/diary_models.dart` |
| `MobilePollMessage` | mobile channel 消息与 behavior metadata；`toChatMessage()` 依赖 `ChatMessage` 和 `_formatDateTime` | `models/mobile_poll_message.dart` |
| `BackendChatResponse` | `/desktop/chat` 与上传回复解析 | `models/backend_chat_response.dart` |
| `PresenceSnapshot` | 主壳生成的展示快照 | `models/presence_snapshot.dart`，或在主壳拆分时留作页面私有 |
| `Plant` | `GardenSlot` 到花园 UI 的展示映射 | 优先留在 `pages/garden_page.dart`，确认复用后再进 model |
| `_BackgroundDeliveryTestSpec`、`_PaletteRole` | 页面/编辑器私有展示配置 | 分别留在 capability/theme 页面文件 |

注意：`MobilePollMessage` 和 `BehaviorDecisionStatus` 直接调用顶层 `_formatDateTime`。搬移前先确定共享时间格式函数的位置，或把展示格式从 model 中移出；不能在多个文件复制一份实现。

## Service 与 Glue 清单

### 当前已有 service 类

| 当前类 | 当前职责与依赖 | 建议目标 |
|---|---|---|
| `AppSettingsStore` | 单一 legacy MethodChannel 包装；包含本地设置、origin 信任判断、文件/图片选择、通知和后台服务、relay 配置/状态、悬浮窗、锁屏、无障碍、屏幕上下文 | 第一阶段整体搬到 `services/app_settings_store.dart`，保持 Dart/Android 方法名同步 |
| `BackendClient` | 鉴权、origin 放行检查、禁重定向 HTTP、JSON/multipart 请求，以及 chat、Dream、日志、花园、日记、mobile channel、上传、sensor 接口 | `services/backend_client.dart` |
| `BackendException` | `BackendClient` 的用户可读错误 | 与 `BackendClient` 同文件 |

`BackendClient` 依赖 `AppSettingsStore.isAllowedBaseUrl()`，因此 origin 安全边界必须先于任何请求执行。拆分时禁止把 origin 检查降级成仅 UI 校验。

### 当前藏在 `_YexuanCompanionAppState` 的隐式 service/glue

| 责任块 | 当前方法/状态 | 依赖与后续方向 |
|---|---|---|
| 启动与生命周期协调 | `_restoreBackendAndStart`、`_startBackendSync`、`didChangeAppLifecycleState`、`dispose`、四个 `Timer` | 依赖 `AppSettingsStore`、`BackendClient` 和页面 State；最后再抽为 `services/app_lifecycle_coordinator.dart`，先保持行为不变 |
| origin 信任通道 | `_normalizeBackendBaseUrl`、`_ensureTrustedBackendOrigin`、`_changeBackendBaseUrl` | Android 原生负责规范化和安全判断，Flutter 负责明确确认 UI；后续可用 `services/trusted_origin_service.dart` 协调，但确认弹窗仍属于页面 |
| 前台 mobile poll / 通知 / relay glue | `_activateMobile`、`_pollMobile`、`_startMobilePollTimer`、`_stopMobilePollTimer`、seen-id 与短时回复指纹去重、`_handleForegroundBehavior` | 依赖 `BackendClient`、`AppSettingsStore`、`MobilePollMessage` 和聊天状态；后续可抽 `services/mobile_channel_controller.dart`。Dart 侧 relay 目前只有配置与状态，真正 relay consumer 在 Android，禁止另造并行 Dart consumer |
| 屏幕上下文中继 | `_pushScreenContextOnce`、`_captureScreenContextForDebug`、`_pushScreenContextSnapshot`、45 秒 timer | 依赖 `AppSettingsStore` 的本机过滤结果和 `BackendClient.pushScreenContext`；后续可抽 `services/screen_context_service.dart`，必须保留 blocked/白名单闸门 |
| 主对话协调 | `_loadHistory`、`_loadOlderHistory`、`_sendToBackend`、回复分段、滚动和去重 | 依赖 chat/log models、`BackendClient` 与 `ChatScene`；优先形成页面 controller，避免把 UI 滚动塞进 HTTP service |
| Dream 协调 | `_loadDreamState`、Dream timer、enter/send/wake/exit、prompt assets 与 Dream settings 更新 | 依赖 Dream/prompt models、`BackendClient` 与 `DreamPage`；随 Dream 页面最后拆 |
| 花园/日记协调 | `_loadGarden`、`_loadDiaryList`、`_loadDiaryEntry` | 依赖内容 models 与 `BackendClient`；可先保留在主 State，通过回调注入页面 |
| 本机能力和资料协调 | token、后台通知、主题、头像、锁屏、悬浮窗、购物 App、能力状态加载 | 同时依赖 MethodChannel 和弹窗 UI；先拆展示页，再评估 controller，避免一次改动跨越安全确认边界 |
| 上传协调 | `_pickAndUploadFile`、`_pickAndUploadImages`、`_uploadFilesToBackend` | 依赖 `AppSettingsStore` 选择器、`BackendClient` multipart 和聊天消息状态 |

## Page 清单

| 当前页面/路由级组件 | 主要依赖 | 建议目标 |
|---|---|---|
| `YexuanCompanionApp`、`_YexuanCompanionAppState` | 所有 service、route、页面和全局状态 | 最后收缩为 app shell；不要第一批搬 |
| `ChatScene` | `ChatMessage`、`YxPrefs`、`YxPalette`、消息气泡、composer、滚动回调 | `pages/chat_page.dart` |
| `DreamPage` | Dream models、`ChatMessage`、Dream/聊天 widgets、enter/send/wake 回调 | `pages/dream_page.dart` |
| `ProfilePage` | prompt assets、头像、主题和资料编辑回调 | `pages/profile_page.dart` |
| `DiaryPage`、`_DiaryPageState` | `DiaryListItem`、`DiaryDetail`、加载回调、日记 widgets | `pages/diary_page.dart` |
| `GardenPage` | `GardenState`、`GardenSlot`、花园 widgets | `pages/garden_page.dart` |
| `SettingsSheet` | `YxPrefs`、prompt assets、Dream settings、主题和系统设置入口 | `pages/settings_sheet.dart` |
| `SystemSettingsSheet` | token、后端、后台通知和能力检查状态 | `pages/system_settings_sheet.dart` |
| `CapabilitySheet`、`_CapabilitySheetState` | `CapabilityStatus`、`AppSettingsStore` 相关回调、调试卡片 | `pages/capability_page.dart` |
| `AvatarCropDialog` | 图片 bytes、裁剪与保存回调 | `pages/avatar_crop_dialog.dart` |
| `ThemePaletteSheet`、`_ThemePaletteSheetState` | `YxPalette` 编辑、预览和保存 | `pages/theme_palette_sheet.dart` |
| `AttachSheet` | 文件/图片选择回调 | `pages/attach_sheet.dart` |

## Widget 清单

建议按复用域成组搬移，避免每个几十行组件都单独建文件。

| 分组 | 当前组件 | 建议目标 |
|---|---|---|
| 通用导航/状态 | `NavPill`、`LiveDot`、`_Pulse`、`YxTag`、`YxIconButton`、`FloatingDrawerButton`、`PageHeader`、`SectionHeader`、`YxStatusPill` | `widgets/common_widgets.dart` |
| 头像/资料 | `YxAvatar`、`ProfileInfoRow` | `widgets/profile_widgets.dart` |
| 聊天 | `JumpToLatestButton`、`ChatTopBar`、`MetaLine`、`HimMessage`、`TypingHimMessage`、`JumpingDots`、`YouMessage`、`UserAttachmentCard`、`Composer` | `widgets/chat_widgets.dart` |
| Dream | `DreamStateStrip`、`DreamEntrance`、`DreamSceneLine`、`DreamComposer` | `widgets/dream_widgets.dart` |
| 抽屉 | `YxDrawer`、`DrawerItem` | `widgets/app_drawer.dart` |
| 设置 | `SettingsRow`、`PromptOptionChips` | `widgets/settings_widgets.dart` |
| 能力检查 | `ScreenContextDebugCard`、`BehaviorTestPanel`、`BackgroundDeliveryTestPanel`、`BehaviorDecisionDebugCard`、`_OemBackgroundGuide`、`CapabilityRow` | 优先留在 `pages/capability_page.dart`；确认跨页复用后再进 widgets |
| 主题编辑 | `_ThemePreview`、`_ColorDot` | 留在 `pages/theme_palette_sheet.dart` |
| 日记 | `DiaryCard`、`DiaryDialog`、`DiaryBodyBlock`、`DiaryEmptyState` | `widgets/diary_widgets.dart`，或先随 diary page 搬 |
| 花园 | `PlantCard`、`PlantPainter` | `widgets/garden_widgets.dart`，依赖页面私有 `Plant` 时先一同留在 garden page |

## 推荐搬移顺序

每一步只做机械搬移、补 import 和必要的可见性调整，不混入功能修改。

1. 固定基线：保持 `flutter test` 绿色；先为纯 model 解析和 `BackendClient` 安全边界补测试。
2. 搬无反向依赖的 model：Dream、prompt assets、chat log、garden、diary、picked file、后台状态。
3. 处理共享格式函数后，搬 `ChatMessage`、`MobilePollMessage`、`BehaviorDecisionStatus`、主题与路由 model。
4. 整体搬 `AppSettingsStore`，逐项核对 legacy MethodChannel 方法名；不要在这一步拆散其方法。
5. 搬 `BackendClient` 和 `BackendException`，保留 token、origin、禁重定向、超时和 multipart 行为。
6. 搬叶子 widget：common、chat、Dream、drawer、日记、花园；页面私有组件先随页面保留。
7. 搬 `ProfilePage`、Diary、Garden、Dream、Chat 和各设置/能力 sheet，通过现有回调保持状态所有权不变。
8. 最后拆 `_YexuanCompanionAppState` 中的生命周期、mobile channel、screen context 和上传协调；每次只抽一个责任块。
9. 收缩 `main.dart` 为 `main()`、`MyApp` 和 app shell import，并清理三个旧空壳文件。

## 每批搬移检查项

- `flutter test` 绿色；涉及共享契约时同时运行 `flutter analyze`。
- 不改接口路径、JSON 字段、轮询周期、去重窗口或超时。
- 不改变 origin 信任、token、通知、屏幕正文白名单、锁屏/悬浮窗确认等安全闸门。
- 改 `AppSettingsStore` 时同步核对 `MainActivity.kt`；改 mobile channel 字段时同步协议文档。
- 提交只包含该批机械搬移和对应测试，不夹带功能开发。
