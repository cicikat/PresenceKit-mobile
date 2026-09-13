# 已知问题与技术债

## 资料接续联合验收（2026-09-13，observe）

后端已支持生活记录就绪后随对话/主动机会提供、图片多模式回读和静默工具结果接续。
手机现有上传、life_records outbox、revision/ack、通知及后台服务无需修改，不需新包。
管理面隔离后端实测和定向回归通过；运行中后端需重启，真实手机/模型联合验收未完成。
边界见 docs/backend/integration.md 与后端 docs/media-continuity-2026-09-13.md。

## Chat history and tool receipts (2026-09-13)

Current: canonical turn reconciliation, clock normalization and one reasoning anchor per turn. Open: legacy records without canonical IDs and mismatched clock/segmentation remain conservative. Partial: phone reads the existing 30-receipt history ring, without desktop real-time WS; storage disabled means no receipt recovery. Observe: native visual/restart and live-backend acceptance. The adjacent backend catalog still lists mobile roadmap; update it in a backend-authorized follow-up. Evidence and detail: [chat history and tools](mobile/chat-history-and-tools.md).


## 聊天情况验收边界（2026-09-12）

- `observe`：手机热力图和角色资料设置已接入，自动化使用合成统计验证；尚未用真实 mobile token 与运行中的后端做日历联调，也未完成真机触摸、日夜配色和重启恢复验收。后端管理面的只读统计接口、桌面独立接入和完整调用口径见 `docs/mobile/conversation-calendar.md`，相邻仓库本轮保持只读。
- 连续天数查询最多覆盖 366 天，遇到更长连续记录或未知历史边界显示 `≥` 已确认天数；不能据 `tracking_since` 推测角色相伴总天数。若需要精确的多年连续/首次相伴统计，建议后端新增角色维度的聚合结果后再消费，手机不复制长期统计台账。

## 手机交互工单 19（2026-09-12）

- `open`：旧版 LifeRecordsStore 在成功 ack 后删除本机图片，merge/接受服务器版本还会覆盖 image 引用；本轮保留现有图片及引用，并在删除记录时清理。已被旧版删除的图片无法由本次更新复原：后端只有结构化详情，没有受鉴权的原图读取端点。建议后续由后端提供 owner/scope/删除闸门一致的图片读取契约，再接手机重取；本次按用户要求不修改后端。新图与仍在本机的图片可继续展示，不把它写成旧图恢复完成。
- `open`：只读查询现有后端生活记录 SQLite jobs，发现 2 个 ValidationError、1 个 JSONDecodeError（均 failed）；这是已上传后识别结果处理失败。未修改后端、未重试识别。管理面现有 /life-records/observability 可继续查看失败任务与回执。
- `observe`：通知点击、下拉刷新、相册往返、日夜背景迁移及生活记录视觉验收仍需真实手机。本次 adb devices 无已连接设备。自动测试、离屏布局和 Dev APK 不等同真机验收。
- 本机图片继续使用既有 100 MiB 上限，满额明确拒绝新图，不静默驱逐用户图片；队列观测显示 local_images 的数量、字节数和上限。未新增队列/数据库/trace；桌面和后端管理开关、effective state、识别原图保留策略不变。后端总账未修改，遵守此次仅改手机端的边界。

## 本轮外观及思考验收边界（2026-09-11）

- current：本机发送及附件回复有固定思考入口，独立显示/默认展开开关；只读 canonical turn_id 端点。历史有显式 turn_id 才显示，缺 ID 不猜测。
- observe：真实 mobile token 的 reasoning 读取、后台先到/跨端主动回复的关联和真实长回复仍需联调；现有回归覆盖 UI 加载到正文、动态名称、展开收起、投递去重与分段跳过。后台/跨端无 canonical ID 的消息不新增思考入口。
- 字体/用户昵称签名头像是本机外观文件，设置页可观察字体清单、当前选择和字号；侧栏可观察用户资料。不新增业务真值或远端 trace；主题 JSON 仅导出颜色，不包含图片、字体内容、Token 或对话。

