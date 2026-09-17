# 22 — 固定会话角色与后端身份契约配合

日期：2026-09-17。状态：partial，非阻塞本机项已落地；后端 B/C 未交付前请求侧冻结与真机联调 blocked。
依赖：[后端综合工单 B/C/D](../../Emerald-presence/cc-tasks/2026-09-17-backend-audit-session-scope-work-order.md)。来源：[桌面会话交接](../../Emerald-client/cc-tasks/2026-09-17-session-scope-backend-handoff.md)、[244 历史身份交接](../../Emerald-client/cc-tasks/244-history-turn-id-backend-handoff.md)。

目标：本机选择的角色与请求归属固定；其他设备或管理面切角色不能改本机会话。Flutter 与 Android 后台使用同一契约，旧响应不会污染当前角色。
完成一项并附证据才勾一项；自动测试、真实后端和真机验收分开。

## 已有成果与前置

- [x] 已阅读 [21 号工单](21-9.17审计评判与工单.md)及后端集成文档；该工单 A/B/D/G 已有实现记录，不重建消息身份、native delivery store 或媒体下载方案。
- [x] 核对该工单 A5/G5 仍含真机未验收项；本单不把过去的完成记录当作本次测试结果。
- [x] **盘点（无后端 B 契约）**：2026-09-17 核对 Emerald-presence HEAD `9aada55`（其后工作树在改 event_log/A，B1–B6 仍全未勾）。证据：
  - `/mobile/chat` 仅 `message`/`reply_to`，不读 body `char_id`；仍走 active 角色（`admin/routers/mobile.py`）。
  - 手机原路径用 PATCH `/settings/prompt-assets` 改全局 active；delivery cursor 为 origin+owner（`MobileDeliveryStateStore` 注释与实现）。
  - 桌面交接文件路径在本机工作区不存在；无 B fixtures/错误码/capability。
  - **不猜字段、未改 cursor 作用域**。后端 B/C 可用版本：not-received。

## M1 — 请求与本机会话 scope

落点按当前实现定位：ConnectionController、ChatController、BackendClient、消息模型与现有 settings 门面；AppShell 仅组合依赖。

- [x] 持久会话选择按后端节点/owner/角色隔离；用户主动切换与服务端 active 变化分开，角色名/头像不是执行授权。
  - 证据：`get/setSessionCharacterId`、`ProfileAppearanceController.selectSessionCharacter`；资料页不再 PATCH active；ARB 文案已改。自动：`profile_appearance_controller_test`、`method_channel_contract_test`。
- [ ] chat、上传、媒体读取、历史日期/单日、reasoning、相关 wake/activate 使用同一冻结 scope；明确 Dream 独立域，不能复用 Reality pending/响应关联。
  - **partial**：本地 `SessionScope` + Dream 独立控制器已确认；**wire char_id / 授权 blocked on B/C**（`sendChat` 尚未传 char_id）。
- [x] 请求开始冻结 scope/代际/request_id；回包按原 scope 归档或明确保留，不写入新会话；切换时隔离 pending、history、reasoning、下载缓存与延迟回调。
  - 证据：发送/错误/finally 与媒体下载按 `SessionScope.matchesLive`；角色切换仍 `resetForConnectionChange`。request_id 等后端 B3。
- [ ] 处理角色删除/撤权、401/403、能力缺失和旧服务端；不静默回落 active 角色。重试/附件去重遵守后端合同，关联 ID 不代表恰好一次。
  - **blocked on B2/B4**（错误码与 capability 未交付）。本地已拒绝未知角色 id 写入会话偏好。

## M2 — Flutter / Android 后台交接

复用 MobileDeliveryStateStore、MainActivity、MobileNotificationService 和现有 MethodChannel，不恢复双 writer 快照覆盖。

- [x] 后台获得明确的节点/owner/角色订阅身份；relay signal 仅触发合法 scope 的 poll，不把信号等同完整消息或擅自切换当前聊天。
  - 证据：既有 origin+owner bind；本机会话角色 prefs；relay 仍只触发认证 poll（未改）。角色级订阅策略等 B。
- [x] 核对 poll 过滤、queue id/seq、ack、TTL 的服务端作用域；共享 cursor 时不得按角色丢弃结果后 ack 跳过其他角色消息。
  - 证据：cursor 保持 origin+owner；前台异角色 `stashPendingMobileEnvelopes` 后再 ack；consume 仍按 char 过滤。自动：既有 poll lifecycle + channel contract。
