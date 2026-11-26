# 66：T4.1 录音和语音回执冻结归属

日期：2026-11-26。默认提交/push/合并；不部署、不正式发布。

- [x] 核对 main 和真实 caller：VoiceInputController → BackendClient.transcribeAudio → 缓存；ChatController.send → durable outbox → sendChat。
- [x] 原实现两项实际失败：迟到 A 转写污染 B 缓存、同 token 同文本不同 Session 误取回执；原日志保留 ignored build。
- [x] 复用 ProfileAppearanceController 的 grant/epoch，录音开始即冻结；每个 await 和缓存提交检验，硬件 start/stop 期间不启动第二段录音。
- [x] 缓存提交保护、逆序响应与同 scope 一次性读取；错误 scope 不销毁合法回执；删除 sendChat 无身份的隐式取回执。
- [x] 迁移真实 composer/outbox caller，保留现有 request_id、去重与共享 poll/ACK，无数据格式迁移。
- [x] 定向 136 passed；analyze 无问题；完整 Flutter 495 passed；实际 grant owner 的 ABA/撤销及 controller/结构补充 28 passed。CI 随交付跟进；结构上限未提高。
- [ ] 手机独立 dev 包验收，逐项写入后端现有 T4 报告；不冒充正式设备/真实模型成功。
