# Flutter 结构

## 当前入口与模块边界

`lib/main.dart` 是薄入口，负责全局错误兜底、根 `MaterialApp` 和 `YexuanCompanionApp` 挂载。历史 `part` / `part of` 结构已全部移除；`lib/` 下的 models、services、controllers、pages、widgets 现在都是独立 library，通过普通 `import` 建立编译器可检查的依赖边界。

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
| `lib/services/backend_client.dart` | 后端 HTTP 请求 |
| `lib/services/device_services.dart` | 五个设备域门面 |
| `lib/services/app_settings_store.dart` | legacy MethodChannel 兼容实现；由域门面包装，不再由 app shell 直接调用 |
| `lib/widgets/` | 场景页面和复用 UI |

## 状态所有权

- `ChatScene` 直接通过 `AnimatedBuilder` 监听 `ChatController`。
- `DreamPage`、`GardenPage`、`DiaryPage` 直接监听各自 controller；app shell 不再展开传递领域状态、加载标记和刷新回调。
- controller 通过构造注入获取 BackendClient、token getter 和设备门面，不反向依赖 app shell。
- `AppSettingsStore` 保留 `presence_mobile/settings` channel 兼容契约；Dart 侧由 `SettingsStore`、`VoiceService`、`DeviceControlService`、`ScreenSensorService`、`RelayStatusService` 分域使用。

## 生命周期

启动后：

1. 并行恢复 ConnectionController 与 DeviceController。
2. token 存在时启动 ChatController、GardenController 和 mobile channel 激活。
3. ChatController 每 5 秒触发前台检查；原生后台服务运行时跳过，实际 poll 使用 25 秒长轮询并防重入。
4. DeviceController 每 45 秒推送一次允许的屏幕上下文，每 30 分钟上报一次电量/步数传感器快照。
5. app 暂停/隐藏时停止前台 chat poll；恢复时重新激活。

## 当前结构债

`app_shell.dart` 已从本轮开始时约 2406 行降至约 1499 行，连接、聊天、设备、Dream、Garden、Diary 的领域状态和 Timer 已迁出。它仍包含 profile、theme、capability/settings 页面编排、附件选择和部分弹窗协调，尚未达到工单最初提出的 `<=600` 行愿景。后续新增领域功能仍必须新建 controller 和 widget，不得把领域字段、Timer 或成组业务方法加回 app shell。

## 验证

常用门禁为 `flutter analyze`、`flutter test`、`flutter build apk --debug`。本机若在测试套件启动前出现 `HttpException: Connection closed before full header was received` 且目标为随机 `127.0.0.1` 端口，应记录为 Flutter tester 回环环境故障；不能据此把断言标成通过。