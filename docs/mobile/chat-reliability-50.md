# 手机 #50：聊天可靠性与阅读位置

2026-11-14。代码修复与自动化证据不等于用户 APK 的真机复现；当前 adb 无设备，50-01～50-14 设备验收、原位升级、录屏及 logcat 均 NOT RUN。

## 根因与处理

| 问题 | 可确认代码机制 | 本轮处理 |
|---|---|---|
| 未知首项阻挡后续 | drain 只发送 queued 首项；重启 sending 转 unknown | 保留原顺序，详情解释暂停；用户确认后持久化 skipped，保留原 request_id 接收迟到回复 |
| 重复事件入队 | 每次回调均创建 ID | 同 scope、正文、引用、附件、语音回执的在途落盘事件合并；落盘完成后允许有意重复发送 |
| 错误重试 | blocked 未区分 HTTP 原因 | 保存 status_code，401/403 处理授权后可手动重试，413/422 要改载荷，不自动重发 unknown |
| 技术状态占据聊天 | 动态 meta 与大操作按钮进入时间线 | 单条轻量状态点开详情，检查/跳过/本机移除含明确说明；连接入口叠放，不改变列表高度 |
| 阅读旧消息下移 | maxScrollExtent 差值混入前后插入；多个跳底入口 | 真实消息 ID + 可见 y，center 双向 sliver 重设原点；邻居回退，用户意图独立于网络事件 |
| 伪生成中/恢复后消失 | typing 绑定前台 HTTP，在途不代表运行证据 | 不以 HTTP/WS 连通推断 running；保留既有 final 揭示，未知只提供有限补读与人工检查 |

`ChatScrollController` 管理 following、可见锚点、scope reset；`AnchoredChatList` 保留虚拟构建，不估算未布局的旧行高度。发送只在原本跟随时滚底。用户主动到最底或点击最新才恢复跟随。主题与草稿/引用/附件功能沿用原组件。

## 后端只读审计与依赖（open）

后端 `core/session_scope.py` 的 `execute_request()` 使用 token label、owner、char、domain、request_id 命名空间，校验载荷摘要并复用 completed；running task 的 shield 意味 HTTP 中断不是未执行证据。`admin/routers/chat.py` 已有 `/desktop/chat/requests/{request_id}`，不能将桌面端点当手机能力。手机 `final_only` 仅有最终结果，没有可恢复的 running 证明。

独立后端依赖：建议只读 `GET /mobile/chat/requests/{request_id}`，由 Bearer chat scope 与 `X-Presence-Session` 固定 owner/char/domain/session，按已有回执查询，拒绝跨 scope 枚举；不存在/过期/重启失去证据均 unknown（或404），不可触发生成、工具、重试或改台账。仅返回 `running/completed/failed/retryable_failed/unknown`、已有 turn_id、更新时间和明确 retry_safe，不返回提示词、工具参数或思考。completed 无正文时复用 scoped 历史补读。只有确证 retry_safe 才允许恢复；进程内台账过期不得承诺 exactly-once。

接口尚未实现或调用。本轮手机不做状态查询循环，不会永久 spinner；手动检查只运行既有有期限的只读补读。未来接入须能力探测、前台退避2/5/10秒与总截止、退后台取消、身份代际隔离、唯一 final 对账。恢复三点仍为 open。

## 三面闭环与兼容

- 管理面：无新总开关；后端仍拥有能力/effective 和执行真值。新本机 skipped 不代表服务器取消，不写后端业务状态；现有只读本机 Outbox 快照与详情可观测，远程请求状态端点依赖保持 open。
- 桌面：无协议/设置改动；手机没有调用桌面 request receipt。感知与原生通知收尾由手机 #49 记录。
- 原调用链：输入先原子落盘→原 ID/载荷发送→HTTP/WS/poll/历史按 scoped request_id 对账。原 Bearer、session、mobile inbox ACK/cursor、TTL、final-only、后台接收所有权不变。skip 是用户明确的顺序例外，不清历史、不撤回、不自动重跑。
- 本机 Outbox v1 新增可选 status_code 与 skipped 枚举；旧记录照常读取。旧版本不认识 skipped，禁止把降级安装当无损回滚；回滚前应先通过当前版本完成/处理该类条目并备份私有数据。新增状态仅本机消费，未改 mobile wire 字段。

## 自动化与设备边界

`chat_recovery_upload_test.dart` 覆盖重复回调、有意重复、明确 skip 重启保留/迟到回复、422 不重试及原队列恢复；`chat_scroll_anchor_test.dart` 覆盖同时 prepend/meta/append 1/10/50 条和锚点删除，邻居坐标误差 ≤2px。布局回归覆盖各主题、大字、键盘、导航及草稿；前台契约验证技术状态退出正文且心情仍可在详情查看。

无设备不能确认 OEM 通知、真实工具超过120秒、实际网络/VPN、杀进程与正式签名原位升级。交付测试统计和构建证据见 `../quality/testing-and-dev.md`，未验收项保留在工单。
