# 41 手机消息投递与跨端连接底层审计

日期：2026-10-24
范围：手机 Flutter/Android、后端 mobile queue/relay/turn sink/desktop WS；桌面只读对照。仅审计与文档，不改运行行为、不发布。

- [x] 对齐实际调用链、轮询/超时/前后台所有权。证据：chat_controller.dart:150、166、1144、1166；MobileNotificationService.kt:340、531；backend_client.dart:210。用户补充：前台 + V2Ray 类代理 + 服务器地址。
- [x] 核对后端发送顺序、持久化、ack、隔离、WS 单连接替换及既有修复。证据：后端 channels/mobile.py:154、desktop_ws.py:259、core/turn_sink.py:173、admin/routers/chat.py:314；入队失败上抛修复已在 dfba6bc 的代码中。
- [x] 用隔离测试/可重复实验验证关键风险。Flutter 定向 78 passed；真实本地 CONNECT 黑洞代理实验 1 passed（16011ms 仍在途，连接超时8000ms、poll响应期限15000ms、第二轮仍复用）；后端 53 passed（49 既有 + 4 审计实验）。日志：build/review/mobile-delivery-audit/；后端 .tmp/mobile-delivery-audit-2026-10-24.log。adb devices -l 为空，V2Ray/Doze/线上均未验收。
- [x] 评估 HTTP 长轮询、独立 WebSocket + HTTP、后台唤醒的边界和迁移顺序。完整报告 docs/mobile/message-delivery-audit-2026-10-24.md 的 A/B/C 与 R0-R3；先网络/连续收件，后独立mobile WS，明确不复用desktop单连接。
- [x] 输出审计报告、已知问题及跨仓总账。报告 docs/mobile/message-delivery-audit-2026-10-24.md；后端文档提交217a021。UTF-8、手机CRLF/后端LF、代码围栏、新增相对链接、git diff与ignore-cr-at-eol统计一致；CRLF按git -c core.whitespace=cr-at-eol diff --check验证。手机文档随本提交固化，运行代码未改。

验收：每个结论包含触发条件、影响、定位、证据强度和建议；不把历史修复或静态测试写成真机结论。
真机/线上部署版本、实际弱网/Doze/OEM 后台行为：未验收，需明确列出。