## 梦境设置对齐范围（2026-09-11）

- 已修复：手机世界卡/破限硬编码及旧单选字段导致的错误展示；现使用动态目录和多选字段，提供记忆范围、感知边界、清明模式。
- `open`：桌面完整 Dream 偏好仍包含模式/剧本选择、场景/镜像只读状态等更大范围能力；手机此次未实现整套桌面 Dream 窗口迁移。证据：`DreamController.enter()` 仍按现有入梦接口调用，设置 UI 只消费上述已接入字段。建议作为独立 Dream 迭代沿入梦、状态、退出全链路接入，不能把此次设置重排记为 Dream 全量对齐。
- `observe`：真实 Android 权限往返、OEM 后台服务和夜间提醒仍需真机验收；本轮自动测试与 Dev 编译不能替代真机投递证据。

## 生活记录前端先行（2026-09-11，open / observe / roadmap）

- `current`：`/life-records/*` 已有后端实现；总开关、识别与角色读取仍由后端管理面决定。本机不得把待上传素材显示为已识别。详见 `cc-tasks/17-life-records.md`、`cc-tasks/18-life-records-backend.md`。
- `observe`：Android JobScheduler 的联网恢复、Doze、强停后重新打开、开机恢复和相机进程回收需真机验收；系统可延迟后台执行。没有连接的真机/模拟器时不能将单元测试当作设备验收。相机回收通过 image_picker retrieveLostData 在打开生活记录页时重新请求用户保存；未确认的选择属于临时草稿，尚未入持久队列。
- `roadmap`：淘宝官方授权直接导入未实现；一期是用户主动提供截图。手机上传确认后清理本机源图，电脑原图跨端重取接口未实现；正式记录的日期、条目和备注可校正。营养估算/统计不属于一期，不能凭图片捏造摄入量。
- 缓存是已查询页面的本机副本，不是全部历史；联网查询由后端分页返回，离线页面明确显示缓存。正式删除和跨设备墓碑需后端按工单返回；schema 确认和真实 mobile token 联调完成前保持 open。

## API 思考可选展开（2026-09-09，roadmap）

后端默认存档 API 已返回思考并提供 admin-only 列表/详情。手机 UI、受限读取契约及
聊天 turn_id 关联尚未实现；不能把管理员凭据发给手机作为替代。真机展示未验收。

## P2：历史图片原图读取尚未闭环（2026-09-09，open）

- 影响：本轮修复让新选择的图片通过 `ChatMessage.attachments` 在当前会话显示原图并支持放大、带原附件重试；重启 App 或切换节点后，历史仍不能仅凭文件名恢复原图。旧记录若实际保留了合法 image data URI，可直接显示。
- 证据：后端 `admin/routers/chat.py` 的 `/upload/ingest` 写入 `media_refs`（kind、filename、sha256），返回 `stored_paths`；当前手机 `/chat-log/*` 模型没有受鉴权的图片读取地址。手机不得把后端磁盘路径当成手机路径或未鉴权 URL。
- 建议：后端提供与历史消息关联的稳定 media id 和受鉴权读取接口、保留期及不可用状态，再同步三仓接口总账和两端历史渲染。本轮未修改后端/桌面仓库，也未新增本地图片落盘缓存；不能把当前会话原图显示写成历史媒体功能已完成。

## 本轮交互修复（2026-09-09）

- 聊天顶部下拉/底部上拉支持短列表；达到阈值后松手刷新，恢复激活、失败的历史加载和非等待 poll，结果显示在当前界面。
- 头像/背景使用源图片坐标裁切，拖动和双指/滑条缩放都限制在图片内，边框和留白不进入导出结果。
- 主聊天/Dream 背景位于 Scaffold 外，键盘仅调整前景输入布局；实际分屏/小窗改变窗口大小时背景按新窗口适配。
- 新上传图片保留原始字节及附言，点开缩放；附件失败重试继续走 multipart 上传，取消附言弹窗不上传。
- OEM 真机输入法、自由小窗切换和相册选取仍需安装 Dev 包验收；Flutter 交互测试不等价于真机验收。

