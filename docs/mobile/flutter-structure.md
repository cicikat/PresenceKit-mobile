# Flutter 结构

## 聊天情况与角色资料设置（2026-09-12）

新增 `ConversationCalendarController` / `ConversationCalendarPage` 和类型化日统计模型；页面拥有控制器生命周期，组合根只注入 HTTP 连接、凭据、角色显示名和本机配色。日周月年热力图、日期详情和连续天数的口径见 [conversation-calendar.md](conversation-calendar.md)。角色资料由侧栏移入设置同级折叠卡片，合并头像/名称编辑，去除重复行及开发说明。生活记录编辑器显式覆盖 dialog/input 主题，主聊天“现在”标签使用顶栏前景色。

## 手机交互工单 19（2026-09-12）

自己的气泡接入回复；长按菜单先释放 composer 焦点，全选打开只读、有选区的富文本窗口，可复制所选文字。ChatController 恢复/通知入口重读正式历史，并解析已有 assistant_display_text；思考使用 9.5px 紧凑按钮，锚点保留日期关联但不显示时间，防止正文重复日期栏。

设置分别显示日间/夜间背景导入和清除，YxPrefs/ChatAppearanceSettings 保存两个槽位，组合根按实际主题选图，删除背景不会丢失其他外观选项。原生槽位兼容与相册路径见 android/native-capabilities.md。

生活记录使用 72×72 缩略图、单行标题/明细与两行备注摘要，完整内容仍在查看校正中；类别和失败提示交换位置，失败用可读红色，操作位于卡片右下并保留内边距。页面、图标、筛选控件和编辑器使用当前配色，避免根亮色 Theme 造成夜间黑字。仅手机呈现，无新增组合根领域状态/Timer、管理面业务开关或桌面设置；旧图和识别失败边界见 known-issues。

设置栏目标题（2026-09-12）：权限与功能、通知闸门测试模式、能力检查和梦境设置共用 `_settingsSectionTitleStyle`，统一为 16px、w600、当前主题 ink1。截图开关直接放系统配置，使用 SettingsRow + Switch，能力页只读状态标记。analyze、截图控件回归通过，真实设备更新后的视觉验收仍 open。

## 设置与生活记录布局（2026-09-12）

侧栏用户头像选图后复用 `AvatarCropDialog` / `ImageCropViewport`，确认裁剪才保存，取消保留原头像。梦境背景、颜色与字号集中到梦境设置的「梦境 UI」分组；独立 `dream_appearance_settings.dart` 提供实时文字预览，色盘内也同步预览。界面字号与正文字号共用 `SettingsRow` 排版，系统字体沿用语言项的无下划线选择样式，设置滑块占整行。

生活记录采用双采集按钮、搜索/日历同行、横向分类、左图右文卡片；缩略图只读现有本机图片缓存，缺图或读取失败显示占位。保留日期筛选、分页、校正/删除确认、冲突处理、手动同步和队列观测。

三面闭环：这批变更只调整手机本机显示与既有头像文件的写入前裁剪，无新落盘字段、后台能力或业务开关，管理面和桌面无需同步配置。生活记录仍由既有 capability、scope、owner/realm 隔离及原生同步队列负责，未变更接口字段、revision、ack、TTL、重试、通知或权限。真机触摸裁剪与布局视觉验收仍待进行。

外观设置拆成日间/夜间两个独立列表项；预设使用名称、色块、选中标记和更多菜单，编辑/重置/复制/导出不再堆叠按钮。侧栏用户头像通过 image_picker 的 gallery 来源打开相册，选图后缩至最长边 1024 并在本机保存；不新增上传、后端开关或权限。

思考旁白：正文左对齐，按钮居中；两者共享主题 surfaceSoft 底面。外边距上下从 10px 改为 0，设置中 `reasoningOpacity` 可调底面不透明度（0–100%，默认 85%），经既有 appearance prefs 通道保存。仅改变本机外观，管理面/桌面无需同步业务配置，reasoning 读取、鉴权、消息关联、poll/ack 与通知链路不变。

