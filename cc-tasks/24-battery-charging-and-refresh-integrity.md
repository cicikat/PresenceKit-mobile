# 24 — 充电状态上报与刷新对账完整性

日期：2026-09-30。状态：open。
来源：用户报告三件事 —— (A) 电量要带「正在充电」让角色看到；(B) 刷新经常吞消息；(C) 自动刷新把刚发的富消息（回复引用/图片/文件/表情）刷成普通文本。
基线：工作树 `bf4d217`。执行顺序：24/A 与 24/B、24/C 可并行；24/C 依赖 24/B 的对账改造（同一函数），建议 B→C 串行落在同一轮。

行号为基线导航，施工时按符号定位。每完成一项立刻把 `- [ ]` 改成 `- [x]` 并补证据（文件:行号 / 测试名 / 提交号），不要全做完再回填。

---

## 根因结论（已核实）

### A. charging 信息在最底层就没被采集

| 层 | 位置 | 现状 |
|---|---|---|
| Android 采集 | `android/app/src/main/kotlin/com/presencekit/mobile/SensorAccess.kt:24-28` | 只读 `BATTERY_PROPERTY_CAPACITY` 返回 `Int?`，**完全没读** `BATTERY_STATUS_CHARGING` / `EXTRA_PLUGGED` |
| MethodChannel | `MainActivity.kt:652-654` | `readBatteryPercent` 只回一个 Int |
| Dart 门面 | `lib/services/app_settings_store.dart:1226`、`lib/services/device_services.dart:172` | 透传 Int? |
| Dart 上报 | `lib/controllers/device_controller.dart:126-145`（30 分钟一次，`:83-85`） | 只传 `battery` |
| HTTP 契约 | `lib/services/backend_client.dart:900-916` `POST /sensor/push` | body 仅 `steps`/`battery`/`screen_sessions` |
| 后端接收 | `Emerald-presence/admin/routers/sensor.py:83-132` | 校验并落 `phone_sensor_log` / `phone_sensor_today`，无 charging 字段 |
| 进 prompt | `Emerald-presence/core/prompt_builder.py:745-771` 层 3.7 | 拼 `电量{n}%`，角色看不到是否在充电 |

结论：charging 是**全链路缺失**，不是某一层丢了。需要 Kotlin → Dart → HTTP → 后端落盘 → prompt 五层同时加字段。

### B. 吞消息：`reconcileChatHistory` 会丢弃尾部未匹配的本地消息

`lib/controllers/chat_history_reconciliation.dart:21`：

```dart
if (!(live ? i < lastMatch : item.retainOnRefresh)) continue;
```

`live == true` 时（source 是 `sent`），本地消息**只有在它后面还有别的本地消息匹配上了远端**（`i < lastMatch`）才会被保留；否则直接 `continue` 丢弃。而 `lastMatch` 是所有匹配项的最大远端下标，尾部最新的几条必然 `i >= lastMatch`。

触发链：
1. poll 收到新回复 → `_appendMobileMessages`（`chat_controller.dart:1107-1184`）构造 `ChatMessage(role:'him', ...)`，**没有设 `retainOnRefresh`**（`:1126-1133`、`:1312-1321`），默认 false（`app_models.dart:575`）。
2. 后端 chat log 落盘比 poll 投递慢 → 这一轮 `/chat-log/{date}` 里还没有这条 → `_matches` 匹配不到。
3. 它在 `sent` 尾部 → `i >= lastMatch` → 被丢。
4. 它的 id 已经进了 `_seenIds` 并 ack 了 seq（`:993-1001`、`:1056-1071`），poll **不会再投一次** → 永久消失。

用户猜的「HTTP 和 WS/poll 到达时间不一样导致竞态」方向正确，但准确说不是两个渠道叠加出幽灵层，而是**poll 渠道的消息被历史对账单方面丢弃**。`_sameVisibleHistory`（`:820`）只比较字段、不会救回被丢的条目。

同一函数还有第二条丢弃路径：`_matches` 跳过 `item.sticker != null`（`:76`），所以表情包永远匹配不上，再被 `i < lastMatch` 判掉 → 刷新后表情消失。

### C. 富消息降级：匹配成功时用远端文本覆盖本地富载荷

`chat_history_reconciliation.dart:36-58`，`keepImage` 只在 `item.attachments.isNotEmpty` 时为 true：

