# 手机可靠消息收件（工单42，2026-10-24）

这是工单41审计后的R0/R1实现。独立mobile WS属于后续工单43，不复用desktop WS；多手机独立游标不在本期。

## 已实现

- **请求总期限与真实取消**：BackendClient六类HTTP入口共用HttpRequestBudget。打开请求（含HTTPS CONNECT）最多8秒，认证/打开/请求头/正文共享总期限；普通HTTP20秒、聊天120秒、上传180秒，其他方法保留各自timeout。过期关闭该请求独占client，接收取消只影响poll/activate/ack，不误伤发送与上传。保持用户代理/VPN选择，没有隐式DIRECT或绕VPN。暂不共享client连接池，避免取消poll连带中断未知结果的发送。
- **连续前台收件**：wait=25、limit=50，成功后100ms让出事件循环再补下一页，无固定5秒空档；失败1/2/4/8/16秒退避。history与首次收件并行，经既有身份/出现次数对账。pause/resume、连接变化、网络变化切换receive epoch，旧回包及finally不能覆盖新任务。
- **网络恢复**：原生MobileNetworkObserver观察默认网络，150ms合并可用/丢失/能力/路由变化；只在网络归属、可达性、传输类型或DNS/路由/代理/MTU改变时恢复，忽略纯带宽/信号和重复链路回调，避免取消健康收件。`presence_mobile/network` EventChannel只传递递增epoch，NetworkStatusService注入ChatController；不传地址、VPN名或凭据，不改AppShell领域状态，不新增权限（复用ACCESS_NETWORK_STATE）。后台同一观察器中断旧relay/poll并缩短恢复等待；没有relay的已退出服务仍依赖系统补偿，不能承诺即时唤醒。
- **完整本机inbox**：复用原pendingMobileEnvelopes，最多500条。前台所有角色的poll信封在seen/UI/服务端ACK前先落盘；request_id、turn_id/id、seq、display_text、artifacts、sticker、完整behavior、voice_available随信封保存。后台也保留空正文的附件/贴纸信封，不额外生成空通知。
- **非删除交接**：新增peekPendingMobileEnvelopes，只有当前scope/epoch已接纳到页面状态之后才调用ackPendingMobileEnvelopes，以origin+owner+charId及精确id+seq确认。迟到peek不删除信封，进程重开可读；确认写盘失败保留错误。legacy consume方法保留旧ABI，新页面不再使用。页面状态接纳不是逐像素绘制确认；已确认后的历史恢复仍由后端canonical history负责，不宣称手机离线完整历史库或跨重启exactly-once。
- **平台通道期限**：收件相关设置/落盘/peek/ack调用8秒期限，后台服务running只读查询2秒后降级为false；不改变等待用户操作的文件选择/权限对话框。
- **后台失败补收**：收到signal但回源失败，保留待补收标志，单worker按1/2/4/8/16/30秒（上限30）退避，成功清除；网络变更/服务销毁使旧代失效，连接恢复时立即补拉。401/403等终止型凭据错误不持续刷请求。15分钟alarm保留为漏signal/非驻留服务补偿，不作为前台轮询节拍，也不承诺Doze下硬期限。
- **后端确认与入队顺序**：19176cc修复ACK safe_write_json(False)仍成功；异常向上传播，不返回ok=true；重复ACK幂等。mobile durable mirror在其他通道的网络发送/动作ACK前持久化，其他通道相对顺序和fanout_failures保留。共享单消费者、seq、TTL、身份与HTTP字段不改。

## ABI与数据边界

新增settings方法：

- `peekPendingMobileEnvelopes({origin, owner, charId}) -> List<envelope>`：非删除读取；只返回归属匹配且可重放的信封。
- `ackPendingMobileEnvelopes({origin, owner, charId, items:[{id, seq}]}) -> remainingCount`：只删除该scope内精确匹配项；无前缀删除，不删除新到达/其他角色/其他节点的信封。
- `stashPendingMobileEnvelopes`从只暂存外角色扩展为完整inbox写入，嵌套Map/List正确转JSON。容量满或写盘失败时不推进后端ACK。原key、legacy SharedPreferences、已有cursor/seen与consume ABI兼容。

inbox数量/上限继续由既有getBackgroundPollStatus的pendingCount/pendingLimit在能力检查页只读显示；失败沿pendingHandoffError/mobileError与lastBackgroundError观测。没有新增服务端台账或第二份业务真值。无新增Flutter可见文案或设置开关，故不新增本地化key。

## 三面与调用链

管理面：未引入运营开关/服务端持久状态，继续使用client_channels与relay设置；mobile effective_state仍只代表活跃TTL，不等同于页面已读。投递分阶段时延/淘汰统计是后续观测缺口，未伪装完成。桌面：只读比对，v0.1 WS、动作权限、连接槽和HTTP不变。

链路：request_id/session冻结 → 生成/工具 → critical持久化 → mobile先入队 → relay/HTTP → 本机完整inbox → UI对账 → 本机精确确认；后端ACK只证明本机已持久接收，不证明已读。保留origin/owner/char隔离、seq排序、角色stash、去重、TTL、取消代际与fallback。未知发送结果保持原request_id，不自动执行有副作用的重试；锁屏/支付/辅助点击授权与确认保留。

## 验收与限制

证据日志保存在 `build/review/mobile-delivery-audit/`（ignored）。失败注入先证实CONNECT和媒体正文卡住、ACK假成功与慢通道顺序，再修复。Flutter与Android、后端最终数量与构建结果见工单42及质量文档；不将历史审计的实验通过误写成真实手机已修。

未连接真机/未安装/未部署服务器，真实V2Ray模式与开关/切节点、Wi-Fi/流量、Doze/OEM后台、真实模型首字/整条p50/p95待验收。独立WS与token流式、独立多设备游标、共享连接池、跨后端重启的持久request receipt仍不在本期完成范围。