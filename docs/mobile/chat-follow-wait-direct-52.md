# 手机 #52：聊天跟随、限时等待与直连取证

2026-11-15；基线 `601087e`，当前工作分支 `fix/mobile-ui-regression-51`，源码版本 `1.3.0+57`。既有 PR #5/#6 已合并；本单沿当前工作树增量施工。

## 根因与改动

1. 主动发送仍检查旧 `following`，读历史时发送不会回最新。`ChatController._enqueueOutgoing` 现在在消息落盘成功后显式恢复跟随、清未读、展示发送行；文本、引用和附件共用这条路径。
2. 原逻辑从 1px 底距和 pixels 变化推断阅读意图，把键盘、视口及布局调整误作上翻。`AnchoredChatList` 现在只从真实拖动及其惯性改变意图；向历史移动立即停止跟随，向最新移动到 80px 范围恢复。`ChatScrollController.followAfterLayout` 合并跳底任务，用意图代际阻止上翻后的旧回调拉回底部，并随惰性列表尺寸修正继续跟随。连接重置清锚点及意图，dispose 阻止排队回调。保留稳定消息 ID/屏内偏移锚点；通知补收尊重阅读模式。
3. HTTP 发送开始直接关闭 typing，等待中没有反馈。现复用原三点气泡，将本地请求等待与分段揭示的 typing 分开，投影为同一个可见气泡。本地等待最多 120 秒，成功/失败/final 对账/暂停/身份切换/dispose 收束；超时或暂停用原用户消息的 uncertain 状态和既有详情入口。消息即使被刷新搬到 history 也能标记。此计时器不重发、不取消后端任务、不证明远端 running。

合成复现：从历史中部发送；短列表连续增长；排队跟随后马上上翻；历史补页并到达 1/10/50 条消息；typing 显隐；等待时暂停或历史刷新移位。修复前分别触发不回底、错误停跟随或无等待反馈。

## 验证与边界

| 验收项 | 自动化证据 | 实机状态 |
|---|---|---|
| 52-A1 | `chat_recovery_upload_test`：读历史时发送恢复 following；实际列表跳底由下面的 widget 用例验证 | NOT RUN |
| 52-A2/A3/A6 | `chat_scroll_anchor_test`：短列表多次增长、近底40px、视口缩小、旧回调失效、真实拖动/惯性回底、显式最新 | NOT RUN |
| 52-A4/A5/B5 | 同文件：补页、1/10/50条到达、删除锚点及typing显隐，同消息误差≤2px；`chat_reveal_test`：真实拖动后多段回复保位 | 后台/键盘实机矩阵 NOT RUN |
| 52-B1/B2 | 注入200ms等待期限，250ms后收束且不重发，迟到成功对账；既有失败、poll先成功/HTTP后超时、换scope回归 | 真实长工具 NOT RUN |
| 52-B3/B4 | pause收束为uncertain，迟到结果不重发；既有重启未知结果、网络失败和身份隔离回归 | 杀进程/弱网 NOT RUN；跨进程running恢复 BLOCKED |
| #51回归 | 全量包含五种顶栏唯一红绿点/详情入口、日夜刷新色、权限组件、大字与布局测试 | 真机 NOT RUN |

最终 `flutter test --no-pub --reporter expanded`：428项通过；`flutter analyze --no-pub`：零问题。滚动/揭示/发送恢复定向49项通过后，增加历史移位覆盖并再次全量通过。结构测试改按真实行数计算，仍保留 AppShell ≤1499 限制。全量同时覆盖协议 fixture、scoped session、Outbox、ACK、实时收件及幂等。

Dev APK及Android回归结果见 [质量记录](../quality/testing-and-dev.md)。无连接设备，未安装、未发布；不以编译或合成用例代表真机验收。

## 网络只读取证

桌面本机配置的公开 origin 为 `https://166-0-22-204.sslip.io`（未输出凭据）；手机已存 origin 因无设备无法读取。取证不修改代理、VPS或应用配置。