- `text: keepImage ? item.text : remote[found].text` —— 非附件消息一律被远端纯文本覆盖。
- `displayText: remote[found].displayText ?? item.displayText` —— 远端 `assistant_display_text` 由 `Emerald-presence/admin/routers/chat_log.py:360` 从 `assistant_event.visible_text` 投影，事件还没落盘时为 null，此时才回退本地值；但一旦远端给了一个「已清洗」的值就覆盖本地 inline display。
- `sticker: item.sticker` 虽然保留，但该条走不到匹配分支（见 B）。
- `quotedText` / `quotedLabel`（回复引用）只在匹配分支保留；未匹配被丢弃时一起消失。
- 上传预览：`:100` `if (item.attachments.isNotEmpty && candidates.length != 1) continue;` —— 候选不唯一就不匹配，再被 `i < lastMatch` 判掉，图片/文件气泡整条消失或退回远端的 `📎 文件名` 纯文本行。

所以「刷成普通文本」= 本地富气泡被丢 / 被远端行覆盖后，只剩后端日志里的纯文本表示。

### D. 没有重复渲染层

`lib/widgets/chat_widgets.dart:81-93` 用 `history.length + sent.length` 线性索引同一个 `ListView`，两个 list 不重叠渲染；`_historyContainsIdentity`（`:1443`）按 `turnId` 去重。**不存在幽灵层**，问题是丢弃而不是重复。

---

## 24/A — 充电状态全链路（P1，可与 B/C 并行）

跨仓：需要同时改 `Emerald-presence`（后端接收 + prompt）。按 AGENTS「三面闭环检查」执行。

- [ ] A1 Kotlin 采集：在 `SensorAccess.kt` 新增读取充电状态，返回 `charging: Boolean?` 与 `plugged`（ac/usb/wireless，取不到则省略）。用 `BatteryManager.BATTERY_STATUS_CHARGING|BATTERY_STATUS_FULL` 判定；API 23+ 可直接 `bm.isCharging`，低版本回退 `registerReceiver(null, IntentFilter(ACTION_BATTERY_CHANGED))` 读 `EXTRA_STATUS` / `EXTRA_PLUGGED`。取不到返回 null，不要编造 false。
  - 验收：`SensorAccess.kt` 有新函数；插拔充电器各读一次日志值正确（真机）。
- [ ] A2 MethodChannel：`MainActivity.kt:652` 的 `readBatteryPercent` 保持兼容不改语义，新增 `readBatteryStatus` 返回 `{percent:int?, charging:bool?, plugged:String?}`；同步 `docs/android/native-capabilities.md`（强制规则 6）。
- [ ] A3 Dart 门面：`app_settings_store.dart` + `platform_settings_channel.dart` + `device_services.dart` 三处同步新增（强制规则 4），加一个 `BatteryStatus` 值对象放 `lib/models/`，不要返回裸 Map。
- [ ] A4 上报：`device_controller.dart:126-145` 改用新门面；`backend_client.dart:900-916` body 增加 `charging` / `plugged`（仅非 null 时带）。保留「battery 和 steps 都为 null 就不发」的短路，但 charging 单独有值时应当发。
- [ ] A5 后端接收：`Emerald-presence/admin/routers/sensor.py` 校验 `charging`（bool，非法 422）和 `plugged`（白名单 `ac|usb|wireless|none`），写入 `phone_sensor_log` 明细与 `phone_sensor_today` 摘要；`/sensor/status` 快照自动带出即为只读观测端点（AGENTS 强制规则 11 要求观测同单提供）。
- [ ] A6 进 prompt：`Emerald-presence/core/prompt_builder.py:745-771` 层 3.7，charging 为 true 时把 `电量85%` 拼成 `电量85%（正在充电）`；charging 为 null 时保持原文案不变，不要输出「未充电」这种噪声。
- [ ] A7 后端回归测试：在 `Emerald-presence/tests/` 加 `/sensor/push` 的 charging 用例（合法 true/false/缺省、非法值 422、落盘字段、层 3.7 文案含/不含充电后缀）。
- [ ] A8 手机端测试：`test/` 加 `pushSensorData` 请求体用例（charging 为 null 时不带该 key；为 true/false 时带）。
- [ ] A9 三面闭环与文档：更新本仓 `docs/backend/integration.md`、`docs/protocols/mobile-channel.md`（强制规则 5）、`docs/android/native-capabilities.md`，同步 `Emerald-presence/docs/three-repo-interface-catalog.md:364` 的 `/sensor/push` 行补 charging 字段。回查桌面端 `Emerald-client`：桌面不消费手机电量，记一句「无桌面影响」即可，不要在桌面加设置。
- [ ] A10 明确不做：不加用户可见设置开关（电量上报已由既有 sensor 上报开关统一管辖），不加前台常驻电量监听 receiver（30 分钟周期读取足够，避免耗电）。若结论有变要写进 `docs/known-issues.md`。

