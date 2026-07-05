# 架构审计 R3：修复后复查 + Emerald-client 对比 2026-06-13

> 范围：重构后的 `MobileNotificationService.kt`（relay 全文）、`MainActivity.kt` 生命周期、`BackendSecurityPolicy.kt`、`app_shell.dart` 轮询/去重段、manifest；Emerald-client 仅文档（ARCHITECTURE / backend-integration / migration-status / README）。
> 修复质量先说：R1/R2 清单基本都落地了，且做法正确——startForeground 顺序、退避、generation+disconnect、id 去重、modeFor 精确白名单、onTimeout、电池豁免、屏幕文本白名单（`screenTextUploadAllowedPackages`）、闸门测试模式都核过代码。但 relay 是修复期间**新引入**的子系统，带进来一个严重问题和两个中等问题。

---

## 一、仍存在的问题

### S1（严重）：relay 模式下，前台收主动消息进不了聊天界面

证据链：

- `MainActivity.onResume()`：relay 配置时**前台也保持服务运行**（`shouldRunRelayService` → `startMobileNotificationService()`）。
- 服务的投递路径 `consumeMobileMessage → deliverBackgroundMessage → 悬浮窗或系统通知`，**全程不检查 `mobileAppInForeground`**（该 pref 只在 `runOneShotPoll` 用于跳过补偿轮询）。
- Flutter 侧 `_pollMobileIfRelayUnavailable()`：relay `connected` 时**跳过前台轮询**；也没有任何机制读取 relay 已投递的内容（`lastRelayDeliveredAt` 无消费方）。

结果：relay 连接时，用户**正开着聊天界面**，主动消息却变成系统通知（或悬浮窗）；更糟的是若处于静音时段/30 分钟冷却，`handleIncomingMessage` 直接静默吞掉——用户人在 App 里，消息无声蒸发，直到下次重启 App 重载历史才出现。这直接违反你们 README 自己定的原则："前台时只在会话内显示，不额外发系统通知"。

**修复方案（二选一）：**

- **方案 A（简单，推荐先做）**：恢复"前台 Flutter 拉、后台 relay 推"的分工。`onResume` 无条件 stop 服务，Flutter 前台恢复 5 秒轮询（`_pollMobileIfRelayUnavailable` 改为只看"服务是否在跑"而非 relay 状态，或直接恢复 `_pollMobile`）。代价是切前后台时 relay SSE 重连一次，generation+id 去重已经能兜住交接窗口。
- **方案 B（保持服务常驻）**：`deliverBackgroundMessage` 开头检查 `mobileAppInForeground`：前台时不弹通知、不过闸门，把消息写入 prefs 的 `pendingForegroundMessages` JSON 队列；Flutter 现有的 5 秒 timer 顺带读取并清空该队列，追加进会话。注意单写者约定：服务只 append，Flutter 只 drain，用一把跨端约定的"读后清空"原子操作（MethodChannel 一次调用内完成 read+clear）。

无论选哪个，补一条契约测试：前台状态下投递一条 relay 消息，断言它出现在会话且不产生系统通知。

### S2（严重，Android 15 条件触发）：dataSync 前台服务 6 小时配额 → 每天最长 ~18 小时盲区

`onTimeout()` 处理是对的，但恢复策略是 `timeoutRecoveryDelayMs = 24h+5m` 后才排下一次补偿——而且那个补偿本身是 `PendingIntent.getForegroundService`，在配额窗口内同类型 FGS 起不来。设备若是 Android 15+，重度后台使用下每天 relay 只活 6 小时。

**修复**：本应用是自分发（debug signing、不上架），不受 Play 对 `specialUse` 的审核约束——把 manifest 的 `foregroundServiceType` 从 `dataSync` 改为 `specialUse`（`FOREGROUND_SERVICE_SPECIAL_USE` 权限 + `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` 说明），常驻 SSE 即不再受 6 小时配额。dataSync 路线保留给将来上架场景再议。改动半天内。

### M1（中等，隐私）：消息正文明文过第三方 relay

`isAllowedRelayUrl == isAllowedBaseUrl`，任何 HTTPS host 都放行，包括公共 ntfy.sh。`decodeRelayMessage` 拿到的是完整消息 JSON（含 content）——叶瑄的主动消息正文会明文过中继服务器，安全性只靠 topic 名熵值 + 可选 token。自托管 relay 没问题；公共 ntfy 则等于把私密对话内容交给第三方。