| 层 | 2026-11-15 观测 | 能说明什么 |
|---|---|---|
| Windows代理/DNS | HTTP_PROXY、HTTPS_PROXY存在，系统ProxyEnable=1；A解析为198.18.0.148，AAAA未取得结果 | 198.18/15为Fake-IP特征；无法证明关闭VPN后的路由或权威AAAA情况 |
| TCP/TLS | 显式禁用urllib HTTP代理后TCP443成功；TLS1.3、主机名验证通过，证书到期2027-01-13 15:08:14 GMT | 当前路径可到HTTPS；系统TUN仍可能接管，不能算免VPN验收 |
| 公网HTTP | `/mobile/poll`、`/mobile/realtime`未带凭据返回401；`/system/health`404 | 401为到达鉴权闸门，未验证业务鉴权成功；404不是TCP失败 |
| 公网WS | 带Upgrade探测 `/ws/mobile`404、`/ws/desktop`403 | 手机WS未成功升级，桌面403不等于手机可用 |
| VPS监听 | presencekit、nginx active/running；caddy inactive；后端127.0.0.1:8080，公网0.0.0.0:443/80；ufw active且允许443/tcp | 已有标准HTTPS入口；后端不需要改成公网监听。云安全组未独立读取 |
| Nginx | presencekit站点为上述主机名，443 ssl/80，代理127.0.0.1:8080，已有Upgrade指令；另有public-routes include | 不应另建第二套反代；仅摘要不足以证明所有媒体/推送路由通过 |
| 后端loopback | `/ws/mobile`同样404，`/mobile/realtime`401；候选`/mobile/chat/requests/<合成ID>`404 | WS问题不只在公网反代层；需对部署版本、路由注册与WS鉴权拒绝行为继续核查。不能从匿名404断言接口一定不存在 |

没有足够证据归因于运营商封锁、DNS权威污染或单一反代缺项。52-C1/C2的关闭VPN手机Wi-Fi/移动网络及Windows对照全部NOT RUN；C3附件/后台/切网NOT RUN；C4只完成上述分层只读探测，故障注入NOT RUN。C5本次未改入口，无配置迁移。

## 待授权的配置计划与回滚

以下为可执行计划，不是已部署结果。应先完成无VPN对照再选最小变更；不宜在证据不足时直接替换域名、证书或防火墙。

1. Windows及Android分别关闭VPN/TUN/系统代理，在Wi-Fi和流量读取实际DNS；Windows使用 `Resolve-DnsName 166-0-22-204.sslip.io`、`Test-NetConnection 166-0-22-204.sslip.io -Port 443`、`curl.exe --noproxy "*" -I https://166-0-22-204.sslip.io/mobile/realtime`。401可证明到鉴权层；业务验证通过应用安全存储的mobile token执行，不将token放进命令行/日志。另测打开代理的同入口对照。
2. 若无VPN直连通过而DNS返回Fake-IP，仅给该精确主机配置代理软件的DIRECT规则及Fake-IP排除；修改前导出规则，失败恢复原规则。不得用宽泛直连改变其他流量。若无VPN TCP失败，记录运营商/网络/时间和VPS对应连接日志，再核对云安全组；不靠延长Flutter超时解决。
3. `/ws/mobile`先核对生产部署SHA和本地路由合同；对齐后用mobile token/session做真实升级验证。必要的后端部署另行授权，不能通过转发到desktop WS替代。HTTP poll补收保留；不暴露管理面。
4. 如确认Nginx缺必要location/Upgrade，先在服务器保存当前站点及include的副本，仅在现有443站点调整已鉴权路由，保持8080 loopback和证书。变更前后运行 `sudo nginx -t`，通过后才 `sudo systemctl reload nginx`；失败恢复副本、再次校验并reload。完整新配置必须基于取到的原文件差异评审，本次不提供会覆盖现网的通用server块。
5. 如该线路在目标网络持续不可达，再评估持有域名的可靠中继/托管隧道或迁移可直连线路。保留原origin，先用新节点做聊天、WS/HTTP fallback、媒体、通知回源、ACK及重连全链验收；不通过则恢复原节点。证书/域名/DNS变更需提供实际资源及TTL后另行确认；不能承诺全运营商可达。

生产DNS/防火墙/Nginx/证书均未改。工单要求生产配置先提交具体方案供确认；当前也缺少无VPN网络对照，故不推进生产修改。

## 三面闭环

- 后端管理面：本单只有本地短时展示与滚动意图，无新增配置开关、业务状态库或审计。原enabled/effective/观测仍由后端拥有。手机只读running接口仍open，须按owner+char+domain+session+request_id隔离，包含TTL/过期和撤权语义；禁止借desktop endpoint。
- 桌面与Android：桌面仅只读取origin，不改设置/UI；Android权限、通知及后台服务代码未改。设备直连、后台恢复与权限验收仍observe。
- 原调用链：输入→持久Outbox→POST /mobile/chat→final/HTTP/history→Flutter呈现及既有通知补收；保留token/session、request_id、turn_id去重、原顺序、未知结果不重发、ACK/TTL和fallback。暂停仅终止本地动画，不取消远端执行。未新增mobile channel字段或持久状态；三点复用现有本地文案/样式，无新增l10n key。

跨端运行契约无变更；跨端依赖和生产网络限制已同步known-issues及后端三仓总账。跨进程running恢复和免VPN真实网络目标尚未完成。
