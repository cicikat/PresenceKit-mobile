# 梦境醒来与分段显示（2026-09-13）

手机醒来沿用 `POST /dream/wake` 的软挽留；选择留下走 `/dream/resume`，坚持离开或侧栏切页走 `/dream/exit`。关闭判定对齐桌面 `dreamWakeTransition.ts`：非 retained，且 `closed_now=true`，或 `already_closed=true` 且 `archive_ok!=false`。不能仅凭 HTTP 200、旧 `exited` 或没有挽留就清空消息并切页。恢复也检查 `ok` 和 `resumed`，失败保留现场并显示双语重试提示。

DreamController 对转换请求防重入；确认关闭后失效旧请求，迟到的聊天/状态响应不能恢复页面。请求失败不会自动再发强退请求。主聊天、Dream 消息列表保持独立。

梦境按协议 segment 类型及空行依次追加段落。对白、动作、感受、环境和旁白复用主聊天 AnimatedRevealText 的 40 字素/秒展示；正文左对齐，保留梦境各类字号和颜色。点击只完成当前段落，段落使用稳定消息 ID，开始显示后消费动画标记，避免轮询、离屏重建时重播。滚动接近底部时跟随内容增长，阅读上文时不强拉到底部。禁止重复发送已在处理的草稿，移除原先重复追加用户消息的隐式队列。

## 三面与调用链核对

- 后端管理面已有 dream-settings、observe-dream、observe-dream-operations；本次不新增业务配置、落盘状态、trace 或队列，无新观测端点需求。
- 桌面只读核对关闭判定、挽留和恢复语义；本次仅修改手机仓库。梦境外观继续使用既有本机偏好，不需新增桌面设置、能力权限、Android 服务或降级配置。
- 仍经 BackendClient Bearer 与后端 activity scope；请求路径、payload 和后端契约未改变，只补齐已有返回字段消费。Dream HTTP 回复完整返回后做本机逐字展示，不是网络 SSE。mobile poll/ack、msg_id/turn_id、TTL、ntfy、通知和 Reality 去重链路均未改动。
- 关闭失败包括网络错误和归档未确认，保留消息供重试；已关闭结果可幂等确认。状态请求 generation 防止退出后的旧响应写回。

## 验收边界

新增 dream_regression_test 覆盖关闭判定、失败后重试、迟到响应、串行段落、重复提交和五种叙述类型的动画重建；请求层覆盖鉴权、关闭响应及恢复拒绝。全量测试与分析结果见本次交付记录。真实手机与运行中后端的挽留、归档失败及长回复视觉体验仍待联调，不能将合成测试当成真机验收。
