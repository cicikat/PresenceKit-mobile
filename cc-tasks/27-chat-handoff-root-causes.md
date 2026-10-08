# 27 聊天交接与对账根因复查

范围：手机端历史、HTTP/poll/pending 合并和发送失败状态；后端只读定位，代码联动待明确授权。保留身份、权限、原有鉴权、TTL、ack 与用户数据。

- [x] A 定位四类根因与三面调用链，记录证据；验收：代码路径与复现用例。
- [x] B 修复后台运行时前台 pending 无周期交接；验收：服务 running 且 native 已 ack 后前台仍呈现新消息。
- [x] C 修复刷新对账误确认/状态丢失，保留失败重试入口；验收：失败用户行仅有历史文本时仍失败，同文本不同 request 不合并。
- [x] D 修复同回合不同分段形状重复；验收：全文和分段等价时只有一组，重复段落保留，不按全局内容去重。
- [x] E 联动后端安全重试与通知策略；依赖授权与后端执行阶段证据，未知副作用不自动重跑。
- [x] F 顺序运行 Dart 格式、定向测试、分析及必要 Android 检查；逐项记录结果并 scoped commit。
- [ ] G 真机长回复、刷新/发送交错、断网重试、前后台/Doze：not-run，adb devices 无设备。

依赖：A → B/C/D；E 待授权；F 依赖修复；G 依赖设备。无并行 agent。

初始状态：HEAD 693a362；仅未跟踪 .tmp/，不纳入提交。adb devices 无连接设备。上一轮自动测试不代表真机通过。
证据（阶段验收）：80 项定向 Flutter 测试通过；B running native service hands pending...；C user history alone preserves failed retry... / same text and clock cannot merge...；D canonical split history replaces obsolete full live and parked copies。后端 session_scope / chat-log / inline / mobile 测试 44 passed、1 既有 desktop trusted_user_text mock 不匹配（chat.py 未修改），待追加边界验收。

E 验收：用户授权已到；后端 73 passed；Android MobileDeliveryStateStoreTest 12 + SettingsChannelDeliveryTest 4 + MobileNotificationDeliveryTest 1 均通过。新增发现：pending 20 条静默淘汰、单页旧消息积压、context/probe 兄弟任务残留。Flutter 最近定向 118 passed，新增 poll 成功早于 HTTP 超时、刷新迁移后失败气泡可原 ID 重试；analyze 0 issues。

最终自动化验收：flutter gen-l10n；flutter test --no-pub 全量 327 passed；flutter analyze --no-pub 0 issues；Android :app:testDevDebugUnitTest 指定三类 17 passed（12/4/1）；flutter build apk --debug --flavor dev --no-pub 成功，build/app/outputs/flutter-apk/app-dev-debug.apk。普通 diff stat 与 ignore-cr-at-eol stat 一致，git -c core.whitespace=cr-at-eol diff --check 通过。后端 scoped commit 1180017；手机本单立即 scoped commit。
代码证据：chat_controller.dart:742/780/1140；chat_history_reconciliation.dart 的完整同回合正文比较和 request 冲突守卫；MobileDeliveryStateStore.kt:112/142/270；MobileNotificationService.kt:258/578/931；MainActivity.kt:367。完整根因与三面边界见 docs/mobile/chat-handoff-2026-10-08.md。
