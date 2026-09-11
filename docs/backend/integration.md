# 后端集成

## 设置控制面调整（2026-09-11）

- Reality 主聊天世界书与破限由后端管理面维护，手机设置不再读取条目列表或提交启用修改。
- Dream 独立设置使用 `GET /dream/settings`、`GET /dream/worlds`（`worlds` 列表）、`GET /dream/presets`（`presets` 列表），均沿用 Bearer mobile token 的 `activity` scope。资产 ID/label 原样显示，不以内置名字替代自定义项；加载失败显示错误与重试，不伪装成功。
- `PATCH /dream/settings` 只提交修改字段：`enable_dream_lorebook`、`world_layer`、`jailbreak_presets`、`memory_access`、`boundary_level`、`lucid_mode`。读取兼容旧 `jailbreak_preset`，优先使用新数组；保存使用新数组。后端仍负责枚举校验和入梦快照，本场梦境中手机禁用编辑。
- 三面核对：管理面的 Reality 资产、Dream CRUD/默认值/effective state 与审计保持后端负责；桌面 Dream 动态资产与上下文设置用作契约依据，未修改桌面/后端代码。本次不新增队列、trace 或台账；mobile chat/poll/ack、消息关联键、去重、TTL、鉴权和生命周期不变。固定深夜静音取消仅影响 Android 提醒，后台接收与提醒冷却仍分离。

## 生活记录（2026-09-11，proposed）

手机新增独立生活记录 UI 和 Android durable outbox。API 草案、schema、幂等和后端验收清单见
`cc-tasks/18-life-records-backend.md`；后端已放置 `cc-tasks/245-life-records-backend-handoff.md`。
`GET /life-records/capabilities`、`POST /life-records/sync`、列表/详情和
`GET /life-records/observability` 均尚未实现，不得作为 current HTTP 清单宣传。

传输由 `LifeRecordsService` → 独立 native channel → `LifeRecordsSync` 完成，使 Flutter
与 JobScheduler 共用同一队列和 HTTP 策略。复用原生 Keystore/Bearer、可信 origin 与 owner；
队列精确绑定 origin+owner，当前身份不符即拒绝，不自动向新节点迁移。
先检查 capability，再发送不可变操作；operation_id 去重，base_revision 乐观并发，确认
operation_id/record_id/revision/delete 后 ack 出队。金额/数量用十进制字符串，日期采用
occurred_on 本地日历日期，拍照时刻另存 UTC captured_at；用户编辑字段优先于后端识别。

管理面需要 enabled/effective reason、模型配置、background_sync、角色读取授权与脱敏观测；
桌面一期 UI 列 roadmap，本次不增加第二个配置真值。照片确认是本机上传授权，不等于后端角色
权限。不调用 `/upload/ingest` 触发对话，不写 `/sensor/realtime` 或长期记忆，不改已有
mobile poll/ack/TTL、relay、通知和购物辅助调用链。后台系统限制见 Android 能力文档。

## API 思考存档（2026-09-09）

后端默认独立保存 API 返回的思考，提供 admin-only
`GET /observability/llm-reasoning`（limit/before/model 元数据分页）和
`GET /observability/llm-reasoning/{call_id}`（parts 正文）。标准 mobile token 无权访问，
手机暂不消费，也无展开 UI。call_id 仅标记一次 API 尝试，尚未关联聊天 turn_id。
存储与 thinking.enabled 生成开关独立，无手机存储开关；未来展开属于展示偏好，需先
补适当的读取权限和关联键。既有 mobile/chat、poll、ack、通知和中继路径不变。

2026-09-09 外观跟进：图片预览缩小、附言气泡和底部安全区只调整 Flutter 展示，不新增后端/桌面开关、权限、持久化或协议字段。图片选择 → 原字节 multipart 上传 → 当前会话预览/原图查看和附件重试沿用现有链路；mobile ack、TTL、后台服务和后端 effective state 不受影响。

