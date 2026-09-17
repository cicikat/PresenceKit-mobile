# 22 — 固定会话角色与后端身份契约配合

日期：2026-09-17。状态：open，工单已编写，新增施工未开始。
依赖：[后端综合工单 B/C/D](../../Emerald-presence/cc-tasks/2026-09-17-backend-audit-session-scope-work-order.md)。来源：[桌面会话交接](../../Emerald-client/cc-tasks/2026-09-17-session-scope-backend-handoff.md)、[244 历史身份交接](../../Emerald-client/cc-tasks/244-history-turn-id-backend-handoff.md)。

目标：本机选择的角色与请求归属固定；其他设备或管理面切角色不能改本机会话。Flutter 与 Android 后台使用同一契约，旧响应不会污染当前角色。
本轮只写工单，不改代码、不构建、不安装。完成一项并附证据才勾一项；自动测试、真实后端和真机验收分开。

## 已有成果与前置

- [x] 已阅读 [21 号工单](21-9.17审计评判与工单.md)及后端集成文档；该工单 A/B/D/G 已有实现记录，不重建消息身份、native delivery store 或媒体下载方案。
- [x] 核对该工单 A5/G5 仍含真机未验收项；本单不把过去的完成记录当作本次测试结果。
- [ ] 收到后端 B 的版本/capability、scope 授权、错误码、字段与 fixtures；确认 C 可用版本。没有契约时仅盘点，不猜字段或擅自改变 queue cursor 作用域。

## M1 — 请求与本机会话 scope

落点按当前实现定位：ConnectionController、ChatController、BackendClient、消息模型与现有 settings 门面；AppShell 仅组合依赖。

- [ ] 持久会话选择按后端节点/owner/角色隔离；用户主动切换与服务端 active 变化分开，角色名/头像不是执行授权。
- [ ] chat、上传、媒体读取、历史日期/单日、reasoning、相关 wake/activate 使用同一冻结 scope；明确 Dream 独立域，不能复用 Reality pending/响应关联。
- [ ] 请求开始冻结 scope/代际/request_id；回包按原 scope 归档或明确保留，不写入新会话；切换时隔离 pending、history、reasoning、下载缓存与延迟回调。
- [ ] 处理角色删除/撤权、401/403、能力缺失和旧服务端；不静默回落 active 角色。重试/附件去重遵守后端合同，关联 ID 不代表恰好一次。

## M2 — Flutter / Android 后台交接

复用 MobileDeliveryStateStore、MainActivity、MobileNotificationService 和现有 MethodChannel，不恢复双 writer 快照覆盖。

- [ ] 后台获得明确的节点/owner/角色订阅身份；relay signal 仅触发合法 scope 的 poll，不把信号等同完整消息或擅自切换当前聊天。
- [ ] 核对 poll 过滤、queue id/seq、ack、TTL 的服务端作用域；共享 cursor 时不得按角色丢弃结果后 ack 跳过其他角色消息。
- [ ] pending envelope 保留原身份和 scope，persist→ack、重试、消费失败/崩溃恢复遵守既有契约；旧无作用域内容不得归给当前角色。
- [ ] 前后台切换、通知点击与在途请求使用 scope/代际校验；SharedPreferences 历史名称和 channel ABI 保持兼容，Dart/native 变更同步。
- [ ] 后台多个角色消息的通知展示、点击目标和当前会话切换行为按后端 B 定义；不能为了展示一条通知改变其他设备的角色。

## M3 — canonical 身份与历史恢复

- [ ] HTTP msg_id、queue id、request_id 与 persisted turn_id 按合同区分；reasoning 仅用 canonical turn_id，有明确身份的历史不按正文合并。
- [ ] 复用 21/D 历史对账和 21/G 媒体读取；测试同文同分钟不同回合、无 ID 旧日志、多段回复、延迟历史、无归档空态，禁止本地另造 ID 映射库。
- [ ] 媒体下载缓存包含合法 scope，A 的 sha256/旧链接不能绕过 B 的读取权限；附件随原请求冻结，角色切换后不得发到新角色。

## M4 — 验证与交付

- [ ] 自动回归：请求序列化/能力降级、scope 切换迟到结果、历史/媒体隔离、native bridge 与 store、poll/ack 交错和落盘失败；优先复用既有测试，按开发文档顺序执行 analyze/test/必要构建。
- [ ] 真机联调：桌面 A、手机 B 同聊，管理面切 C；手机发送/附件/历史/思考仍属 B，切 D 后旧 B 结果不污染 D。
- [ ] 真机后台：离线点击通知、进程重启、前后台竞态、relay 断线补偿、ack 超时、TTL 过期、撤权与节点切换；联动关闭 21/A5，媒体场景另核 21/G5，未测不勾。
- [ ] 更新 `docs/backend/integration.md`、`docs/protocols/mobile-channel.md` 和实际受影响 native/structure/known-issues；后端接口总账同步 open/observe。新增可见文案维护双语 ARB；UI 复用现有组件。
- [ ] 核对管理面 capability/effective/无正文诊断由后端提供，手机只展示必要连接/权限/降级，不增运维面板。新持久状态如有独立排障需求须与后端观测同单交付。
- [ ] 每个独立可验收子单完成后差异/换行检查并单独 commit，记录后端版本、客户端版本及测试证据；真实后端/真机未跑明确 not-run。

顺序：后端 B → M1/M2 方案；后端 C 可用 → M1/M2/M3 接入 → M4 联调。与 21 号工单相同 controller/store 的修改串行。本单不要求手机配合纯后端 scheduler、tool authority、Memory shadow 重构；Dream settings 仅在后端 F 明确归属且合同实际变化后追加接入项。
