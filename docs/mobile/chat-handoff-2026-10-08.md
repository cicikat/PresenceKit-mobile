# 聊天交接与重试根因复查（2026-10-08，mobile 27 / backend 271）

## 根因与修复

1. 历史记忆正文保留模型原始段落，HTTP/poll 显示正文经过强制分段。chat-log 只投影 display_text，plain assistant 仍用记忆正文，造成同 turn 全文与分段并存。后端现从同一 ledger visible_text 投影 plain/display；手机清理同 turn 全文与完整分段等价的旧副本，不按全局文本去重，重复段落仍保留。
2. 刷新可将 user 从 sent 迁入 history，失败处理只查 sent；reconcile 重建气泡丢 failed/uncertain。现查两处、保留请求与失败状态，只由 assistant 成功证据确认发送。服务端仅用户文本不足以确认回复成功，不同 request_id 不可按同文同分钟匹配。
3. poll 成功可能早于 HTTP 超时。新增本代内有界 accepted request 集合，让成功证据优先于迟到错误；不新增落盘状态。
4. 后端把所有 executor 异常固定当 unknown，原 ID 重试永不执行。现仅 mobile/desktop chat 在工具执行与 turn sink 前失败标 retryable_failed，同 ID 同 payload 可重跑。已执行工具/进入 sink、上传和未知入口仍保守 unknown；completed replay/inflight/409 不变。并发 context/probe 失败会取消并等待兄弟任务，避免失败后遗留工具执行。
5. 前台看到后台服务 running 就停止 poll，且只在启动/恢复/通知点击 consume pending；服务运行不证明投递或呈现健康。现前台每轮交接 pending 并补偿 poll，后台 running 时不播放重复动画；同轮工作串行、旧代不覆盖当前代。
6. Android 写死 30 分钟提醒冷却，用户已授权取消。保留通知权限、用户开关、消息身份去重与高风险动作确认；移除无作用的冷却测试 UI，旧 MethodChannel 方法/偏好保留兼容。
7. 后台每次只读前 20 条，重连不立即补拉，积压的新消息留在后页。现重连即非阻塞补拉，每页最多 50、最多 10 页（匹配后端 500 条队列上限），逐页保存/ack。
8. native pending 只留 20 条，超过静默移除最旧的已 ack 信封。现上限 500、重复 pending 身份也参与防重；满载拒绝接收/ack，seen+pending 一次 commit。能力检查通过既有 getBackgroundPollStatus 显示 pendingCount/pendingLimit，无新增状态库。

## 三面闭环

管理面仍拥有模型路由/生成分段配置、能力 enabled/effective、session-scope trace。安全重试原因在既有 GET /observability/session-scope（state.read）可见，无正文/凭据；无新增运营开关。手机原生待交接数量只在本机能力观测显示，不成为后端业务真值。桌面只读核对；既有 chat-log 字段与 session HTTP 合同兼容，没有改桌面代码。

输入 → 冻结 request/reply_to/session → 后端执行/回执 → turn sink/HTTP/durable mobile → SSE signal/认证 poll → pending/seen → Flutter/history → UI/通知。origin+owner 共享 seq 不按角色拆分；外角色 stash 后 ack；认证、请求/回合身份、TTL、闸门与动作确认保留。后台满载错误沿现有 lastBackgroundError 可观测。

## 验收与剩余边界

定向 Flutter（包括交错超时、刷新迁移失败、同文不同请求、pending 交接）通过记录见工单 27；后端见工单 271。真机未连接，弱网/Doze/进程被杀/真实模型与通知矩阵 not-run。

- 15 分钟 AlarmManager 补偿保持原设置；无信号且处于后台/Doze 时仍可能延迟，不能承诺实时。前台补偿、重连立即补拉与分页解决原有阻塞，不改变 Android 调度约束。
- native consume 后、Flutter 呈现前崩溃窗口仍 open；无本机 claim/ack 事务。后台 artifacts/sticker 元数据仍不完整，canonical history 是恢复来源之一。
- 无 ledger 可见正文的旧历史仍 fallback 原日志；全文与分段只有同 turn 且完整正文等价才清理，不凭内容猜身份。
- 进程内 30 分钟回执不提供跨服务重启 exactly-once。已执行工具后的 unknown 不盲目重跑；旧 failed 回执没有阶段证据，仍保守 unknown。
- 真机安装/正式发布未执行；Dev 构建不等于正式包升级验收。
本轮结果：Flutter 327 passed / analyze 0 issues；Android 17 passed；后端 73 passed（1 既有桌面 mock 不匹配单测 excluded）；Dev debug APK 构建成功。后端提交 1180017，手机提交见本单 Git log。没有安装手机、重启运行中后端或对外发布。