2026-09-09 交互修复闭环核对：聊天边缘刷新复用 `/mobile/activate`、`/chat-log/*` 和
`/mobile/poll`，catch-up poll 使用 `wait=0`，仍经过原有去重 → 持久化 seen → ack → 游标流程。
健康历史不因手动刷新被全量重载。上传继续使用 `/upload/ingest` 的 Bearer、`files`、`message`、
`channel=mobile` 契约；原始图片字节仅作为当前会话 UI 附件保留，失败重试发送同一文件和附言。
本轮未新增协议字段、服务端配置、权限、队列或落盘状态，无需管理面板/桌面设置开关；背景和
裁切属于本机 UI。历史原图跨端读取仍为 open，边界及后端入口证据见 `docs/known-issues.md`。

聊天背景属于本机外观设置，不进入后端接口或 mobile channel 消息队列。Flutter 通过
`presence_mobile/settings` 的 `pickChatBackgroundImage`、`getChatAppearance`、
`saveChatAppearance`、`deleteChatAppearance` 管理裁切后的图片、模糊度和聊天框透明度；
Android 将图片保存在应用私有目录，后端无需配置开关、鉴权或观测端点。

后端核心在 `Emerald-presence` 仓库（通常与本仓库同级）。手机端只通过 HTTP 接口交互，不直接读写后端数据文件。
三仓接口、WebSocket、Tauri IPC、Android channel、relay 和设置/观测闭环总账见
`Emerald-presence/docs/three-repo-interface-catalog.md`；本页保留手机端调用细节。

Appearance preferences use `presence_mobile/settings` methods `getAppearancePrefs` / `setAppearancePrefs` for `infoStrip`, `fontSize`, `showYouAvatar`, and `nightSilent`; they are local-only and do not enter backend APIs. `proactiveRate` is not exposed because no backend scheduler consumer exists.

## 连接方式

默认：

```text
http://127.0.0.1:8080
```

插线调试：

```powershell
adb reverse tcp:8080 tcp:8080
```

脱线调试：

- 在 App 后端节点里填电脑局域网 IP，例如 `http://192.168.10.154:8080`。
- 对 RFC1918 私网 IPv4 和 Tailscale MagicDNS `*.ts.net` HTTP origin，App 会要求用户明确确认，并只保存确认过的精确 origin。
- 公网 HTTP origin 会直接拒绝；公网节点必须使用 HTTPS。
- 后端需监听 `0.0.0.0:8080` 或对应网卡地址。
- Windows 防火墙需允许手机访问 8080。

## 鉴权

访问凭证不再内置于 Flutter 或 Android 原生代码。首次启动时由用户手动填写，使用隐藏输入框；Android 通过 `BackendSecurityPolicy` 将 admin/relay token 写入 `AndroidKeystoreCredentialStore`，并在每轮后台请求前经同一策略读取。legacy `SharedPreferences("yexuan_memery", MODE_PRIVATE)` 只作为一次性迁移来源，普通节点/owner 设置仍保存在其中。

owner/user id 不再硬编码，改为在「后端节点」设置对话框中填写（与 backend base URL 同一个弹窗），保存到本机 `SharedPreferences`（`getOwnerUserId`/`setOwnerUserId` method channel），默认空字符串（占位符 `<owner_user_id>`）。仅支持 `[A-Za-z0-9_-]` 字符，与后端 `safe_user_id()` 校验规则一致。

访问凭证缺失时，前台请求、聊天加载、后台轮询、文件上传和屏幕上下文上报均不会启动。

后端节点请求前会校验 origin：

- 允许 `https://`。
- 允许 `http://127.0.0.1`、`http://localhost`。
- 允许 `http://100.64.0.0/10` Tailscale 地址。
- 允许用户明确确认过的 RFC1918 私网精确 IPv4 和 Tailscale MagicDNS `*.ts.net` HTTP origin。
- 拒绝公网 HTTP origin，即使用户曾确认过也不会发送访问凭证。
- 拒绝带 userinfo、query、fragment 或路径的 origin。
- 前后台请求均关闭自动重定向；`3xx` 不会绕过 origin 校验。

### Scoped token（SEC-AUTH-2）

后端鉴权已从单一 admin secret 升级为多 token + scope 分层（后端侧完整设计见
`Emerald-presence/docs/security.md`）。本 app 使用 `mobile` profile，签发方式：

