# 07 - app_shell.dart 结构债审计与拆分

> 审计日期:2026-07-12。审计人:Claude Desktop。执行方:Claude Code。
> 背景:main.dart 拆分(见 known-issues「已修复:Flutter 主体代码过度集中在 lib/main.dart」)后,
> 结构债转移到了 `lib/pages/app_shell.dart`。本工单固化审计结论并给出拆分路线。

## 审计结论

### F1. app_shell.dart 已在恶化(实测 2674 行,文档写 2185)

- `_YexuanCompanionAppState`:约 **81 个状态字段、85 个方法**。
- 覆盖领域 ≥12 个:连接/鉴权(backend url、admin token、trusted origins、relay)、主题、
  语音录音、屏幕上下文/sensor、profile、能力检查、聊天历史(双数据源)、garden、diary、
  mobile poll、dream(state/settings/prompt assets/stats)、附件上传、路由分发。
- 增长机制:每加一个功能 = app_shell 加字段 + 加方法 + `_buildRoute()` 加参数,三处同时膨胀。

### F2. 根因是 `part` 结构,不只是行数

- `lib/main.dart` 用 `part` 引入全部 17 个文件,整个 lib 是**一个编译单元**。
- 所有 `_` 私有成员全仓互见,widget 层不直接访问 state 只靠自觉,编译器无约束。
- 私有性、依赖方向、层边界在当前结构下全部不可强制。

### F3. Prop-drilling 已爆炸

- `ChatScene` 构造约 30 个参数;Dream/Profile 等场景同模式。

### F4. 第二个 god object:AppSettingsStore(786 行,74 个 invokeMethod)

- 单一 `MethodChannel('presence_mobile/settings')` 上承载:设置持久化、语音录音、
  锁屏、悬浮窗/订单气泡、屏幕采集、relay 状态、通知闸门、权限查询。
- 名为 settings,实为整个设备桥。与 app_shell 同病:唯一入口 → 所有新能力默认塞入。

### F5. 相关已知问题

- known-issues P2「后台服务状态由 SharedPreferences 标记,可能与真实服务状态漂移」
  应并入 T3 处理范围。

---

## 工单

### T1. 杀 part,转 library + import 【前置,纯机械,单独 commit】

- 删除 main.dart 中全部 17 个 `part`;各文件去掉 `part of`,补 import,必要处将
  跨文件引用的 `_` 成员改公开(仅限模型/主题类,widget 不得反向 import app_shell)。
- 不改任何逻辑。验收:`flutter analyze` 0 error + `flutter test` 通过 + 手机冒烟。
- 完成后才有真实的模块边界,T2/T3 才有意义。

### T2. 抽域控制器 【依赖 T1;各域之间可并行】

- 方案:`ChangeNotifier` + 构造注入,不引 riverpod/bloc(薄客户端,不加大依赖)。
- 目标控制器(每个 = 字段 + 方法 + timer 从 app_shell 整体迁出):
  | 控制器 | 迁出内容 | 备注 |
  |---|---|---|
  | `DreamController` | dream state/settings/stats/messages、`_dreamStateTimer`、`_dreamScrollController`、enter/chat/wake/exit | **pilot,最自包含,先做** |
  | `ConnectionController` | backend url/token/origins/relay 设置与状态快照 | |
  | `ChatController` | history 双源加载、分页、去重指纹、发送、`_chatScrollController`、mobile poll | 最大块,最后做 |
  | `GardenController` | garden state + `_gardenRefreshTimer` | 小 |
  | `DiaryController` | diary list/detail | 小 |
  | `DeviceController` | 锁屏/悬浮窗/购物跳转/语音/屏幕上下文推送 + `_screenContextTimer`、`_sensorPushTimer` | 与 T3 门面对接 |
- 场景组件改为接收对应 controller(`ListenableBuilder`/`AnimatedBuilder`),
  消灭 30 参数构造。
- 完成态:app_shell 只剩组合根 + 路由 + 生命周期,目标 **≤600 行**。
- 每抽完一个域单独 commit;Dream pilot 验收通过后其余域可并行派发。

### T3. 拆 AppSettingsStore 为域门面 【不依赖 T2,可与其并行;依赖 T1】

- Dart 侧拆为:`SettingsStore`(真·设置持久化)、`VoiceService`、`DeviceControlService`
  (锁屏/悬浮窗)、`ScreenSensorService`、`RelayStatusService`。
- **channel 名 `presence_mobile/settings` 本期不动**(守 AGENTS.md 强制规则 4,
  Kotlin 侧零改动);内部共用一个私有 channel holder。channel 按域分拆留待后续评估。
- 顺带处理 known-issues P2:后台服务运行状态改为向原生查询真值,不再信 SharedPreferences 标记。
- 验收:`flutter test`(含 settings 契约测试,注意 `debugForceChannelAvailable`)。

### T4. 守护与文档 【随时可做,无依赖】

- 更新 AGENTS.md / ARCHITECTURE.md / docs/mobile/flutter-structure.md 中过期的
  「2185 行」及 part 结构描述(T1/T2 落地后各同步一次)。
- 加轻量闸门:CI 或 pre-commit 检查 `app_shell.dart` 行数只减不增(基线 2674)。
- 新增守则写入 AGENTS.md:新领域功能一律新建 controller + widget 文件,
  禁止向 app_shell 添加新状态字段。

## 依赖与并行总览

```
T1 ──┬── T2(Dream pilot → 其余域并行)
     └── T3(与 T2 并行)
T4 独立,随 T1/T2 各同步一次文档
```

## 施工状态（2026-07-13）

- T1 已完成：`part` / `part of` 全部移除，独立 library/import 边界已建立。
- T2 本轮目标已完成：Connection、Chat、Device、Dream、Garden、Diary controller 均已接线；聊天历史/分页/发送/去重/mobile poll/滚动与设备双 Timer 已迁出 app shell。
- UI 收口已完成：Chat/Dream/Garden/Diary 页面直接监听 controller，不再展开传领域状态。
- T3 已完成当前阶段：五个域门面已接入；`AppSettingsStore` 仅作为 legacy MethodChannel 兼容实现注入，app shell 无直接方法调用。
- 当前 app shell 约 1499 行。profile、theme、capability/settings、附件选择和弹窗协调仍是后续结构债，因此最初 <=600 行愿景尚未完成。
- 验证：lutter analyze 通过；lutter test 因本机 tester 随机 127.0.0.1 回环断连，在断言执行前失败；lutter build apk --debug 成功。