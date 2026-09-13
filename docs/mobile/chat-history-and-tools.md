# 历史对账与工具回执（2026-09-13）

`chat_history_reconciliation.dart` 保留服务端条目顺序，优先以 canonical reasoning 锚点限定用户/回复范围；旧日志按日期、HH:mm 和出现顺序兼容本机秒级时间。思考不比较时间，重复刷新保留已有 widget ID；同一回合只生成一个锚点，可信 action_trace 旁白不生成思考入口。失败/正在发送消息保留原 live retry 路径。

`ToolActivity` / `ToolActivityRow` 消费既有 `GET /chat-log/{date}` 的 `entries[].tool_activity`：event_id、chain_id、char_id、source=reality、tool_name、status。9.5px 单行文字右侧圆点：成功绿、失败红、其余中性并提供状态提示；仅连续、同角色同链的回执连线，event_id 去重。不读取参数、结果正文，不执行工具。entry_kind=narration 的旧动作回声仅显示小字，不作为角色发言或 reasoning ID。

外观中的 showToolActivity 默认 true，经既有 getAppearancePrefs / setAppearancePrefs 保存到 yexuan_memery；YxPrefs、AppSettingsStore、PlatformSettingsChannel、MainActivity 与中英文文案同步。设置页可读回当前显示偏好，无新权限或后台服务。

发送/附件回复完成且停留最新消息时刷新历史；发送中、动画中、已滚离底部时不做额外刷新。启动、恢复、通知和手动刷新仍是既有入口。手机没有订阅桌面实时 WS，不承诺调用刚开始就显示。

三面闭环：管理面继续拥有 action_trace enabled/event_log_echo 与 /observability/tool-traces；桌面既有本机开关独立。新增的仅是可在手机设置中读回的显示偏好，无新业务状态/台账。memory.read、reasoning turn_id、poll/msg_id/seen/ack/TTL、通知、权限及后台服务契约不变。后端/桌面仓库保持只读。

## 验收边界

验证：flutter gen-l10n 完成；全量 Flutter 178 项通过，最后新增历史回执联动并调整自动刷新生命周期后，相关测试 53 项通过。Dev debug APK 构建成功，产物为 build/app/outputs/flutter-apk/app-dev-debug.apk；没有安装或正式发布。

- `open`：没有 canonical turn_id 且跨分钟/正文分段不同的旧日志，仍只能按日期/时间/正文保守对账；不猜关联、不丢弃本机未匹配内容。完整解决需要后端日志提供稳定 user/message ID 与精确时间。
- `partial`：详细回执受后端既有最近 30 条 action_trace 环形记录限制，更早记录无可靠成功/失败状态。存储关闭时无法从历史恢复。手机实时工具流与完整历史需另行纳入后端范围；后端三仓总账 2026-09-12 工具链节仍列 mobile roadmap，后续维护时应更新为 partial，本轮未越界修改。
- `observe`：尚未完成真实 mobile token、真机自动刷新、默认展开思考、跨端工具链及重启保留开关的验收；自动测试与 Dev APK 不等同真机视觉验收。