## P2：主动消息频率偏好未接入后端调度

移动端此前存在 `proactiveRate` 偏好，但后端没有对应调度字段，本机也没有消费者。该设置已从 UI 移除，保留字段仅用于兼容旧数据；重新接入前不得将其标记为已生效。

> 修复前请先对照代码确认问题仍存在；修复后在本文件改状态或移到已修复区。

## 当前仍存在（2026-08-02 更新后的权威清单）

- **设备重启后后台通道不自恢复** — `observe`。自用阶段接受，能力页能看见失活；要根治时另开 boot receiver 工单。
- **`app_shell.dart` 剩余结构债** — `open`。下一步按 profile、theme、capability/settings、附件与弹窗协调继续拆分，保持领域状态不回流。

本轮已关闭：维护者已确认 Mobile ntfy 后台推送恢复；debug 与正式包已分离，正式包的版本号限制与签名升级验收已完成。历史记录曾写有“`flutter test` 全量 105 项已通过”，但当前测试说明记录 tester 在断言前断开，因此该数字不能作为现行通过证据；以 [`docs/quality/testing-and-dev.md`](quality/testing-and-dev.md) 的带日期验证记录和当前重跑结果为准。外卖/购物悬浮窗硬编码示例订单已改为中性确认且不展示虚构商品/金额；通知权限不再在 `onCreate()` 弹出，改由能力检查页或首次开启后台通知触发。

## 历史快照（已由上方权威清单覆盖）

<details>
<summary>展开查看清盘前原始条目与修复背景</summary>

## P0：后台弹窗通知从未触发 — 根因是后端中继（ntfy）从未配置

**位置**：后端 `Emerald-presence/config.yaml`（缺 `relay_base_url/relay_topic`）、
`Emerald-presence/channels/relay_publisher.py`；手机端代码本身无致命问题。

**排查结论**（2026-07-10，按实证修正过一次）：

1. 入队路径**正常**：`core/turn_sink.py` 已有 durable mobile fallback——主动消息即使手机离线
   （`is_active=False`）也会写入 `mobile_queue`。实测 `mobile_queue_seq` 已到 608，证明消息一直在流。
   队列当前为空是因为前台 poll+ack 正常消费。**不需要改 `is_active`**（保持 TTL 门控，它只该管
   实时广播目标，不管入队）。
2. 真正断掉的一环：`config.yaml` 里从来没有 `relay_base_url/relay_topic/relay_token` 三个键
   （`config.example.yaml` 之前也没记载）→ `schedule_signal_publish()` 静默直接 return →
   **后端从不向 ntfy 发唤醒信号** → 手机后台服务永远等不到 SSE 信号 → 无弹窗。
3. 次级问题（已修）：`_relay_config()` 要求 token 必填，而手机端订阅侧 token 是可选的——
   无鉴权自建 ntfy 会导致后端永远判定"未配置"。已改为 token 可选。
4. 兜底路径也弱：中继未配置时手机端只剩 6 小时一次补偿轮询，且默认节点 `127.0.0.1:8080`
   在脱线后台时不可达（adb reverse 只在插线时有效）；命中后还有 23:30–06:30 静音 +
   30 分钟冷却两道闸（`notificationTestMode` 可绕过，用于测试）。

**已修**（后端，已过 `tests/test_relay_publisher.py` + `tests/test_mobile_queue_ack.py` 全部 10 例）：

- `config.example.yaml` 补上 `relay_*` 三键的文档化示例。
- `relay_publisher.py`：token 改为可选（无 token 不带 Authorization 头）；中继未配置时打一次
  warning 日志，不再静默。

**用户侧待办**（代码修完弹窗也不会来，还差配置）：