```text
POST /auth/tokens {"label": "mobile-main", "profile": "mobile"}
```

`mobile` profile 的 scope 集合：`chat`、`state.read`、`memory.read`、`activity`、`persona`、
`sensor.write`（不含 `hardware` / `admin` / `ws.*`）。手机是最易丢失的设备，丢机不泄露危险模式
开关、settings 写权限、硬件控制；端点与 scope 的完整定义以同级 `Emerald-presence/docs/security.md` 为准，本仓不复制后端工单。旧的 admin secret（legacy-admin）仍等价
`admin` scope，可以继续使用，但不建议——系统设置里的 token 输入弹窗已提示优先使用
`emt_` 开头的 mobile profile token。

Token 明文只在创建/轮换时返回一次；吊销、轮换均走后端 `/auth/tokens/*`（admin scope），操作手册
见 `Emerald-presence/docs/security.md`。

后端错误语义：

| 状态码 | 含义 | 手机端表现 |
|---|---|---|
| 401 | token 无效 | `backend_client.dart` 提示「token 无效，请检查系统设置里的 token」 |
| 403 | token 有效但 scope 不足（detail 含所需 scope） | 前台提示「token 权限不足：{detail}」；后台 `MobileNotificationService` 记为 `token scope insufficient` 并停止对同一 token 的重试，避免刷后端审计日志/触发 429 |
| 429 | 该来源 401 失败次数过多，被临时限流 | 提示「认证失败过多，来源已被临时限制，稍后再试」 |

`GET /system/data-path` 需要 `admin` scope，mobile token 预期拿不到；能力检查页把这一项的 403
渲染成中性状态「无权限（mobile token 预期行为）」，不算故障，其余端点的 403 仍按上表当作
需要回后端仓修表的错误处理。

## 接口清单