**修复（按成本递增）**：a) 文档 + 设置页警告"建议自托管或使用高熵私密 topic + 访问 token"；b) 后端 relay 发布时只推"有新消息"信号（不带正文），手机收到信号后回源 `/mobile/poll` 拉正文——这同时把 relay 降级为纯唤醒通道，隐私和 ack 问题一起解决，**建议与后端 ack 改造打包成同一批契约变更**；c) 对称加密 payload（后端和手机共享密钥）。b 是结构上最优解。

### M2（中等）：`RelayConnectionStatus.connected` 不校验心跳新鲜度

`connected => connectionStatus == 'connected'`，字符串状态由服务写入。服务被 OEM 硬杀（不走 `onDestroy`）时状态滞留 "connected"。当前被 `onResume` 重启服务所缓解（重启会改写状态），但 S1 方案 A/B 都依赖这个判断的真实性。**修复**：getter 改为 `connectionStatus == 'connected' && lastHeartbeatAt 距今 < 3 分钟`（服务侧每条 SSE 行都打心跳，relayReadTimeout 90s，3 分钟阈值安全）。三行改动，建议无论如何都做。

### 小项（打包半天）

- `seenMobileMessageIds` 实际是 Flutter 与服务**双写**同一 key（服务在 `consumeMobileMessage`，Flutter 在 `_pollMobile`），靠前后台时序互斥。可接受，但与你们"单写者"的自述不符——至少在文档里写明这是有意的时序互斥，或统一由 MethodChannel 提交给原生侧合并写。
- 无 `RECEIVE_BOOT_COMPLETED`：重启后 relay 服务和补偿闹钟全部消失，直到手动打开 App。自用可接受，建议在能力页显示"上次活跃时间"让用户能察觉。
- 未声明 `USE_EXACT_ALARM`/`SCHEDULE_EXACT_ALARM` → `canScheduleExactAlarms()` 恒 false，走 inexact 分支（6h 补偿无所谓，24h 恢复可能漂移数十分钟）。自分发 App 可直接声明 `USE_EXACT_ALARM`。
- `notificationIndex++` 在 relay/poll 双线程下非原子——改 AtomicInteger，一行。

### 对"ack 保留口"的回应

判断正确，这确实是后端契约问题。但建议把范围扩大一点再去找后端谈：`/desktop/chat` 响应里有 `turn_id`/`msg_id`（Emerald-client 文档明确：HTTP msg_id = WS msg_id，桌面端靠它对账），而手机端 `BackendChatResponse` **丢弃了这两个字段**，同步回复去重只能靠内容指纹。如果后端在 mobile queue/relay 消息里带上同一个 `msg_id`，手机端就能用 id 对账同步回复，内容指纹彻底退役。所以找后端的清单应该是一批三件：① `after=<id>` cursor + `POST /mobile/ack`；② mobile queue 消息携带与 `/desktop/chat` 一致的 `msg_id`；③（若采纳 M1-b）relay 只推信号不推正文。一次契约变更解决三个 hack。

---

## 二、Emerald-client 对比：手机端缺什么

只读了桌面端文档。按"值得补/可以补/不该补"分三档。

### 值得补（低风险，纯只读新增）

| 能力 | 桌面端现状 | 手机端缺口 | 风险 |
|---|---|---|---|
| 情绪状态 `GET /mood/state` | SubStatus 展示持久 mood（两轮漂移制） | 手机只有聊天响应里的瞬时 emotion | 无，只读 |
| 活动状态 `GET /activity/current` | SubStatus 展示"在读书"等身体动作 | 完全没有 | 注意：该 GET **有副作用**（必要时自动切换活动，15-45 分钟间隔）。双端轮询会让切换判定更频繁。建议手机端低频轮询（≥60s）或后端确认幂等 |
| 潜意识面板 `GET /debug/user-hidden-state` | Dream 潜意识 tab，只读 | 手机 Dream 页没有 | 无，只读；开发者字段显隐复用 `/dream/settings.display.physiological_arousal`，照搬即可 |
| Dream 入梦模式（sandbox/scenario/mirror + `script_id`） | 偏好"世界"页，`POST /dream/enter` 带 `dream_mode` | 手机端入梦不带模式 | 无新接口；注意桌面约定"梦境进行中不可切换"，手机端要同样禁用 |
| chat-log `turn_id`/`ts` 消费 | 用 `ts` 推进 wake 游标、`turn_id` 对账历史 | 手机端读 chat-log 但丢弃这两个字段 | 无；这是上面 msg_id 对账的同一族工作 |
| Dream HUD v1.1 字段、梦境流动摘要 | 状态 Sidebar 全量展示 | 手机 DreamStateStrip 子集 | 无，只读 |