1. 起一个 ntfy 服务（`spike/push_relay_ntfy/server/docker-compose.yml` 有现成的，或用公网 ntfy.sh）。
2. 后端 `config.yaml` 填 `relay_base_url`、`relay_topic`（token 可选），重启后端。
3. App 设置里填同一组中继地址/topic，后端节点用局域网 IP 或 HTTPS（别用 127.0.0.1，后台不可达）。
4. 打开 App 后台通知开关、授予通知权限；测试时开 `notificationTestMode` 绕过静音/冷却。
5. 能力检查页看"中继已连接"和最近信号时间即可验证。

**本次复核（2026-07-12，工单 03）**：手机端的“中继已连接”只代表 SSE
订阅成功，不能证明后端已经 publish；能力检查页现同时展示最近信号时间，并在该时间为空时
直接提示核对后端 `relay_base_url` / `relay_topic`。通知闸门的累计抑制数和最近原因也已透出，
可据此区分“信号未发出”与“消息被静音/冷却吞掉”。本仓无法读取用户实际后端
`config.yaml` 或手机日志，因此根因仍以本节已实证的“后端 relay_* 尚未配置”为准；完成配置后，
请按工单用测试模式下的手动 ntfy publish 做真机验收。

## 已收缩：手机端不再持有 admin 全权 token

**位置**：`lib/services/backend_client.dart`、`android/app/src/main/kotlin/com/presencekit/mobile/MobileNotificationService.kt`、
`docs/backend/integration.md`

后端 SEC-AUTH-2 落地后，手机端应
换装 `mobile` profile scoped token（`emt_` 开头；scope：chat/state.read/memory.read/activity/
persona/sensor.write，不含 hardware/admin），不再需要旧的全权 admin secret。存储键、
MethodChannel、prefs 结构不变，只是填入的凭证值收敛为最小权限 token；旧 admin secret 仍可用
但不建议。`GET /system/data-path` 需要 admin scope，mobile token 下预期 403，能力检查页已识别
为中性状态而非故障。

**状态**：已修复（手机端侧）。现行 token、scope 和错误码说明见 `docs/backend/integration.md`；后端完整契约在同级 `Emerald-presence/docs/security.md`。

## 已修复：Android 后台常驻长轮询

**位置**：`android/app/src/main/kotlin/com/presencekit/mobile/MobileNotificationService.kt`

Android 后台已改为 ntfy SSE 实时主路径；不再维持 `wait=55` 常驻长轮询。中继明确订阅失败
或连续断开 15 分钟后，通过 `AlarmManager` 执行非阻塞补偿拉取，之后最多每 6 小时一次，
中继恢复即取消。

**状态**：已修复。中继重连仍使用 1-60 秒指数退避；能力检查页展示中继状态、最近信号时间、
最近中继心跳和最近周期补偿。

## 已修复：无障碍屏幕上下文本机敏感过滤

**位置**：`lib/controllers/device_controller.dart`、`android/app/src/main/kotlin/com/presencekit/mobile/YexuanAccessibilityService.kt`、`MobileNotificationService.kt`

原生采集层现在会过滤密码输入框，验证码、银行、支付、医疗类页级关键词，以及敏感 App/包名。屏幕上下文上传使用独立开关 `screenContextUploadEnabled`，默认关闭；不再有额外的按 App 文本上传白名单——2026-07 移除，唯一闸就是这个主开关加上述敏感内容过滤。

**状态**：已修复。过滤页面只保留 `isBlocked` 和 `blockedReason`，不保留标题、正文、包名或 App 名；Flutter 前台和 Android 后台都会跳过上传。

**后续建议**：结合实际安装应用继续扩充包名黑名单，并为过滤策略补充自动化测试。

## 已修复：公网 HTTP 和自动重定向可能绕过 origin 边界

