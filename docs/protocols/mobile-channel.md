## 聊天交接根因修复（2026-10-08）

工单 27 / 后端 271：历史 plain/display 与 HTTP/poll 使用同份 ledger 显示正文；刷新保留失败状态及原请求，assistant 成功证据优先于迟到 HTTP 错误；前台周期交接 native pending 并补偿 poll。Android 去掉固定 30 分钟冷却，重连立即补拉、有界分页排空；pending 500 条且满载拒绝 ack，不静默淘汰。既有 getBackgroundPollStatus 新增可选 pendingCount/pendingLimit，能力检查只读展示；AppSettingsStore、PlatformSettingsChannel 和 MainActivity 同步。旧测试模式方法/偏好仅兼容。详见 [根因复查](../mobile/chat-handoff-2026-10-08.md)。真机/Doze/真实模型仍 observe，consume 崩溃窗口与后台产物元数据仍 open。
## 聊天恢复补全（2026-10-07）

既有 native pending envelope 增加可选 request_id，Android toJson/toMap 与 Dart 解析同步；它只用来确认原逻辑发送，不作为 msg_id/turn_id。seen 表示通知投递，不证明页面已显示；启动、恢复、通知点击按页面身份回放 pending。chat-log entries 的可选 ts/user_ts 提供精确排序；tool_activity 可带 turn_id/request_id。POST/mobile/chat、poll/ack/TTL、SharedPreferences 与 MethodChannel ABI 不变。请求 ID 改为 req_ 加 32 位随机 hex，仍符合原 opaque 字符串校验。同作用域 grant 重绑不重开 receipt 执行空间。

# Mobile Channel 协议现状

## Brief 253.6：转写语调关联

POST /transcribe（chat）保留 text，新路径可返回 tone/audio_perception_id；POST /mobile/chat
增加可选 audio_perception_id。客户端按未编辑文本、相同 token 和 5 分钟有效期一次使用；
后端再绑定 owner、角色、mobile 通道和文本摘要。编辑/跨作用域/过期/重复时仅丢语调，文字照常发送。
缺字段兼容旧后端；不改变 mobile poll/ack、relay、通知与录音权限。

聊天情况（2026-09-12）只读独立 `/chat-log/stats/calendar`，不扩展 mobile 消息字段、msg_id/turn_id、去重、ack、TTL 或通知。`calendarPalette` 仅通过本机 appearance prefs 通道保存，默认 jade，不上传后端；Dart 与 Android 读写键同步。

工单 19（2026-09-12）：通知点击/恢复先重读正式聊天历史，再 catch-up；后台已 ack 的内容可从历史展示。消费历史现有 assistant_display_text，不改 mobile HTTP 字段、scope、msg_id/turn_id、seen、ack 或 TTL。自己消息可作为原 reply_to 引用目标；复制/全选和思考外观不改协议。旧历史无字效字段则保留纯文本。

## IME awareness (2026-09-11)

Backend-owned `ime_ingest` / `ime_awareness` flags and `ime_judge` routing are managed in the admin UI.
IME Android owns recording, upload and realtime batching switches. This client keeps the existing proactive
message/notification path; no new native switch, raw IME read permission, WS payload or ack protocol.
Physical device delivery remains observe. Backend contract: docs/ime-ingest.md.


## 生活记录队列边界（2026-09-17）

生活记录使用独立 `/life-records/*` 与 native `presence_mobile/life_records`。
不往 mobile durable queue 写识别任务，不使用 `ack_seq`，不改变 chat/poll/ack/relay 字段。
记录关联键是 record_id + operation_id，版本为 revision；操作确认后才清本机 outbox。
字段、scope、日期/金额、图片保留期、角色读取权限与观测端点见
[`Emerald-presence/docs/life-records.md`](../../../Emerald-presence/docs/life-records.md)。
手机状态表与冲突规则见 [`../android/native-capabilities.md`](../android/native-capabilities.md)。
真机拍照/Doze/识别联调仍 observe。

MCP is backend-only and is not part of the desktop/mobile client transport contract.

## 本机外观设置通道

`presence_mobile/settings` 还承载不进入后端的本机外观设置。Flutter 通过
`pickChatBackgroundImage` 选择图片，裁切后的 PNG 与 `blur`（0-24）和 `opacity`
（0.35-1）由 `saveChatAppearance` 保存；`getChatAppearance` 启动时读取，
`deleteChatAppearance` 恢复默认。图片保存在 Android `filesDir`，不会上传到后端。