### 可以补但要先和后端定规则

- **角色头像后端化**：桌面端走 `POST /settings/characters/{char_id}/avatar`，头像存后端 `data/runtime/characters/`。手机端目前是本机头像（README 里"作用域待定"的老问题）。补上即可统一全端头像源——但要先决定：手机端的本机裁切头像是覆盖上传，还是只读拉取后端头像 + 保留本机覆盖。建议"拉取后端为默认 + 本机覆盖可选"，避免两端互相覆写。
- **`POST /desktop/wake`（last_seen 游标）**：桌面端用它做"回来了"唤醒。手机端如果也调，**两个客户端各自推进 last_seen 游标会互相干扰**（桌面刚 wake 过，手机又 wake，或互相吞掉对方的未读窗口）。要么后端给游标分端（`wake?client=mobile`），要么手机端不接 wake。先问后端，别直接抄。

### 不该补 / 必须绕开的坑

1. **`/ws/desktop` 绝对不能复用**。桌面文档写明：后端只保留一个 WS 连接，**新连接会踢掉旧连接**。手机若连 `/ws/desktop`，等于上线即踢掉桌宠。手机端的实时通道就是 mobile queue + relay，已经是正确架构；如果未来想要 WS，必须让后端开 `/ws/mobile` 或多连接支持，那是后端任务。
2. **`/sensor/realtime` 是 last-write-wins 单字典，双端现在就在互相覆盖**。桌面文档明示："无 source 分桶，最后写入者赢"。桌面 Rust sensor 按 30s 窗口推键鼠数据，手机（开关开启时）前台每 45s / 后台每轮推屏幕上下文——两端同时在线时，`sensor_aware` 看到的快照在"PC 键鼠"和"手机屏幕"之间反复横跳，客观评分基于哪份纯看时序。这不是移植新功能的风险，是**已经存在的跨端 bug**，值得在找后端谈 ack 时一并提：`/sensor/realtime` 按 `sensor_version`（或显式 source 字段）分桶，sensor_aware 合并消费。手机端在后端改好前的临时缓解：手机快照里 `input` 全是 0（已如此），后端至少可以按"有键鼠数据的优先"做合并——但这是后端逻辑，手机端不要试图绕。
3. **桌面 action 体系（minimize/open_url/notify/media）不要照搬**。手机端已有自己的 behavior 白名单 + 悬浮窗确认体系，语义边界不同（桌面 action 是无确认直接执行的低风险动作）。两套各自演化，靠后端 behavior metadata 当公共语言。`pet_emote`/`execute` 等 sensor_aware 产物的 `behavior_id`（如 `late_night_lock_hint`、`sit_long_force`）将来会下发到手机——注意这些 id 是**语义标签不是枚举**，再次印证 modeFor 白名单"未知一律降级普通通知"这条规则必须守住。
4. **message_segments 暂缓**。桌面端靠 WS `message_segments` + msg_id 关联更新气泡；手机端没有 WS，现在用换行切分本地模拟。等 msg_id 契约落地后，可以让后端把 segments 放进 mobile queue 消息体，一步到位；现在抄只会多一套对不上号的伪实现。

### 移植顺序建议

1. 先做零风险只读三件套：mood + activity（低频）+ 潜意识面板，手机端"状态感"立刻对齐桌面。
2. Dream 模式选择（复用现有 enter 接口）。
3. 等后端契约批次（ack + msg_id + relay 信号化 + sensor 分桶 + wake 分端）落地后，再做对账重构和 segments。
4. 头像后端化放最后，先定覆盖规则。

---

## 三、一句话总结

修复质量是合格的，R1/R2 的事故源都消掉了；现在的头号问题是 relay 这个新子系统"后台做对了、前台没接回来"（S1），以及它带来的平台配额（S2）和隐私（M1）问题。Emerald-client 那边真正要警惕的不是"缺功能"，而是三个共享资源的单实例假设：WS 单连接、sensor 单字典、wake 单游标——手机端接任何一个之前都要先让后端把"多客户端"语义补上。