**位置**：`lib/controllers/connection_controller.dart`、`lib/services/backend_client.dart`、`android/app/src/main/kotlin/com/presencekit/mobile/BackendSecurityPolicy.kt`、`MobileNotificationService.kt`

自定义明文 origin 现在只允许用户确认过的 RFC1918 私网精确 IPv4；公网 HTTP 即使曾保存过也不会放行。loopback、Tailscale `100.64.0.0/10` 和 HTTPS 仍可使用。

**状态**：已修复。Flutter 前台请求与 Android 后台请求均关闭自动重定向，`3xx` 不会绕过 origin 校验。

## 已修复：鉴权 token 硬编码

**位置**：`lib/controllers/connection_controller.dart`、`android/app/src/main/kotlin/com/presencekit/mobile/MobileNotificationService.kt`

访问凭证已从 Flutter 和 Android 原生源码移除。首次启动时由用户手动填写；Android 通过 `BackendSecurityPolicy` 写入并读取 `AndroidKeystoreCredentialStore`，后台服务每轮经同一策略重新读取。旧 `SharedPreferences` token 只在迁移期间读取，成功写入 secure storage 后删除。

**状态**：已修复访问凭证硬编码；owner/user id 已可在连接设置中配置，并由 ConnectionController 管理。

**后续验证**：继续覆盖已安装旧版本的迁移、替换/删除和安全写入失败回滚；owner id 等普通设置仍保留在 legacy `SharedPreferences`，不属于敏感 token。

## 已修复：`/upload/ingest` 请求未附带 `Authorization` header

**位置**：`lib/services/backend_client.dart` `BackendClient.uploadFiles()`

`BackendClient.uploadFile(s)` 已增加 token 参数，`/upload/ingest` 请求会设置 `Authorization: Bearer <token>`。

**状态**：已修复。

## P2：外卖/购物悬浮窗仍显示硬编码示例订单

**位置**：`android/app/src/main/kotlin/com/presencekit/mobile/FloatingBubbleService.kt`

`addOrderContent()` 固定展示“香菇滑鸡饭、白灼时蔬、姜茶、红包、合计 39.00”等示例内容，没有消费后端 behavior 或 message 中的真实建议。

**影响**：真实主动行为触发时，用户可能误以为后端已经完成选品；这与“不自动加购、不自动支付”的安全边界容易混淆。

**建议**：在未接真实购物车/推荐数据前，只显示普通确认文案；不要展示具体商品和价格。

## 已修复：Flutter 主体代码过度集中在 `lib/main.dart`

**位置**：`lib/main.dart` → 已拆分

原 8k+ 行 `main.dart` 已完成拆分：`lib/pages/app_shell.dart`（主状态/页面）、`lib/services/backend_client.dart`（HTTP 封装）、`lib/models/app_models.dart`（数据模型）、`lib/widgets/*.dart`（UI 组件）。现 `main.dart` 仅约 164 行入口。

**状态**：已修复。

## 已修复：`foreground_mobile_delivery_contract_test.dart` 覆写签名

**位置**：`test/foreground_mobile_delivery_contract_test.dart`、`lib/services/backend_client.dart`

`BackendClient.pollMobile()` 的 `waitSeconds` 具名参数已同步到测试替身 `_ForegroundBackendClient`，不再产生 `invalid_override`，该问题不会再阻塞测试套件加载。

**状态**：已修复。当前全量 `flutter test` 的阻塞原因是下方独立的 tester 回环连接故障。

## P2：本机 Flutter tester 在加载测试套件前断开

**位置**：`flutter test`

当前环境多次运行 `flutter test` 时，Flutter tester 在执行任何测试用例前报
`HttpException: Connection closed before full header was received`，目标为本机随机
`127.0.0.1` 端口。`flutter analyze` 与 Debug APK 构建均可正常完成。

**影响**：新增 widget test 可以通过静态分析编译，但当前无法在这台机器上实际执行断言。