mobile channel 是后端向手机端投递主动消息的通道。手机端不决定“什么时候该主动说话”，只消费后端已经裁决好的消息和 metadata。

三仓接口总账（含 `/mobile/*`、`/sensor/*`、relay、桌面 WS、Tauri IPC 和设置/观测闭环）见
`Emerald-presence/docs/three-repo-interface-catalog.md`。

Appearance preferences use the same `presence_mobile/settings` channel via `getAppearancePrefs` / `setAppearancePrefs`. `nightSilent` remains readable/writable for compatibility and no longer suppresses notifications; fixed 23:30–06:30 quiet hours were removed. `proactiveRate` is intentionally not exposed because there is no backend scheduler field or local consumer.

传感器相关的 `presence_mobile/settings` 方法保持 `readBatteryPercent` 兼容语义，并新增
`readBatteryStatus`，返回 `{percent: int?, charging: bool?, plugged: string?}`。
`plugged` 只接受 `ac`、`usb`、`wireless`、`none`；无法读取的字段保持 `null`，Dart
`BatteryStatus` 不把未知值猜成 `false`。它只用于前台 30 分钟周期的 `/sensor/push`，不新增
常驻 receiver 或用户可见开关；后端接收与 prompt 消费需由后端仓库另行闭环。

ABI: do not rename `SharedPreferences("yexuan_memery")`. Current channels stay
`presence_mobile/settings`, `presence_mobile/life_records`, and
`presence_mobile/screen_observation`. This protocol page is the current mobile
channel authority; design notes in `../mobile/background-notification-design.md`
cross-reference it. P2-3 旧 6 小时补偿阈值已失效：中继断线 1 分钟后补偿，之后每 15 分钟。

## Scope boundary

`/mobile/*` is the mobile foreground-chat, activation, polling, acknowledgement, and proactive-delivery surface.
`BackendClient.sendChat()` POSTs `/mobile/chat` with the mobile Bearer token. It shares the owner-chat
Pipeline with `/desktop/chat`, while retaining mobile provenance, mobile-safe probe tools, and an independent
durable mobile mirror for the assistant reply.

### 本机会话角色与共享 cursor（2026-09-18，consumer current）

- 本机 Reality 会话角色按 `origin|owner` 持久化（`getSessionCharacterId` /
  `setSessionCharacterId`），与服务器 `active_character` 分离；资料页切换不再 PATCH
  全局 active。角色名/头像仍不是执行授权。
- 发现：`GET /auth/whoami` `capabilities.session_scope="v1"`。缺失则本地
  `session_scope_unsupported`，禁止发送，禁止静默发给 live active。
- 绑定：`POST /v1/sessions` `{char_id, domain: reality}`。后续 Reality 写/读用
  `X-Presence-Session`；不要把 `char_id`/`session_id`/`request_id` 塞进无 session
  的 legacy `/mobile/chat`（旧服务端会忽略并发给当时 active）。
- chat/upload 仅在有 session 时带 `request_id`（30 分钟 receipt correlator，不是
  `msg_id`/`turn_id`）。该 ID 绑到同一逻辑发送；失败气泡重试必须复用，不得重新
  mint。202 `in_flight`、503 `execution_outcome_unknown`、
  409 `request_payload_conflict` 不当成功；超时/未知结果保留原气泡，由用户用同一
  ID 再试。`session_not_found` 可重绑后复用同一 `request_id`；角色撤权/不可用
  fail-loud。上传重试仍提交本机附件，服务端 completed receipt 应回放原 turn，不
  再识别/导入。
- Delivery cursor 仍是 **origin+owner 节点级共享**（见 `MobileDeliveryStateStore`），
  不按角色分 cursor。前台 poll 解析可选 `char_id`：匹配本机会话的消息进入当前聊天；
  其他角色消息经 `stashPendingMobileEnvelopes` 写入 pending，再统一 ack，避免共享
  cursor 推进时丢弃其他角色条目。consume 仍按 char 过滤。
- 后台通知标题优先信封 `char_id` 的分槽备注名/头像；点击只设
  `pendingOpenLatestMessage`，不切换本机会话。Dream 仍是独立域，不复用 Reality
  pending 或 Reality session grant。

