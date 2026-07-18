# 中继发布契约

> **状态**：后端与 Android 已实现 signal-only 中继链路：“收到 signal 后回源
> `/mobile/poll` 拉正文”。后端业务发布契约以 A1 唯一消息和 G2 单调 `seq` 为准；
> 队列保留为正文来源与有界补偿存储。
> 上游参考：[mobile-channel.md](mobile-channel.md) — 消息结构与 behavior 映射以该文档为准。

---

## 1. 中继角色

```
后端服务器
  └─ POST <relay-base-url>/<topic>    {"message": "<json-payload>"}
       ↓ 中继服务器（ntfy 或兼容实现）
         ↓ SSE / WebSocket 推送
           └─ Android MobileNotificationService（前台服务）
                └─ 收到 signal → 调 /mobile/poll?after=<lastSeq> → 原有去重/投递
```

中继是**实时唤醒主路径**，只承载“有新消息”信号。消息正文只通过后端
`/mobile/poll` 返回；中继第三方不可见正文或 behavior（见第 7 节）。

---

## 2. Topic 命名规则

### 格式

```
mychar/<user_id>/<device_token>
```

| 段 | 值 | 说明 |
|---|---|---|
| `mychar` | 固定前缀 | 隔离同一 ntfy 实例上的其他应用 |
| `<user_id>` | 当前 owner user id（示例，实际由用户在设置里配置） | 用户维度隔离，多设备共享 |
| `<device_token>` | 客户端生成的 UUID v4，每次安装唯一 | 设备维度隔离，避免多设备串台 |

### 示例

```
mychar/<owner_user_id>/a3f2c1b0-8e4d-4f7a-9c3b-1d2e5f6a7b8c
```

### 命名约束

- **不允许**省略 `<device_token>`：用户有多设备时，同一 user_id 的 topic 若不隔离设备，
  每条消息会同时送达所有设备，重复通知且无法针对单设备撤回。
- **不允许**使用可预测的 topic（如纯 user_id）：ntfy topic URL 即是订阅密钥，
  名称可猜则任何人均可订阅并监听消息流。
- topic 字符集：`[a-z0-9\-_/]`，总长度 ≤ 128 字节（ntfy 限制）。

---

## 3. 消息体格式

后端 `POST` 给中继时，body 必须是合法 JSON，中继将其原样或封装后转发给客户端。

### 3.1 最小合法 signal-only 消息体

```json
{
  "id": "msg-20260612-001",
  "seq": 42,
  "user_id": "<owner_user_id>",
  "timestamp": 1749686400,
  "signal": "new_message"
}
```

后端已按此格式实现发布。中继 payload **只允许**上述字段，绝不包含 `content`、`behavior`
或其他正文/展示元数据。客户端收到信号后必须以 `seq` 为游标回源 `/mobile/poll` 拉取完整消息。
Android 收到旧式含 `content` payload 时也会忽略正文并强制回源，不保留中继正文直投路径。

### 3.2 `id` 字段（必填）

- 类型：非空 ASCII 字符串，建议格式 `msg-<yyyymmdd>-<seq>` 或 UUID。
- **全局唯一**：同一 user_id 下不同消息的 id 不得复用，包括重试投递的副本。
- 与补偿队列中完整消息的 A1 `id` 相同；signal 本身不直接展示，客户端回源后仍按完整消息
  `id` 做去重（见第 6 节）。

### 3.3 `seq` 与 `signal` 字段（必填）

- `seq`：与补偿队列完整消息的 G2 单调游标相同；客户端用于
  `/mobile/poll?after=<lastSeq>` 回源。
- `signal`：当前固定为 `"new_message"`；未知 signal 不得直接投递，Android 可将其作为保守唤醒
  触发一次 poll。

### 3.4 ntfy 封装层（如中继为 ntfy）

ntfy 服务器会在转发时在外层包裹一个 SSE 事件：

```
event: message
data: {"id":"ntfy-id","time":1749686400,"event":"message","topic":"mychar/…","message":"<payload>"}
```