**2026-07-13 复验**：10 个测试文件均在断言执行前失败，示例随机端口为 `127.0.0.1:57419`、`52702`、`57430`；错误仍为 `Connection closed before full header was received`。`flutter analyze` 通过，Debug APK 构建成功。

**建议**：排查本机回环连接、防火墙、安全软件与 Flutter SDK tester 进程；修复后重新运行完整测试。

## 已修复：系统设置内更换 Token 触发 Flutter 路由断言

**位置**：`lib/pages/app_shell.dart` 系统设置路由与 token 弹窗

Token 弹窗保存后已经通过父 State 更新 `_adminToken`，系统设置底部页仍额外调用
`sheetSetState()`，导致弹窗关闭与底部页重建叠在同一帧，触发
`_dependents.isEmpty` 断言。现已移除多余刷新，并为原生 Token 保存失败增加弹窗内错误提示。

## 已修复：手机主对话回复双发

**位置**：`lib/controllers/chat_controller.dart` `sendMessage()` / `pollMobile()`

手机主对话的同步响应与 mobile channel 可能携带同一条助手回复。手机前台此前会分别追加两次，而桌面客户端已有自己的同步响应 / WebSocket 去重逻辑，因此只有手机出现双发。现已为 Flutter 前台增加 45 秒短时回复指纹去重，同一回复无论先从同步响应还是 `/mobile/poll` 到达，都只显示一次。

## 已修复：后台服务状态由 SharedPreferences 标记，可能与真实服务状态漂移

**位置**：`MainActivity.kt`、`MobileNotificationService.kt`

能力检查页过去读取 `backgroundNotificationServiceRunning` 判断后台服务运行状态。这个值由服务启动/销毁和 Activity resume 写入，不是实时进程状态。

**状态**：已修复。`MobileNotificationService` 现在以进程内 `isServiceRunning` 生命周期标记暴露
实时真值，`MainActivity` 的 `isBackgroundNotificationServiceRunning` MethodChannel 调用直接查询
该值，不再信任 SharedPreferences 的历史标记。原 SharedPreferences 键暂时保留，仅用于兼容旧版
诊断数据，不再参与 Flutter 前台是否轮询的判定。

## 已修复：Android applicationId 仍是模板包名

**位置**：`android/app/build.gradle.kts`

原 `namespace` 和 `applicationId` 是模板值 `com.example.yexuan_memery`。

**状态**：已修复。Dart package 改为 `presencekit_mobile`，Android namespace/applicationId
改为 `com.presencekit.mobile`，Kotlin 源码目录和安装脚本同步迁移。legacy MethodChannel 与
SharedPreferences 名有意保留，避免把兼容契约误当成当前项目名继续扩散。

## 已关闭：release debug signing fallback

`android/app/build.gradle.kts` 现在要求任何 release task 提供完整的、本地或 CI 注入的固定 keystore；缺失时在打包前 fail-loud，不会输出 debug-signed release APK。配置、CI secrets 和剩余真机升级验收见 `docs/v1-release-readiness.md`。

## P3：通知权限在 Activity 创建时主动弹出

**位置**：`android/app/src/main/kotlin/com/presencekit/mobile/MainActivity.kt`

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

## 部分修复：`app_shell.dart` 结构债

**状态（2026-07-13）**：`part` 已移除；Connection、Chat、Device、Dream、Garden、Diary controller 已建立并接线，Chat/Dream/Garden/Diary 页面直接监听 controller；app shell 不再持有这些领域的 Timer 和成组业务状态。`AppSettingsStore` 已由五个域门面包装，app shell 无直接方法调用。

**状态（2026-07-22）**：app shell 已降至约 1196 行；资料、Dream、Token、节点和中继的纯 UI 对话框，以及附件可见反馈/预览文案已迁至 `widgets/`。

**剩余**：app shell 仍包含 profile、theme、capability/settings、附件选择和可信 HTTP origin 等安全确认协调，尚未达到工单 07 的 `<=600` 行长期目标。影响主要是可维护性，不改变当前接口和安全闸门。