| 接口 | 调用方 | 用途 |
|---|---|---|
| `POST /mobile/chat` | Flutter `sendChat()` | 手机主对话用户发消息；与桌面共用 Reality Chat Pipeline，但 provenance 为 `mobile` |
| `POST /mobile/activate` | Flutter / Android service | 激活 mobile channel；即使 HTTP 200 也必须检查 JSON `ok` 与 `active`，失败时读取 `error` |
| `POST /mobile/deactivate` | Flutter dispose / 切节点 | 关闭 mobile channel；响应同样包含 `ok`、`active` 与可选 `error` |
| `GET /mobile/poll?limit=20&after=<seq>` | Flutter 前台 / Android 周期补偿 | 非销毁式读取；响应包含 `ok`、`active`、`error`、`messages`、`cursor`；`after` 为本机已持久化的最大 ack seq，首次可省略 |
| `POST /mobile/ack` | Flutter 前台 / Android 周期补偿 | 消息落库/写入去重记录后提交 `{"ack_seq": <本批最大 seq>}` |
| `GET /chat-log/dates` | Flutter | 读取聊天日志日期 |
| `GET /chat-log/{date}` | Flutter | 读取某日聊天日志 |
| `GET /garden/state` | Flutter | 花园只读状态 |
| `GET /diary/list` | Flutter | 日记列表 |
| `GET /diary/{date}` | Flutter | 日记正文 |
| `POST /sensor/realtime` | Flutter / Android service | 屏幕上下文上报；默认仅包名/App 名，独立上传开关 `screenContextUploadEnabled` 开启后上传完整正文（敏感 App/密码/关键词仍二次拦截），不再有按 App 的文本白名单 |
| `POST /sensor/push` | Flutter `BackendClient.pushSensorData()` | 手机周期性上报步数、电量、亮屏次数等 objective sensor；与 `/sensor/realtime` 的实时上下文契约分开 |
| `GET /sensor/behavior/status` | 能力检查页 | 调试最近行为裁决 |
| `POST /mobile/push` | 能力检查页 | 写入主动行为测试 |
| `POST /phone_control/step` | Android `PhoneControlService` | 手机自动化循环：上报截屏/节点观察，换回下一步动作；契约见 `docs/protocols/phone-control-protocol.md` |
| `GET /phone_control/status` | 能力检查页 | 只读诊断：角色是否已授权 `phone_control` 工具 + 视觉模型是否已配置 |
| `POST /phone_control/debug/start` | 能力检查页的开发者诊断区域（默认关闭） | 调试用：跳过 LLM 判断和 chat 内二次确认直接发起任务，仍过 danger-mode 门禁 |
| `POST /upload/ingest` | Flutter 文件/图片上传 | 文件投喂后端 |
| `POST /tts/synthesize` | Flutter / Android 播放链路 | 按场景合成移动端语音；provider 配置仍由后端管理面维护 |
| `GET /dream/state` | Flutter Dream 页面 | 读取 Dream 独立状态 |
| `POST /dream/enter` | Flutter Dream 页面 | 进入 Dream |
| `POST /dream/chat` | Flutter Dream 页面 | 发送 Dream 独立对话 |
| `POST /dream/exit` | Flutter Dream 页面 | 醒来并退出 Dream |
| `GET /settings/prompt-assets` | 资料页 / 偏好页 | 读取 Reality 角色卡、世界书、破限可用项与当前启用项；Mobile 只提供当前项选择与启停，不是完整编辑器 |
| `PATCH /settings/prompt-assets` | 资料页 / 偏好页 | 切换 Reality 角色卡、世界书或破限；仅提交发生变化的字段，Mobile 不提供条目 CRUD |
| `GET /dream/settings` | 偏好页 / 能力检查诊断 | 读取 Dream 独立世界书开关、世界层和破限预设 |
| `PATCH /dream/settings` | 偏好页 | 保存 Dream 独立世界书开关、世界层或破限预设 |
| `GET /system/data-path` | 能力检查诊断 | 读取后端当前数据目录 `data_prefix`；沙盒路径会在诊断页高亮警示 |
| `GET /system/meta-mode` | 能力检查诊断 | 读取当前元模式 `mode`（safe/danger）及 `expires_at` |
| `GET /status` | 能力检查诊断 | 读取 `config_summary`（`llm_model`、`llm_provider`、`short_term_rounds`） |
| `GET /characters/active-info` | 能力检查诊断 | 读取当前加载的角色卡 `char_id` 和 `name` |
| `GET /lorebook` | 能力检查诊断 | 读取世界书条目列表（取 `entries` 数组长度） |
| `GET /jailbreak-entries` | 能力检查诊断 | 读取破限条目列表（取 `entries` 数组长度） |

活动、群聊和群梦调用也已在 `BackendClient` 接通：`/activity/reading/*`、
`/activity/gomoku/*`、`/activity/chess/*`、`/activity/dream_seed/*`、`/group/*` 以及
`/group/{id}/dream/state|enter|send|exit|transcript`；字段和状态机以三仓总账及后端
`/openapi.json` 为准，不在本页复制第二份完整 schema。

## 数据流注意点

- 手机主对话走 `/mobile/chat`；桌面端保留 `/desktop/chat`。两者复用 Reality Chat Pipeline，手机端不直接读写后端 `data` 文件。
- 主对话历史与 Emerald-client 桌面端一致，只走 `/chat-log/*`。接口由后端负责适配真实数据目录，手机端不再回退旧短期记忆路径。
- Dream 使用 `/dream/*` 独立状态与对话接口；移动端 Dream 消息不混入主对话列表。
- Reality Prompt Assets 严格使用 `/settings/prompt-assets`；Dream 世界书、世界层和破限严格使用 `/dream/settings`，两套配置不交叉提交。
- `/mobile/chat` 的同步回复与 mobile durable queue 使用同一 `turn_id`/`msg_id`。手机请求不启用 desktop stream，
  但 durable mirror 不因 live origin 为 mobile 而取消。Flutter 前台同时解析 `msg_id` 和 `turn_id`，
  并将两者注册到 `_synchronousAssistantReplyIds`，使 poll 去重命中；旧后端或无 id 消息仍使用短时内容指纹兜底。