客户端从 `data.message` 字段取出原始 JSON payload，再按 3.1 格式解析并回源 poll。
`data.id` 是 ntfy 自己的事件 ID，与 `payload.id` 无关，**不可用于业务去重**。

---

## 4. 鉴权

### 4.1 客户端订阅中继

| 方式 | 说明 |
|---|---|
| `Authorization: Bearer <relay-token>` | 首选，ntfy 和大多数自托管中继均支持 |
| URL 内嵌 token（`?auth=<base64>`） | 备选，仅用于不支持请求头的 SSE 场景 |

`relay-token` 是与后端 `admin-token` **独立**的凭证：

- 中继 token 只授权订阅该 topic，不授权访问后端 API。
- 中继 token 可以有独立的过期和轮换策略，不必与 admin-token 同步。

### 4.2 后端发布到中继

后端携带自己的中继写入凭证（与客户端订阅凭证不同权限）向中继 POST。
客户端侧不存储也不感知后端的发布凭证。

### 4.3 Topic 私密性

- ntfy topic URL 即是订阅密钥——知道 URL 即可订阅。
- device_token（UUID v4）提供约 122 bit 熵，不可穷举。
- 自托管中继需启用 TLS（HTTPS），防止 topic 路径在传输中泄露。
- 公网 HTTP 中继**客户端拒绝接入**（复用后端 origin 信任策略，见第 5 节）。

---

## 5. 客户端 origin 信任策略

中继 base URL 复用与后端相同的校验链（`BackendSecurityPolicy.isAllowedBaseUrl`）：

| URL 类型 | 是否允许 | 说明 |
|---|---|---|
| `https://` 任意主机 | 允许 | 公网 HTTPS 无需额外确认 |
| `http://127.0.0.1`、`http://localhost` | 允许 | 本机开发场景 |
| `http://100.64.x.x`（Tailscale） | 允许 | 内网隧道场景 |
| `http://10.x`、`http://192.168.x`、`http://172.16-31.x` | 需用户明确确认 | RFC1918 私网，走同一确认弹窗流程 |
| 公网 `http://` | 拒绝 | 明文传输，不存储 token |
| 带 userinfo / query / fragment / 路径 | 拒绝 | 非标准 origin 格式 |

私网 HTTP 中继走同一条确认链路（`addTrustedCleartextOrigin`），即与后端地址确认框共用——
用户确认过某个私网 IP 作为后端，该 IP 同时对中继有效。

---

## 6. 客户端去重（四阶段对齐）

中继推送路径与 `/mobile/poll` 路径最终进入相同的去重机制：

| 阶段 | 位置 | 机制 |
|---|---|---|
| **A1** 服务端唯一 ID | 后端 | 每条消息在入队前分配全局唯一 `id`，中继和 poll 共用同一个 `id` |
| **A2** 后台跨轮次去重 | Android `MobileNotificationService` | signal 触发 poll 拉取完整消息；完整消息消费后写入 `seenMobileMessageIds`（SharedPreferences JSON 数组） |
| **A3** 补偿窗口去重 | signal 即时 poll / 中继断连恢复期 | 即时 poll 与补偿 poll 先后拉到同一 `id` 时，A2 保证只展示一次通知 |
| **A4** 前台消息去重 | Flutter `MobilePollMessage` | 前台以同步响应 `msg_id` / `turn_id` 对账 poll `message.id`；仅无 id 消息使用短时内容指纹兜底 |

**关键约束**：signal 本身不写入 `seenMobileMessageIds`、不直接投递；它只触发
`/mobile/poll?after=<lastAckedSeq>`。poll 拉回的完整消息必须在投递时将其 `id` 写入
`seenMobileMessageIds`，即时回源与补偿回源共用同一个存储 key，否则 A2/A3 失效。

---

## 7. 最终发布与补偿约定

后端以中继作为实时唤醒主路径。创建主动消息时：

1. 分配全局唯一 A1 `message.id` 和单调 G2 `seq`，将含正文/behavior 的完整消息写入有
   TTL、容量上限的 `/mobile/poll` 队列。
2. 写盘成功后，异步向设备中继 topic 发布同一 `id` / `seq` 的 signal-only payload。
   发布失败不回滚、不阻塞已完成的队列入队，设备仍可通过 poll 恢复。