</details>

## 已修复：mobile durable queue 积压被误作实时逐条 reveal，且中继断连补偿可延后数小时

**位置**：`lib/controllers/chat_controller.dart` 的 `pollMobile()` / `_appendMessages()`；
`android/app/src/main/kotlin/com/presencekit/mobile/MobileNotificationService.kt` 的中继断连与
`AlarmManager` 补偿路径；通知 `openAppIntent()` 与 `MainActivity.kt` 生命周期处理。

**影响**：手机打开后可能把已积压的历史主动消息按气泡逐条、串行出现，较长文本与多段消息会在队列中
等待很久，视图一段时间内停留在旧记录。中继不可用时，早晨入队的消息可能到下午才显示为系统通知；
点击通知后也没有明确的“同步并定位到最新”动作，体验上会像打开了旧对话。

**证据（2026-08-02）**：

- Flutter 仅以调用来源 `source == ChatDeliverySource.live` 和气泡数 `<= 10` 判断动画；它不检查
  `MobilePollMessage.timestamp` 是否早于当前轮询。后台服务停止与 Flutter 恢复之间的竞态会让恢复轮次
  被 `isBackgroundServiceRunning()` 跳过，随后 5 秒 timer 的 live poll 接到旧队列，进入 `_messageQueue`。
  `_appendMessages()` 对每个气泡按 `text.length / 40 CPS + 100-1000ms` 串行等待。
- Android 在中继不可用满 15 分钟后才安排补偿，成功补偿后的下一轮是 6 小时；`/mobile/poll` 非销毁式
  队列会返回所有未 ack 消息，因此延迟表现为旧消息集中弹出，而不是中继传输正文变慢。
- 通知 `PendingIntent` 只以 `SINGLE_TOP | CLEAR_TOP` 打开 `MainActivity`，无 action/extra；
  `MainActivity` 也未实现 `onNewIntent()` 向 Flutter 发出刷新和滚动到底部的事件。

**建议方向**：将“是否动画”改为以消息时间戳和明确的恢复/积压状态判定，而不是仅看 poll 来源；恢复时
应等待原生服务真正停止后完成一次强制 catch-up，并原子追加、立即定位到底部。中继失败时应缩短首个和
后续补偿间隔，并把 relay heartbeat/最近 poll/最近成功通知的时间暴露为可诊断状态。通知点击应携带
显式 action，原生通过 channel 通知 Flutter 立即 catch-up 并跳到最新消息。

**状态（2026-08-02）**：已修复。超过 15 秒的有服务端时间戳批次会原子静态追加；恢复前台会等待原生
服务退出（最多 2 秒）后进行 catch-up。中继断线 1 分钟后开始补偿并每 15 分钟续约；即使 SSE 保持连接，
也每 15 分钟执行一次受鉴权安全 poll。通知点击以一次性原生标记传递到 Flutter，凭证和首次历史同步完成后
执行 catch-up 并跳到最新消息。消息 id 去重、seen 持久化、ack 后推进 cursor 的原有顺序未改变。

## Inline typography history and visual verification (2026-09-09)

`observe`: reality HTTP/poll rendering now supports hl/big/sm, including typing and selection. Widget/controller regressions and a Dev APK validate implementation; physical-device visual verification remains pending. `roadmap`: backend chat-log history is plain text, so a reload cannot recover discarded styles. Independent Dream/group transport is not extended by this reality change. No new settings, permissions, queue or notification behavior are introduced.


## Life records v1 backend (2026-09-11)

current: /life-records capabilities/sync/list/detail/observability are implemented with dedicated life_records scope (mobile profile), transactional images/jobs/receipts, revisions/tombstones, bounded snapshot pagination, asynchronous OCR/vision, correction locks and owner-only read_life_records tool. Admin Service Configuration owns switches, effective recognition, task/device/audit observation and failed-task retry. See backend docs/life-records.md and brief 245. No changes to chat/poll/ack, notifications or payment.