- 前台由 Flutter 每 5 秒轮询主动消息并直接写入会话流；后台中继只实时推送 signal，Android 收到后
  立即 poll 拉取正文。中继断线 1 分钟后由 `AlarmManager` 每 15 分钟补偿一次；中继 SSE 保持连接时也
  每 15 分钟执行一次安全 poll，限制单个 signal 丢失造成的队列滞留。
- 前后台共用 legacy `SharedPreferences("yexuan_memery")` 中的 `lastAckedSeq`。poll 带
  `after=<lastAckedSeq>`；消息先进入会话/通知消费管线并持久化 `seenMobileMessageIds`，然后 ack，
  ack 成功后才推进本地游标。ack 失败会让下次重收，客户端依靠 `message.id` 去重。
- 主动消息正文不经过中继服务器；中继 signal 只包含 `id`、`seq`、`user_id`、`timestamp` 和
  `signal`，正文与 behavior 由受鉴权的 `/mobile/poll` 返回。
- `/mobile/poll` 队列现在是有 TTL、容量上限的非销毁式补偿副本；前后台消费后通过 `/mobile/ack`
  推进共享游标，不再把队列当作实时双写消费路径。
- 前台首次连接、切换节点、恢复或通知打开时，先加载正式聊天历史，再以非动画方式 catch-up durable queue；
  后续实时 poll 仍按正常气泡 reveal 展示，但服务端时间戳超过 15 秒的批次一律原子静态追加。历史与 queue
  同时命中的同步回复按现有 `msg_id` / `turn_id` / 内容指纹去重。
- 主动消息可以带 `behavior` metadata，手机端只消费 metadata，不自己定义触发规则。
- 屏幕上下文当前是实时上下文，不应被手机端直接长期记忆化。独立上传开关默认关闭；原生采集层会先过滤敏感页面。
- `/upload/ingest` 与其他后端请求一样附带 `Authorization: Bearer <token>`。

## Model streaming compatibility settings audit (2026-09-09)

Backend admin Preset editing owns force_stream (default false, Chat Completions only). Model requests including tool decisions are buffered from SSE; mobile receives the original complete `/mobile/chat` JSON without new SSE/WS, scopes, background services or local settings. Request transport is independent of typing animation. Real gateway and admin browser verification remain observe in the backend interface catalog.

## Inline display delivery (2026-09-09)

Reality HTTP chat/upload replies and turn-sink poll messages consume optional display_text; reply/content stays canonical for voice, notification, quotation and dedup. Phone validates copy text equality, then renders hl/big/sm in animation and selection with desktop proportions and the theme red color. Existing font-size/theme settings apply; no backend feature switch, new client setting, native permission or service is needed. Backend queue poll is the existing read-only observation surface. Old history style recovery and independent Dream/group display transport remain roadmap; real-device visual verification remains observe.


## Life records v1 backend (2026-09-11)

current: /life-records capabilities/sync/list/detail/observability are implemented with dedicated life_records scope (mobile profile), transactional images/jobs/receipts, revisions/tombstones, bounded snapshot pagination, asynchronous OCR/vision, correction locks and owner-only read_life_records tool. Admin Service Configuration owns switches, effective recognition, task/device/audit observation and failed-task retry. See backend docs/life-records.md and brief 245. No changes to chat/poll/ack, notifications or payment.

observe: physical phone/network/Doze and live image-model end-to-end validation remain open. Backend tests include atomic retry, edits versus recognition, deletion, scopes, decimals, snapshot pagination and worker recovery; 72 initial scope/store tests and 39 focused/mobile regressions passed. Android LifeRecords/security/credential targeted task succeeded (cached unit-test output). Admin browser hard refresh used real isolated API. Desktop native record UI and original-image refetch remain roadmap.


## XHS reader deployment (2026-09-11)

Backend-owned settings remain authoritative; no client credentials or local switches were added. Docker login and a user-provided share were verified with body text, one WebP image description and ten sampled comments. The adapter supports xhslink.cn and returns busy/cooldown_seconds in its settings projection. Reads are serialized with a 15-25 second cooldown and five-minute backoff on login/rate rejection. Native chat verification and loading the new code in the running backend remain observe.