## 基础消息

当前手机端兼容的字段：

```json
{
  "id": "message-id",
  "seq": 42,
  "content": "消息正文",
  "user_id": "<owner_user_id>",
  "timestamp": 1779026400,
  "char_id": "optional-speaker-character",
  "behavior": {
    "kind": "overlay_message",
    "delivery": "overlay",
    "level": "attention_grab",
    "behavior_id": "presence_ping"
  }
}
```

Flutter `MobilePollMessage` 会读取：

- `id`
- `seq`
- `content`
- `user_id`
- `timestamp`
- `char_id`（可选；缺省视为无作用域，当前会话可显示）
- `behavior.kind`
- `behavior.delivery`
- `behavior.level`
- `behavior.behavior_id`

## 前台消费

前台每 5 秒读取 Android 原生后台服务运行状态。服务仍在退出过程中时暂时跳过；服务停止后请求：

```text
GET /mobile/poll?limit=20&after=<lastAckedSeq>
```

收到消息后：

1. 先检查 poll JSON 的 `ok` 与 `active`；响应始终可读取 `messages`、`cursor` 和可选 `error`。`ok:false` 或 `active:false` 不是成功，即使 HTTP 状态为 200。
2. 有身份的消息按 `id`/`turn_id` 去重后追加为 `him` 消息；history 已有相同身份不重复。
3. 经 native `MobileDeliveryStateStore` 合并持久化 `seenMobileMessageIds`（merge，非整快照覆盖）。
4. 调用 `POST /mobile/ack {"ack_seq": <本批最大 seq>}`。
5. ack 成功后单调推进共享的 `lastAckedSeq`；失败或落盘失败都不推进游标，下次重收时按 `id` 去重。
6. 不论 metadata 是否表示 overlay/direct action，都只显示在会话内，不额外弹系统通知或悬浮窗。
7. poll 必须绑定当前 origin+owner；迟到结果不得写入当前作用域。角色切换不重置节点级 cursor。

同步 chat 响应记录传输 `msg_id`（有 persisted turn_id 时两者相等，否则 `msg_id` 为 minted
transport，`turn_id` 可空）。poll 返回相同 `id` 时按 id 丢弃重复副本。思考读取仍只用明确
`turn_id`，不用 `msg_id` 代替。内容指纹只用于同步响应或 poll 消息缺少 id 的旧后端兜底。

前后台切换窗口依赖已有 generation 与同一 `message.id` 去重；允许后台 relay SSE 重连一次，
无需依据 relay connected 状态丢弃 Flutter 已拉取的结果。

## 后台消费

后台服务以 ntfy SSE 中继为主路径。中继明确订阅失败或连续断开 1 分钟后，通过
`AlarmManager` 安排一次非阻塞补偿拉取；完成后每 15 分钟续约。SSE 保持连接时也每 15 分钟执行一次
安全 poll，用于限制 relay 单个 signal 丢失时 durable queue 的滞留；应用回前台后取消：

```text
GET /mobile/poll?limit=20&after=<lastAckedSeq>
```

中继 signal 不直接投递；收到后立即按 `lastAckedSeq` 调用 poll 拉取完整消息。signal 即时 poll 和
断线补偿 poll 进入同一条 `message.id` 去重、behavior 和通知闸门管线。收到完整消息后：

1. 如果 behavior 可映射为悬浮窗，优先弹悬浮窗。
2. 否则走普通通知。
3. 普通通知受静音时段和 30 分钟冷却控制。

补偿 poll 消费时由 `MobileDeliveryStateStore.acceptIncoming` 原子写入 seen+pending envelope
（id/seq/time/turn_id + origin/owner/char_id），再 ack 本批已处理的最大 `seq`，最后单调推进
`lastAckedSeq`。ack 失败不推进游标。通知点击走 `consumePendingMobileEnvelopes`；缺 ID 的旧正文
一次性丢弃，不冒充身份回放。channel 缺失不得中断 catch-up，仍刷新正式历史。

## behavior 映射

后台原生服务使用**精确白名单**路由，不做子串匹配。路由逻辑唯一实现在 Kotlin
`MobileNotificationService.modeFor()`；Flutter 前台忽略 behavior 的系统投递语义，只把消息写入会话流。

### behavior_id 精确白名单（优先级最高）