## 24/B — 刷新不再吞消息（P0）

落点集中在 `lib/controllers/chat_history_reconciliation.dart` 与 `chat_controller.dart` 的消息构造处。

- [x] B1 本地消息一律标记「尚无服务器行」：`_appendMobileMessages`（`chat_controller.dart:1146`、`1160`）、`_appendSegments`（`:1337`）、`_appendSticker`（`:1350`）、`send` 的用户气泡（`:274-281`）构造时全部带 `retainOnRefresh: true`。
- [x] B2 放宽保留规则：`chat_history_reconciliation.dart:21` 的丢弃规则改为只作用于仍在飞行中的 live 行（它们留在 `sent` 里，屏幕上仍可见、retry 仍可达）；已进 `history` 的投递行凭 `retainOnRefresh` 一律保留，不再因为落在尾部被删。保留位置仍按 `next ?? preceding+1` 计算。
  - 偏差说明：工单原文要求「未匹配的本地消息默认保留」，含 live 行。实测把未匹配 live 行提升进 `history` 会破坏 retry / reveal 契约（`chat_recovery_upload_test.dart`、`mobile_catchup_state_test.dart` 共 11 例依赖失败气泡与同步回复留在 `sent`），且 live 行本来就不会从屏幕消失。吞消息发生在 `previous` 路径，已按此收敛。
- [x] B3 表情包可匹配：`_matches` 不再无条件跳过 `sticker != null`，按 canonical turn 匹配；无 turn 时落到 B2 的保留路径。
- [x] B4 防止反向重复：新增 `_remoteAlreadyOwns()`（turnId/requestId + 同文本或附件占位行双重证据才认定远端已有）与 `retainedIds` 的 id 级去重，`previous`/`local` 两条源不会各插一份。
- [x] B5 回归测试：`test/chat_history_reconciliation_test.dart` group `refresh neither swallows nor degrades local rows` —— 远端缺失的 poll 回复跨两次刷新存活且唯一、随后落盘时只剩一条、表情包跨刷新存活且不重复、刷新幂等。
- [ ] B6 真机验收：发一条 → 立刻下拉刷新 → 消息不消失；等自动刷新触发（`:617`、`:1277`）再确认一次。**未做前保持 not-run，不得用 `flutter test` 冒充。**

## 24/C — 富消息不再被刷成纯文本（P0，紧随 B）

- [x] C1 匹配分支停止用远端文本覆盖本地富载荷：`keepImage` 已改名 `keepRich`，判定含 `attachments` / `sticker` / `quotedText` / 非空 `displayText`；命中时 `text` 保留本地，只接受远端 `time` / `dateKey` / `turnId` / `timestamp` / `mediaRefs`。
- [x] C2 `displayText` 优先级反转为 `item.displayText ?? remote[found].displayText`（`chat_history_reconciliation.dart:56`）。
- [x] C3 回复引用不丢：匹配分支保留 `quotedText` / `quotedLabel`（原本已保留，现连带 `keepRich` 一起被测试守住）；插入路径经 `settled().copyWith` 保留，已补测试。
- [x] C4 上传气泡匹配放宽：`candidates.length != 1` 先按 canonical turn 收敛到唯一候选，仍不唯一则保留本地条目（走 B2 保留路径），不再退回 `📎 文件名` 纯文本。
- [x] C5 回归测试：同 group 内覆盖引用气泡 + inline display 跨刷新不降级、远端投影为 null 不覆盖本地、远端给出「已清洗」投影也不覆盖本地、歧义文件气泡保留附件。
- [ ] C6 真机验收：发图 → 自动刷新后仍是图片卡片；引用回复 → 刷新后引用条仍在。**未做前 not-run。**

## 24/D — 收尾

- [ ] D1 `flutter analyze` + `flutter test` 全绿（Windows，路径按 `android/local.properties`）。
- [ ] D2 未闭环项写入 `docs/known-issues.md`，标明影响、证据、建议方向（强制规则 7）。
- [ ] D3 按「小步 commit」逐项提交：A、B、C 各自独立 commit，不攒大坨。
- [ ] D4 跨端影响说明：24/B、24/C 属本仓内部对账逻辑，**无跨端契约变更**；24/A 有 `/sensor/push` 契约扩展，已在 A9 同步总账。
