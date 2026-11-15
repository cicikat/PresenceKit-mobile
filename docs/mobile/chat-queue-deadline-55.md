## 手机 #55 排队一分钟与取消发送（2026-11-15）

仅尚未调用 chat/upload 的 queued 消息从 queued_at 起计一分钟，满一分钟转 expired；排队消息长按可取消为 cancelled。两者均退出自动发送与100条有效队列容量，聊天仍保留原内容、附件和红色感叹号，只有明确手动重试才重新排队并刷新 queued_at。已经调用接口的 sending/outcomeUnknown 不按此期限丢弃，不伪装成未发送。准备会话也保持 queued；派发和取消通过原子状态比较竞争，迟到准备不能发送已取消的旧尝试。

持久化兼容：Outbox v1 新增可选 queued_at，旧快照回退 created_at；新增 expired/cancelled 仅本机状态。恢复时先淘汰过期积压再派发，不补发。原 created_at、request_id、scope、引用/附件载荷不变。详情可观测状态、原时间、关联键并重试/删除；未处理计数不含本地终止项。仍保留64MiB总体存储上限，保留附件的失败记录也占物理存储；可在详情删除。旧包不识别新状态，回退旧包前应备份和处理记录。

三面闭环：后端管理面不新增开关或远端取消语义；桌面不消费手机私有队列，无同步设置。手机输入→原子落盘→会话准备→原子派发→原有 chat/upload→HTTP/WS/poll/history 对账保持鉴权、关联键、去重、ACK/cursor、通知和后端TTL不变；本机一分钟仅作用于尚未派发消息。Android后台服务不修改；前台计时、唤醒恢复/恢复快照检查以及派发前检查共同防止补发旧消息。

open：scoped只读请求执行状态端点仍未完成，复用既有本机投递详情观察，不虚构后端查询端点。observe：真机后台/杀进程/旧包升级未验收。测试入口及证据见工单55。

防回归：test/chat_recovery_upload_test.dart 的 55: 五项虚拟时钟用例覆盖59/60秒边界、发送后等待不淘汰、会话准备到期、取消持久化及重启补发隔离；test/mobile_outbox_deadline_test.dart 覆盖容量、原子取消/派发竞争、旧快照与重试代际；test/chat_interaction_regression_test.dart 覆盖长按入口及原复制菜单。原54队首恢复用例继续保留。CI的flutter test覆盖全部这些用例。

自动验收：全量447项通过（build/chat-queue-55-full.log）；故意把一分钟改为61秒后，60秒用例按预期失败：Expected expired / Actual queued（build/chat-queue-55-red.log），已恢复正式60秒规则。此红/绿验证证明该用例能拦截期限回归。既有CI的flutter test自动运行这些测试。

flutter analyze --no-pub 零问题；flutter build apk --debug --flavor dev 成功，Gradle31.2秒。开发APK位于build/app/outputs/flutter-apk/app-dev-debug.apk；未安装、未正式发布，真机行为仍not-run。
