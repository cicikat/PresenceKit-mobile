# 手机聊天完整性修复（2026-10-07，工单 26 / 后端 267）

## 结论与责任边界

缺陷分布在请求身份、会话绑定、投递消费、历史投影和展示合并五层，并非单纯连接状态或气泡样式问题。后端仍是业务真值；手机负责同一请求重试和有身份的多来源呈现。

| 层 | 根因 | 修复与验收入口 |
|---|---|---|
| 请求 | retryMessage 丢失 reply_to；request_id 仅由时钟生成；重绑 grant 会切换 receipt 空间 | ChatMessage.retryReplyTo 保存 wire payload；随机 128-bit request ID；后端按 token label+owner+char+domain+request_id 去重，重绑回放 |
| 会话 | history/send 并发 bind 互相升代；旧同步 finally 可清理新任务 | ProfileAppearanceController 合并同作用域 bind；start/refresh/reveal/poll 加 generation 与任务身份守卫 |
| 确认 | 历史对账将保留的本地 request_id 当回执；迁入 history 后丢 correlator；无成功 poll 时确认中状态不超时 | 仅原始服务端条目可 settle；保留 request_id；内存期限 Timer；HTTP 回包绑定同时查 history/sent |
| 投递 | native seen 是通知消费，Flutter 却据此丢 pending；pending 全文与历史分段形状不同；后台信封丢 request_id | 启动/恢复/通知均回放 scoped pending；按页面身份与出现次数去重；分段保留字效；Android/Dart 透传 request_id |
| 合并 | 同 turn 多段任意匹配，富文本覆盖另一段；HTTP/历史并发重复 | 同回合限定范围并匹配段落；单一段落才允许 identity-only 修正；HTTP/poll/reveal 统一逐段 merge，复用本地 key 与字效 |
| 工具 | chat-log 将回执追加后仅按 HH:mm 排序；工具继承相邻思考身份；状态改变被 silent unchanged 忽略 | ledger ts/user_ts 精确排序；真实 owner 执行上下文绑定 turn_id/request_id；工具按 event_id 对账，不猜邻居；工具状态参与可见比较 |

## 不变量与链路

输入 → ChatController 冻结引用与 request_id → presence grant → POST /mobile/chat 或 upload/ingest → owner-chat / session receipt → turn sink → HTTP + mobile durable queue → poll / native pending / chat-log → 分段呈现。request_id 标识逻辑请求，turn_id 标识已落盘回合，tool event_id 标识调用，不能互相替代。相同正文在不同身份下仍是不同消息；同一回合中的重复段落按出现次数保留。

poll 仍保持 stash 外角色 → seen 合并 → ack 最大 seq → 单调保存 cursor；origin+owner cursor 不按角色拆分。旧 generation 的结果或错误不得改变当前角色状态。上传正文读完也受 timeout 限制，避免 sending 长期不释放。

## 三面闭环

管理面：沿用 action_trace enabled/event_log_echo、/observability/tool-traces/{uid}（已有 display_activity 可查看新增关联字段）与 session-scope 观测；无新增业务开关、状态库或队列。现有 bounded receipt 30 分钟、trace 30 条未扩大。桌面：HTTP/历史的加法字段保持兼容，WS 工具字段仍可忽略；未修改桌面代码。手机：不新增设置、权限或前台服务；pending request_id 是既有信封元数据补全，ABI 不改名。无新 Flutter 可见文案。

## 验收边界与遗留

自动测试与具体结果记录在 cc-tasks/26-chat-identity-recovery-tools.md；后端见 cc-tasks/267-mobile-chat-recovery-tool-order.md。真实手机、实际模型长回复、Doze、弱网及杀进程验收保持 observe，不等同单元测试。

- legacy 无精确时间/回合身份时只能稳定保留原顺序；不伪造工具所属回合，无法恢复旧 trace 被淘汰的状态。
- request receipts 仍是进程内 30 分钟有界状态；后端重启/回执到期后无法承诺 exactly-once。真正 execution_outcome_unknown 不自动换新 ID 重跑工具。
- native pending consume 是取出后清除；消费后、页面呈现前进程被杀的原子 handoff 与完整 artifacts/sticker 元数据仍 open，通常依靠 canonical history 恢复，不能称无损持久投递。
- 手机工具回执来自历史刷新，没有实时工具事件订阅；修复历史时间顺序不等于实时 running UI。