下拉刷新现在无条件重读最新聊天历史，再执行 mobile catch-up；按角色、日期、时间、正文逐条对账，保留本地消息标识与正在发送/失败/附件消息。旧日志缺少稳定 ID 时这一兼容对账不等同于后端精确关联。主题管理支持 JSON 文件导入/导出，导入校验完整 schema，始终新增本机副本，不覆盖同名 ID。

`PersonalizationController` 管理本机字体与用户资料，`personalization_widgets.dart` 提供侧栏编辑和字体选择。`ReasoningController`/`reasoning_widgets.dart` 管理单回合读取与旁白展示；不新增组合根领域 Timer。主题与字体恢复不阻塞聊天连接初始化。

## 外观调整（2026-09-11）

手机群聊路由、页面和专属 HTTP 门面已移除，不删除后端数据。Dream 动作/感受取消斜体；旁白、聊天、动作分别持久化字号与颜色。主题预览支持点选区域打开色盘，日夜模式使用下拉框、分别选择预设；雾窗颜色来自桌面 presence-glass 的 OKLCH 色值转换。

三面检查：以上均为本机显示，管理面无需增加业务开关或审计，桌面功能独立保留；不改 mobile 请求字段、去重、ack、TTL、后台权限和通知。长回复分段等待上限缩短，跳过展示覆盖当前批次剩余内容；真实网络长回复仍需真机复验。

## 设置分组（2026-09-11）

`SettingsPage` 顶部固定显示访问 Token、后端节点和用户 ID；未配齐时解释自部署后端与鉴权初始化，配齐后仅显示「已配置」（不等同于联网验证成功）。其余按系统配置、外观、梦境折叠分组，能力检查单独入口。简单开关同行排列，复杂编辑器纵向布局适配窄屏。

主聊天世界书/破限编辑已移除，设置页不再请求 `/lorebook`、`/jailbreak-entries` 或 Reality prompt assets。DreamController 负责动态世界/破限列表与独立设置，UI 不硬编码资产名；保留旧单选字段的读取兼容，写入使用 `jailbreak_presets`。记忆范围、感知边界、清明模式与桌面端共用后端字段，梦境中禁止修改。设置路由订阅控制器以同步保存状态、语言、主题及连接变化。

`CapabilitySheet.controlsOnly` 复用原权限确认与设备门面，系统配置入口提供权限和功能操作；能力检查入口只提供观测、连通测试与刷新。无新增领域 Timer、持久状态或原生通道。

## 生活记录（2026-09-11）

侧栏 `AppRoute.lifeRecords` → `LifeRecordsPage`，由独立 `LifeRecordsController`
持有查询条件、分页、缓存/同步状态、30 秒前台重试与 generation 防串号。
`LifeRecordEditor` 提供图片确认、日期/类别及条目校正（数量、单位、金额、币种）；
`models/life_record.dart` 负责记录展示模型，中英文文案同步维护并 gen-l10n。
`app_shell.dart` 只负责 controller 注入、连接监听、路由和前后台生命周期，不新增领域 Timer。

`LifeRecordsService` 是 `presence_mobile/life_records` 专用门面；持久化与前后台共享传输
由 Android `LifeRecordsStore` / `LifeRecordsSync` / `LifeRecordsJobService` 实现。
这是 Android 优先能力，其他平台明确提示不支持采集/离线存储；其余页面仍可使用。
识别和角色工具已在后端实现，本地显示的排队状态不代表上传或识别完成。

## 当前入口与模块边界

`lib/main.dart` 是薄入口，负责全局错误兜底、根 `MaterialApp` 和 `CompanionApp` 挂载。历史 `part` / `part of` 结构已全部移除；`lib/` 下的 models、services、controllers、pages、widgets 现在都是独立 library，通过普通 `import` 建立编译器可检查的依赖边界。

主要目录职责：

