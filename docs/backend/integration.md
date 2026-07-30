# 后端集成

后端核心在 `Emerald-presence` 仓库（通常与本仓库同级）。手机端只通过 HTTP 接口交互，不直接读写后端数据文件。

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
- 对 RFC1918 私网 HTTP origin，App 会要求用户明确确认，并只保存确认过的精确 IPv4 origin。
- 公网 HTTP origin 会直接拒绝；公网节点必须使用 HTTPS。
- 后端需监听 `0.0.0.0:8080` 或对应网卡地址。
- Windows 防火墙需允许手机访问 8080。

## 鉴权

访问凭证不再内置于 Flutter 或 Android 原生代码。首次启动时由用户手动填写，使用隐藏输入框，并保存到 legacy `SharedPreferences("yexuan_memery", MODE_PRIVATE)`。Android 后台服务每轮轮询前重新读取凭证。当前尚未接入 Android Keystore，因此这仍是本机私有明文存储，只适合自用内测。

owner/user id 不再硬编码，改为在「后端节点」设置对话框中填写（与 backend base URL 同一个弹窗），保存到本机 `SharedPreferences`（`getOwnerUserId`/`setOwnerUserId` method channel），默认空字符串（占位符 `<owner_user_id>`）。仅支持 `[A-Za-z0-9_-]` 字符，与后端 `safe_user_id()` 校验规则一致。

访问凭证缺失时，前台请求、聊天加载、后台轮询、文件上传和屏幕上下文上报均不会启动。

后端节点请求前会校验 origin：

- 允许 `https://`。
- 允许 `http://127.0.0.1`、`http://localhost`。
- 允许 `http://100.64.0.0/10` Tailscale 地址。
- 允许用户明确确认过的 RFC1918 私网精确 IPv4 HTTP origin。
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
| `POST /desktop/chat` | Flutter `sendChat()` | 主对话用户发消息；与 Emerald-client 桌面端共用 Reality Chat 写入入口 |
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
| `GET /sensor/behavior/status` | 能力检查页 | 调试最近行为裁决 |
| `POST /mobile/push` | 能力检查页 | 写入主动行为测试 |
| `POST /phone_control/step` | Android `PhoneControlService` | 手机自动化循环：上报截屏/节点观察，换回下一步动作；契约见 `docs/protocols/phone-control-protocol.md` |
| `GET /phone_control/status` | 能力检查页 | 只读诊断：角色是否已授权 `phone_control` 工具 + 视觉模型是否已配置 |
| `POST /phone_control/debug/start` | 能力检查页测试面板 | 调试用：跳过 LLM 判断和 chat 内二次确认直接发起任务，仍过 danger-mode 门禁 |
| `POST /upload/ingest` | Flutter 文件/图片上传 | 文件投喂后端 |
| `GET /dream/state` | Flutter Dream 页面 | 读取 Dream 独立状态 |
| `POST /dream/enter` | Flutter Dream 页面 | 进入 Dream |
| `POST /dream/chat` | Flutter Dream 页面 | 发送 Dream 独立对话 |
| `POST /dream/exit` | Flutter Dream 页面 | 醒来并退出 Dream |
| `GET /settings/prompt-assets` | 资料页 / 偏好页 | 读取 Reality 角色卡、世界书、破限可用项与当前启用项 |
| `PATCH /settings/prompt-assets` | 资料页 / 偏好页 | 切换 Reality 角色卡、世界书或破限；仅提交发生变化的字段 |
| `GET /dream/settings` | 偏好页 / 能力检查诊断 | 读取 Dream 独立世界书开关、世界层和破限预设 |
| `PATCH /dream/settings` | 偏好页 | 保存 Dream 独立世界书开关、世界层或破限预设 |
| `GET /system/data-path` | 能力检查诊断 | 读取后端当前数据目录 `data_prefix`；沙盒路径会在诊断页高亮警示 |
| `GET /system/meta-mode` | 能力检查诊断 | 读取当前元模式 `mode`（safe/danger）及 `expires_at` |
| `GET /status` | 能力检查诊断 | 读取 `config_summary`（`llm_model`、`llm_provider`、`short_term_rounds`） |
| `GET /characters/active-info` | 能力检查诊断 | 读取当前加载的角色卡 `char_id` 和 `name` |
| `GET /lorebook` | 能力检查诊断 | 读取世界书条目列表（取 `entries` 数组长度） |
| `GET /jailbreak-entries` | 能力检查诊断 | 读取破限条目列表（取 `entries` 数组长度） |

## 数据流注意点

- 主对话写入与 Emerald-client 桌面端一致，走 `/desktop/chat`。手机端不直接读写后端 `data` 文件。
- 主对话历史与 Emerald-client 桌面端一致，只走 `/chat-log/*`。接口由后端负责适配真实数据目录，手机端不再回退旧短期记忆路径。
- Dream 使用 `/dream/*` 独立状态与对话接口；移动端 Dream 消息不混入主对话列表。
- Reality Prompt Assets 严格使用 `/settings/prompt-assets`；Dream 世界书、世界层和破限严格使用 `/dream/settings`，两套配置不交叉提交。
- `/desktop/chat` 的同步回复也可能进入 mobile channel。后端流式路径响应包含独立的 `msg_id`
  （`_stream_msg_id`）和 `turn_id`；mobile channel fanout 用的是 `turn_id`。Flutter 前台
  `BackendChatResponse` 同时解析 `msg_id` 和 `turn_id` 两个独立字段，并将两者都注册到
  `_synchronousAssistantReplyIds`，使 poll 去重在两个维度上均能命中，避免同一条回复在手机
  显示两次。旧后端或无 id 消息仍使用短时内容指纹兜底。
- 前台由 Flutter 每 5 秒轮询主动消息并直接写入会话流；后台中继只实时推送 signal，Android 收到后
  立即 poll 拉取正文；不再常驻长轮询，仅在中继长时间断连时由 `AlarmManager` 周期读取补偿队列。
- 前后台共用 legacy `SharedPreferences("yexuan_memery")` 中的 `lastAckedSeq`。poll 带
  `after=<lastAckedSeq>`；消息先进入会话/通知消费管线并持久化 `seenMobileMessageIds`，然后 ack，
  ack 成功后才推进本地游标。ack 失败会让下次重收，客户端依靠 `message.id` 去重。
- 主动消息正文不经过中继服务器；中继 signal 只包含 `id`、`seq`、`user_id`、`timestamp` 和
  `signal`，正文与 behavior 由受鉴权的 `/mobile/poll` 返回。
- `/mobile/poll` 队列现在是有 TTL、容量上限的非销毁式补偿副本；前后台消费后通过 `/mobile/ack`
  推进共享游标，不再把队列当作实时双写消费路径。
- 前台首次连接或切换节点时，先加载正式聊天历史，再以非动画方式 catch-up durable queue；后续实时 poll
  仍按正常气泡 reveal 展示。历史与 queue 同时命中的同步回复按现有 `msg_id` / `turn_id` / 内容指纹去重。
- 主动消息可以带 `behavior` metadata，手机端只消费 metadata，不自己定义触发规则。
- 屏幕上下文当前是实时上下文，不应被手机端直接长期记忆化。独立上传开关默认关闭；原生采集层会先过滤敏感页面。
- `/upload/ingest` 与其他后端请求一样附带 `Authorization: Bearer <token>`。