`/mobile/poll` 队列是唯一正文来源，同时承担 Flutter 前台轮询、Android 收到 signal 后的即时
回源和后台断线补偿。中继只负责低延迟唤醒，不持有任何正文。

当前后端已实现 `/mobile/poll?after=<seq>` cursor 和 `/mobile/ack`；队列仍不得停止写入，
因为它既是正文源，也是中继发布失败、设备未收到 signal 或中继长时间不可用时的恢复来源。

---

## 8. 发布失败时后端行为

| 场景 | 期望的后端行为 | 当前状态 |
|---|---|---|
| 中继服务返回 5xx | 指数退避，总尝试最多 3 次，仍失败则等待补偿队列恢复 | 后端已实现 |
| 中继服务不可达（DNS / 连接失败） | 同上，快速失败，不阻塞后续消息入队 | 后端已实现 |
| 中继 token 无效（401/403） | 不重试，记录错误，消息仍进 poll 队列 | 后端已实现 |
| 补偿队列 TTL 到期前仍未送达 | 后端记录告警；不得无限增长队列 | 待确认 |

客户端对中继推送失败无感知（中继是服务端 → 中继的 push，不是客户端 → 中继的 pull 失败）。
客户端只监控 SSE 连接断开并自动重连，不感知后端是否成功 POST 给中继。

---

## 9. 客户端配置项

```
relay_base_url  : String?   中继 base URL，e.g. https://ntfy.sh（无尾斜杠）
relay_topic     : String?   完整 topic 路径，e.g. mychar/<owner_user_id>/<device_token>
relay_token     : String?   订阅凭证，Bearer token，不混入后端 admin-token
```

三项均可为 null（中继功能未配置）；Flutter 前台仍每 5 秒轮询，Android 后台仅做周期补偿。

存储位置：`SharedPreferences("yexuan_memery", MODE_PRIVATE)`，key 分别为
`relayBaseUrl`、`relayTopic`、`relayToken`。

Android 后台服务在中继连接成功时只消费 SSE；订阅失败或连续断线超过 15 分钟后通过
`AlarmManager` 执行一次非阻塞补偿，恢复连接时取消待执行补偿并通过共享 generation
丢弃在途结果。能力页展示中继连接状态、最近心跳和最近信号时间；该时间表示客户端已收到中继
payload，不表示正文已经通过 poll 拉取或投递完成。

---

## 10. iOS / APNs 预留

iOS 沿用同一份 A1 业务消息契约：`message.id`、正文、时间戳和 behavior metadata 均不变化。
iOS 客户端不自持 ntfy SSE，而由 APNs 唤醒并投递；后端的消息创建、A1 分配、补偿队列和行为裁决
保持不变，仅传输适配器从 ntfy topic 发布切换为 APNs device token 发布。

因此“业务发布侧不变”不等于 APNs 无需后端接入：后端仍需 APNs provider 凭证和传输适配器，
但不应为 iOS 另造一套消息结构或去重语义。

---

## 11. 待确认清单

在与后端对齐前，以下条款不应作为实现依据：

- [x] 后端已实现 signal-only 中继发布：`POST <relay_base_url>/<relay_topic>`，
  `Authorization: Bearer <relay_token>`；payload 不含正文/behavior。
- [x] 补偿队列 TTL、容量上限和淘汰策略：24 小时、最多 500 条，保留最新消息。
- [x] 发布失败策略：5xx/不可达指数退避，总尝试不超过 3 次；401/403 不重试；
  任何发布结果均不影响已写入的补偿队列。
- [ ] ntfy vs 其他中继：后端选定的中继实现及 SSE 事件格式？
- [x] 消息 `id` 与 `seq` 跨中继 signal / poll 完整消息保证相同（A1/G2 前提）。
- [x] Android `decodeRelayMessage` 已切换为 signal → `/mobile/poll?after=<lastSeq>`，
  不再从中继 payload 读取 `content` 或直接投递。
- [ ] iOS APNs 传输适配器与 device token 注册接口？