| 路径 | 职责 |
|---|---|
| `lib/main.dart` | Flutter 入口、根主题、全局错误兜底 |
| `lib/pages/app_shell.dart` | 组合根、路由、应用生命周期和少量跨域 UI 协调 |
| `lib/controllers/connection_controller.dart` | 节点、token、owner、可信 origin、中继配置与 BackendClient 重建 |
| `lib/controllers/chat_controller.dart` | 历史加载/分页、发送、附件回复、去重、前台 mobile poll、ack 与聊天滚动 |
| `lib/controllers/device_controller.dart` | 锁屏、购物/悬浮窗、语音、屏幕上下文和传感器 Timer |
| `lib/controllers/dream_controller.dart` | Dream state/settings/stats/messages 与轮询 |
| `lib/controllers/garden_controller.dart` | 花园状态与刷新 Timer |
| `lib/controllers/diary_controller.dart` | 日记列表和详情加载 |
| `lib/controllers/theme_controller.dart` | 多颜色预设、旧数据迁移、`mods/` 资产加载、Web localStorage 与导出 |
| `lib/controllers/locale_controller.dart` | 跟随系统/中文/英文选择、即时切换与语言偏好持久化 |
| `lib/services/backend_client.dart` | 后端 HTTP 请求 |
| `lib/l10n/` | 中英文 ARB、生成的 `AppLocalizations` 和稳定值展示映射 |
| `lib/services/device_services.dart` | 五个设备域门面 |
| `lib/services/app_settings_store.dart` | legacy MethodChannel 兼容实现；由域门面包装，不再由 app shell 直接调用 |
| `lib/widgets/` | 场景页面和复用 UI |

## 状态所有权

- `edge_refresh.dart` 只持有边缘拖动动画，恢复逻辑属于 `ChatController.refreshConnection`。
- `image_crop_viewport.dart` 使用原图坐标进行有界裁切，供头像和背景编辑共用；导出不截取 UI。
- `SceneBackground` 在 app shell 的 Scaffold 外绘制主聊天/Dream 背景，避免 IME 压缩背景画布。
- `ChatMessage.attachments` / `uploadNote` 是当前会话的上传预览及重试载荷，`chat_image.dart` 负责原图查看；不作为后端历史或本地长期存储。
- 图片预览最大宽高为 126×170（原预览宽高各减半），点开仍查看原图；附言单独使用用户气泡颜色、字体和透明度。
- `BottomSystemInset` 仅占用 `MediaQuery.padding.bottom`，替代固定 22px 的仿导航条。主聊天/Dream 的系统底部区域填黑，IME 显示时不重复预留导航高度；空草稿不显示计数字符占位行。

- `ChatScene` 直接通过 `AnimatedBuilder` 监听 `ChatController`。
- `DreamPage`、`GardenPage`、`DiaryPage` 直接监听各自 controller；app shell 不再展开传递领域状态、加载标记和刷新回调。
- 资料页的本机备注名编辑弹窗属于纯 UI，位于 `profile_widgets.dart`；app shell 只负责保存编辑结果和更新组合状态。
- Token、后端节点和中继设置对话框位于 `settings_dialog_widgets.dart`；附件选择与上传仍由 app shell 协调，`upload_feedback_widgets.dart` 负责其可见反馈和预览文案。
- controller 通过构造注入获取 BackendClient、token getter 和设备门面，不反向依赖 app shell。
- `AppSettingsStore` 保留 `presence_mobile/settings` channel 兼容契约；Dart 侧由 `SettingsStore`、`VoiceService`、`DeviceControlService`、`ScreenSensorService`、`RelayStatusService` 分域使用。
- 根 `MaterialApp` 监听 `LocaleController`；设置页语言项位于第一行，切换后整棵 Flutter UI 即时按新 locale 重建。完整契约见 `localization.md`。

## 生命周期

启动后：

1. 并行恢复 ConnectionController 与 DeviceController。
2. token 存在时启动 ChatController、GardenController 和 mobile channel 激活。
3. ChatController 每 5 秒触发前台检查；原生后台服务运行时跳过，实际 poll 使用 25 秒长轮询并防重入。
4. DeviceController 每 45 秒推送一次允许的屏幕上下文，每 30 分钟上报一次电量/步数传感器快照。
5. app 暂停/隐藏时停止前台 chat poll；恢复时重新激活。