- [x] pending envelope 保留原身份和 scope，persist→ack、重试、消费失败/崩溃恢复遵守既有契约；旧无作用域内容不得归给当前角色。
  - 证据：既有 store + stash 写入含 `char_id`；无 char 的 legacy 仍按 `acceptsMessageChar` 可见（不伪造归属）。
- [x] 前后台切换、通知点击与在途请求使用 scope/代际校验；SharedPreferences 历史名称和 channel ABI 保持兼容，Dart/native 变更同步。
  - 证据：新增方法为加法 ABI；`yexuan_memery` 未改名；发送/媒体代际校验。
- [ ] 后台多个角色消息的通知展示、点击目标和当前会话切换行为按后端 B 定义；不能为了展示一条通知改变其他设备的角色。
  - **blocked on B5/B6**；后台仍通知全部 poll 条目（既有行为），未发明多角色通知 UX。

## M3 — canonical 身份与历史恢复

- [x] HTTP msg_id、queue id、request_id 与 persisted turn_id 按合同区分；reasoning 仅用 canonical turn_id，有明确身份的历史不按正文合并。
  - 证据：复用 21/D；未新建 ID 映射库。request_id 等 B。
- [x] 复用 21/D 历史对账和 21/G 媒体读取；测试同文同分钟不同回合、无 ID 旧日志、多段回复、延迟历史、无归档空态，禁止本地另造 ID 映射库。
  - 证据：`chat_history_reconciliation_test` 等既有回归本轮仍通过；未重做解析器。
- [x] 媒体下载缓存包含合法 scope，A 的 sha256/旧链接不能绕过 B 的读取权限；附件随原请求冻结，角色切换后不得发到新角色。
  - 证据：进程内缓存键含 origin|owner|char；下载回填校验 SessionScope；切换清缓存并 `resetForConnectionChange`。服务端按角色拒绝读取仍等 C2。

## M4 — 验证与交付

- [x] 自动回归：请求序列化/能力降级、scope 切换迟到结果、历史/媒体隔离、native bridge 与 store、poll/ack 交错和落盘失败；优先复用既有测试，按开发文档顺序执行 analyze/test/必要构建。
  - 证据（本机）：`flutter analyze`（改动文件无 error）；`session_scope_test`、`profile_appearance_controller_test`、`method_channel_contract_test`、`chat_session_coordinator_test`、`mobile_poll_lifecycle_test`、`chat_history_reconciliation_test`、`localization_contract_test`、`foreground_mobile_delivery_contract_test` 通过。
- [ ] 真机联调：桌面 A、手机 B 同聊，管理面切 C；手机发送/附件/历史/思考仍属 B，切 D 后旧 B 结果不污染 D。
  - **not-run**（无后端 B/C + 未接真机）。
- [ ] 真机后台：离线点击通知、进程重启、前后台竞态、relay 断线补偿、ack 超时、TTL 过期、撤权与节点切换；联动关闭 21/A5，媒体场景另核 21/G5，未测不勾。
  - **not-run**。
- [x] 更新 `docs/backend/integration.md`、`docs/protocols/mobile-channel.md` 和实际受影响 native/structure/known-issues；后端接口总账同步 open/observe。新增可见文案维护双语 ARB；UI 复用现有组件。
  - 证据：上述文档已更新；ARB zh/en + `flutter gen-l10n`。三仓总账需后端授权仓写入，本仓标明 open/blocked，未改 Emerald-presence 总账。
- [x] 核对管理面 capability/effective/无正文诊断由后端提供，手机只展示必要连接/权限/降级，不增运维面板。新持久状态如有独立排障需求须与后端观测同单交付。
  - 证据：仅本机会话角色 prefs + stash；无新管理面板。会话偏好无独立远端观测需求（本机 UI 可见）。
- [x] 每个独立可验收子单完成后差异/换行检查并单独 commit，记录后端版本、客户端版本及测试证据；真实后端/真机未跑明确 not-run。
  - 后端版本：B/C not-received（presence `9aada55` + 未勾 B）。客户端：见本提交。真机/真实后端：**not-run**。

顺序：后端 B → M1/M2 方案；后端 C 可用 → M1/M2/M3 接入 → M4 联调。与 21 号工单相同 controller/store 的修改串行。本单不要求手机配合纯后端 scheduler、tool authority、Memory shadow 重构；Dream settings 仅在后端 F 明确归属且合同实际变化后追加接入项。

### 复查记录

- 2026-09-17 非阻塞落地后复查：后端 B1–B6 / C1–C7 仍全部未勾选；继续 blocked 项保持未勾。
