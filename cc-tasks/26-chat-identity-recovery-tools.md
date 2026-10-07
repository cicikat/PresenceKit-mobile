# 26 手机聊天身份、恢复与工具时序根因修复

范围：手机仓库聊天请求、HTTP/poll/history/native handoff 合并、工具呈现及生命周期；后端已获授权联动施工；桌面只读核查，保留 HTTP/鉴权兼容字段。保留 .tmp/ 等无关文件。

- [x] 入口与初步诊断：chat_controller.dart retryMessage 丢失 replyTo；chat_history_reconciliation.dart 同 turn 任意匹配分段，工具受邻居身份过滤；需测试确证。
- [x] 建立链路与不变量：逻辑请求复用 request_id 和完整载荷；回合不等于气泡；正文/字效分离；工具按 event_id 去重、不得继承邻居回合；迟到工作不得污染新代际。验收：代码路径及后端只读证据。
- [x] 修复请求重试与发送恢复。验收：原引用重试、未知结果恢复、history 迁移后 settle、连接换代回归。
- [x] 修复多来源和分段对账，保留富文本、重复正文不同回合、附件及产物。验收：定向 controller/reconciliation 测试。
- [x] 修复工具排序、身份隔离及历史更新与本地尾部拼接。验收：先工具后回复、旧工具不会挂新回合测试。
- [x] 审查 poll/ack/native/连接生命周期与相邻功能，记录剩余风险；同步三面闭环文档及必要跨仓总账。验收：不新增后端开关/权限，不改 ack/TTL，证据明确。
- [x] 顺序运行格式、分析、定向与完整 Flutter 测试；核对换行差异。验收：analyze 零问题，Flutter 全量 321 项，Android 15 项，后端 33 项通过；按仓分别提交。
- [ ] 真机网络断连重试、长回复/工具、前后台切换验证（not-run：没有实际执行前不勾选）。

验收边界：自动测试证明实现规则，不能替代真实后端/模型/手机验收；后端施工已获明确授权，保持现有兼容契约。

## 后端授权扩展（2026-10-07）
用户已授权纳入后端历史投影与工具关联，保留现有兼容契约。
- [x] 后端以 ledger occurred_at 排序，工具关联 owner turn，legacy 分钟级顺序不伪造；请求回执恢复关联为有界兼容字段。验收：Python 隔离测试。

根因补充：profile ensurePresenceSession 无 in-flight 合并，history/send 同时重绑会相互升代作废，甚至令服务器 request receipt 分属不同 session；chat-log 未回传 request_id；HTTP 完成路径未检查已加载历史身份；工具历史仅 HH:mm 排序，同分钟追加工具落到回复之后。
## 分项证据

- 重试/历史确认/工具时序：chat_recovery_upload_test.dart，chat_history_reconciliation_test.dart；定向 52 项通过（chat26-focused-final）。
- 后端关联/精确时间/重绑回放：后端 test_chat_log_turn_id.py、test_tool_activity_display.py、test_session_scope.py、test_event_context_propagation.py、test_event_context_contract.py；33 项通过。
- native correlator：MobileDeliveryStateStoreTest 11 + SettingsChannelDeliveryTest 4，15 项通过。
- 三面审计：docs/mobile/chat-integrity-2026-10-07.md；后端三仓总账与 session-scope-contract 已同步。
- 最终门禁：flutter analyze --no-pub 零问题；flutter test --no-pub 全量 321 项通过；Debug APK 构建成功，未安装。后端提交 70a60c8。真实手机/模型 not-run（adb 未发现连接设备）。
