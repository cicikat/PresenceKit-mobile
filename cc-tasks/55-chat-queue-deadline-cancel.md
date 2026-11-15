# 55 手机发送排队期限与取消发送

目标：尚未发出的消息排队满一分钟后停止自动发送、显示红色感叹号；排队消息支持长按取消；已发出等待回复不受影响。

- [x] 明确状态边界、持久化兼容、容量与跨端影响，补回归测试（含原队首阻塞）。证据：chat_recovery_upload_test.dart 中 55: 六项虚拟时钟用例与既有 54: 用例，交互组合 69 项已通过；新增存储原子竞争/旧快照/100 条容量四项也已在全量448项中通过。
- [x] 实现一分钟排队到期、重启清理、手动重试重新计时，保留失败消息与附件。证据：55: queued B expires at 60s、expiry during session preparation、legacy expired queue 三项已通过。
- [x] 实现排队消息长按取消发送和中英文文案，验证取消与发送竞争。证据：55: queued cancel persists、cancelling a pending session bind 与 queued long press cancels 已通过；gen-l10n 完成。
- [x] 完成控制器、存储、界面回归与分析、构建；同步诊断和接口文档。证据：全量448项通过（build/chat-queue-55-full.log），analyze零问题；dev debug APK构建通过（28.7秒）。已同步AGENTS/CLAUDE、结构/集成/协议/已知问题/测试文档与跨仓总账；详情复制包含queued_at。故意改为61秒时60秒测试失败，已恢复60秒。
- [ ] 提交推送并按必需检查合并，记录证据。
- [ ] 真机验收：积压一分钟、后台恢复、取消与重复点击（not-run，自动测试不代替真机）。