## 当前结构债

`app_shell.dart` 已从本轮开始时约 2406 行降至约 1196 行，连接、聊天、设备、Dream、Garden、Diary 的领域状态和 Timer 已迁出；资料、Dream、Token、节点和中继的纯 UI 对话框也已迁至 `widgets/`。它仍包含 profile、theme、capability/settings 页面编排、附件选择和可信 HTTP origin 等安全确认协调，尚未达到工单最初提出的 `<=600` 行愿景。后续新增领域功能仍必须新建 controller 和 widget，不得把领域字段、Timer 或成组业务方法加回 app shell。

## 验证

常用门禁为 `flutter analyze`、`flutter test`、`flutter build apk --debug --flavor dev`。本机若在测试套件启动前出现 `HttpException: Connection closed before full header was received` 且目标为随机 `127.0.0.1` 端口，应记录为 Flutter tester 回环环境故障；不能据此把断言标成通过。

## Inline chat typography (2026-09-09)

`models/inline_display.dart` owns the desktop-compatible paired-tag parser, canonical-text validation and paragraph style slicing. `widgets/inline_display_text.dart` builds TextSpans with theme red emphasis and font-size scaling. `ChatController` carries optional displayText through HTTP replies and live/catch-up polling without changing dedup/ack/voice logic. `HimMessage` and `AnimatedRevealText` use rich text for display and selection; copy/reply use canonical text. No state is added to app_shell.

聊天时间开关（2026-09-11）：设置 → 外观提供 `showChatTime`，默认 true，控制角色和用户消息头的时间；日期分隔及消息原始时间不变。经现有 appearance prefs 通道持久化，重启和删除背景后保留。纯本机外观，无后端/桌面开关、权限、队列或通知协议变化。

LifeRecordsController 的保存/连接/手动同步在 busy 期间合并为后续一轮，手动标志保留；缓存读取失败不阻断原生同步。复用原 30 秒恢复定时器，未向组合根增加状态。


## 按需截图三端接入（2026-09-12，partial）

详见仓库 `docs/screen-observation-2026-09-12.md`。后端 `observe_user_screen` 通过独立 HTTP poll/result 请求活跃电脑或手机的新截图，UUID/凭据绑定、20 秒 TTL、30 秒设备新鲜度和本地授权均参与门控；图像只在内存中处理。

管理面提供全局开关、effective state 与 `/perception/screen/status` 无正文观测；电脑视觉观察页、手机系统配置页各有独立本地授权，默认关闭。全局开启时自主工具继承启用，显式工具禁用优先；角色消息继续走原通知/免打扰链路。桌面 IPC 新增可选 onDemandEnabled；手机使用专用 screen_observation 通道与无障碍 worker，不改 mobile poll/ack/relay。

实现及构建/定向测试通过，真实双设备、锁屏、OEM 后台及 VLM/消息联合验收保持 open。管理面既有国际化测试 3 项失败保持 open，详见施工记录，不能将静态检查作为真实设备验收。

## 截图设置位置与样式修正（2026-09-12，partial）

手机按需截图开关移到 SettingsPage 的系统配置分组，复用 SettingsRow + Switch；能力权限页仅显示 CapabilityRow 状态标记，不再显示灰色禁用开关。系统配置中的权限操作子页不重复放置截图开关。桌面按需截图使用与“允许视觉观察”一致的左侧标题/说明、右侧滑动开关布局。两端 AGENTS.md 已写入复用周围 UI 风格约定，手机额外明确设置与权限观测边界。

三面检查：后端管理开关、effective state、观测端点、截图请求/TTL/去重和原生授权闸门不变。本次仅移动本机设置入口和统一控件；手机可先保存本地授权，实际截图仍须 Android 11+、无障碍及未锁屏。真实手机更新安装后的交互验收仍 open。
