# Mobile Channel 协议现状

mobile channel 是后端向手机端投递主动消息的通道。手机端不决定“什么时候该主动说话”，只消费后端已经裁决好的消息和 metadata。

## Scope boundary

`/mobile/*` is the mobile activation, polling, acknowledgement, and proactive-delivery surface.
It is **not** the foreground user-chat endpoint in the current Flutter client: `BackendClient.sendChat()`
POSTs `/desktop/chat` with the mobile Bearer token. This is the current shared owner-chat contract;
do not switch it to `/mobile/chat` without a separately versioned backend/client change.

## 基础消息

当前手机端兼容的字段：

```json
{
  "id": "message-id",
  "seq": 42,
  "content": "消息正文",
  "user_id": "<owner_user_id>",
  "timestamp": 1779026400,
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

1. 追加为 `him` 消息。
2. 持久化 `seenMobileMessageIds`。
3. 调用 `POST /mobile/ack {"ack_seq": <本批最大 seq>}`。
4. ack 成功后持久化共享的 `lastAckedSeq`；失败则不推进游标，下次重收时按 `id` 去重。
5. 不论 metadata 是否表示 overlay/direct action，都只显示在会话内，不额外弹系统通知或悬浮窗。

同步 chat 响应会记录 `msg_id`（兼容 `turn_id`）；poll 返回相同 `id` 时按 id 丢弃重复副本。
内容指纹只用于同步响应或 poll 消息缺少 id 的旧后端兜底。

前后台切换窗口依赖已有 generation 与同一 `message.id` 去重；允许后台 relay SSE 重连一次，
无需依据 relay connected 状态丢弃 Flutter 已拉取的结果。

## 后台消费

后台服务以 ntfy SSE 中继为主路径。中继明确订阅失败或连续断开 15 分钟后，通过
`AlarmManager` 安排一次非阻塞补偿拉取；完成后最多每 6 小时续约一次，恢复中继后取消：

```text
GET /mobile/poll?limit=20&after=<lastAckedSeq>
```

中继 signal 不直接投递；收到后立即按 `lastAckedSeq` 调用 poll 拉取完整消息。signal 即时 poll 和
断线补偿 poll 进入同一条 `message.id` 去重、behavior 和通知闸门管线。收到完整消息后：

1. 如果 behavior 可映射为悬浮窗，优先弹悬浮窗。
2. 否则走普通通知。
3. 普通通知受静音时段和 30 分钟冷却控制。

补偿 poll 消费时会先持久化 `seenMobileMessageIds`，再 ack 本批已处理的最大 `seq`，最后单调推进与
Flutter 前台共用的 `lastAckedSeq`。ack 失败不推进游标。

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