observe: physical phone/network/Doze and live image-model end-to-end validation remain open. Backend tests include atomic retry, edits versus recognition, deletion, scopes, decimals, snapshot pagination and worker recovery; 72 initial scope/store tests and 39 focused/mobile regressions passed. Android LifeRecords/security/credential targeted task succeeded (cached unit-test output). Admin browser hard refresh used real isolated API. Desktop native record UI and original-image refetch remain roadmap.

## 生活记录真机排查（2026-09-11）

- `observe`：1.0.1+37 的 3 条记录已在本机队列，后端 enabled=false 阻止上传；recognition_available/background_sync=true。经用户授权启用后，已收到 2 次图片上传回执；剩余 1 项是同记录的本机修改，遇到 revision 冲突并保留，没有擅自采用电脑版本。
- `open`：生活记录页在用户自定义暗色背景下，说明文字与同步状态沿用浅色 Material 文本，存在低对比度；真机截图证实。建议后续按 YxPalette 统一此页 Material 主题与文本色。

- `open`：真实后端两张图片均上传成功，但识别任务均为 failed / ValidationError；额外一次不提交结果的识别诊断返回 JSONDecodeError，尚不能断言具体失败字段。建议后端按独立提取 schema 处理模型输出、未知值与用户已锁定字段，提供脱敏校验路径；修复后走管理面重试。recognition_available=true 仅代表配置就绪，不代表真实模型输出通过校验。
- `open`：已上传记录的后续本机校正在识别推进 revision 后可能冲突；当前只提供“采用电脑版本”，无保留本机修改的三方合并入口。用户确认前保留冲突，不应通过自动丢弃本机操作清空队列。


## 按需截图三端接入（2026-09-12，partial）

详见仓库 `docs/screen-observation-2026-09-12.md`。后端 `observe_user_screen` 通过独立 HTTP poll/result 请求活跃电脑或手机的新截图，UUID/凭据绑定、20 秒 TTL、30 秒设备新鲜度和本地授权均参与门控；图像只在内存中处理。

管理面提供全局开关、effective state 与 `/perception/screen/status` 无正文观测；电脑视觉观察页、手机系统配置页各有独立本地授权，默认关闭。全局开启时自主工具继承启用，显式工具禁用优先；角色消息继续走原通知/免打扰链路。桌面 IPC 新增可选 onDemandEnabled；手机使用专用 screen_observation 通道与无障碍 worker，不改 mobile poll/ack/relay。

实现及构建/定向测试通过，真实双设备、锁屏、OEM 后台及 VLM/消息联合验收保持 open。管理面既有国际化测试 3 项失败保持 open，详见施工记录，不能将静态检查作为真实设备验收。

## 截图设置位置与样式修正（2026-09-12，partial）

手机按需截图开关移到 SettingsPage 的系统配置分组，复用 SettingsRow + Switch；能力权限页仅显示 CapabilityRow 状态标记，不再显示灰色禁用开关。系统配置中的权限操作子页不重复放置截图开关。桌面按需截图使用与“允许视觉观察”一致的左侧标题/说明、右侧滑动开关布局。两端 AGENTS.md 已写入复用周围 UI 风格约定，手机额外明确设置与权限观测边界。

三面检查：后端管理开关、effective state、观测端点、截图请求/TTL/去重和原生授权闸门不变。本次仅移动本机设置入口和统一控件；手机可先保存本地授权，实际截图仍须 Android 11+、无障碍及未锁屏。真实手机更新安装后的交互验收仍 open。

## Life-record recognition follow-up (2026-09-12)

current: backend accepts prose/partial fields, routes food/cart to vision and bills to OCR, preserves user notes and stores separate recognition_description. Flutter list/editor display it and offline search includes it. 16 focused tests passed. observe: new build on physical phone and real OCR; open: keep-local conflict merge; roadmap: restoring historical images without a backend image-download endpoint.