| `behavior_id` | 浮窗模式 | 说明 |
|---|---|---|
| `lock_screen` | lock | 锁屏确认浮窗 |
| `lock_screen_confirm` | lock | 锁屏确认浮窗 |
| `takeout_order` | order | 外卖/购物确认浮窗 |
| `takeout_overlay` | order | 外卖/购物确认浮窗 |
| `presence_ping` | message | 悬浮短句（存在感提醒） |
| `phone_control_task` | control | 手机自动化任务起手确认浮窗；用户点"开始"后转交 `PhoneControlService` 循环；`behavior.task_id`/`behavior.task` 见 `docs/protocols/phone-control-protocol.md` |

### kind 精确白名单（behavior_id 未命中时）

| `kind` | 浮窗模式 |
|---|---|
| `lock_screen_confirm` | lock |
| `takeout_overlay` | order |
| `overlay_message` | message |

### 结构字段回退（kind 也未命中时）

`delivery=overlay`、`level=attention_grab`、`level=direct_act` 均映射为 `message`（悬浮短句）。

### 未知 behavior_id 的默认行为

behavior_id 或 kind 不在上述白名单中，且结构字段也无法匹配时，**一律降级为普通通知**，不弹任何浮窗。

### requires_confirmation 字段

```json
"requires_confirmation": true
```

后端可在 behavior 对象中附带此字段，表示该行为需要用户手动确认才会执行。手机端不以此字段决定路由（路由由 behavior_id / kind 白名单决定），但 lock 和 order 模式的浮窗 UI 本身已内置二次确认：

- **lock 浮窗**：需点击"替我锁屏"→ 再点"再点确认锁屏"，共两步。
- **order 浮窗**：需点击"去购物车"，最终支付仍需用户在外卖 App 内确认。

## 安全边界

- 普通主动消息不能自动升级为锁屏、全屏、悬浮窗或辅助点击。
- 锁屏必须用户点击确认。
- 购物/外卖可以打开 App 或尝试进购物车，但不自动支付、不提交订单。
- 截图/OCR/视觉识别未接入；未来接入必须是明确开关或手动确认。

## Optional inline display text (2026-09-09)

Mobile `/mobile/chat` and upload responses add optional `display_text` alongside plain `reply`; poll items add the same optional field alongside plain `content`. The copy contains desktop-compatible hl/big/sm tags. Missing, wrong-type or mismatching display copies fall back to canonical text. `BackendChatResponse` and `MobilePollMessage` carry the optional string; `ChatMessage` preserves it across settling/copying. Copy, reply-to, TTS, notification and fingerprints continue using canonical text. IDs, ack/cursor persistence, TTL and relay are unchanged. Legacy clients may ignore this field. No native MethodChannel change or extra permission is required.

The Flutter parser mirrors desktop paired-tag rules (up to 200 characters, no nested angle brackets); hl uses the theme red color (danger palette slot) at weight 600, big uses 1.18x, sm .85x with .8 alpha. Parsing before reveal prevents half tags flashing. Paragraph slicing preserves styles spanning newlines. Old plain-text history has no display copy; Dream/group transport is not extended by this reality contract.
# 手机只读历史与思考补充（2026-09-11）

手机下拉刷新重读 `/chat-log/dates` 与日期详情，随后沿既有 mobile catch-up/ack 路径执行。历史补回不伪造 mobile seq 或 ack。思考仅使用明确的 `turn_id` 读取 `/chat/turns/{turn_id}/reasoning`；不会将 `msg_id` 当作 canonical turn_id。未增加 mobile 请求/投递字段。

## 聊天产物（253.3）

后端 mobile/chat 与 mobile/poll 可附带 artifacts[]（id、filename、mime、size、download_url、previewable、可选 preview_url），不含正文与绝对路径；既有 ack/TTL 不变。下载与预览为 chat scope，路径 /chat/artifacts/{id} 与 /chat/artifacts/{id}/preview。手机解析该字段（`ChatArtifact`）并渲染文件卡片：预览走 `GET /chat/artifacts/{id}` 取文本应用内查看，下载经系统另存为；客户端只按 id 拼固定路径，不信任任意 download_url。历史 `GET /chat-log/{date}` entry 也带 `artifacts[]`（后端按 turn_id 持久化元数据）。聊天原图不走产物路径，而走 `GET /chat/media/{sha256}`；身份为 sha256，不把磁盘路径当 URL。
