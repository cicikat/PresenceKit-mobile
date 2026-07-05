# 架构审计 R2（代码级专项深挖）2026-06-12

> 范围：`FloatingBubbleService.kt`、`YexuanAccessibilityService.kt` 全文，`accessibility_service.xml`、`device_admin.xml`，`main.dart` 的 origin 策略 / BackendClient / behavior 映射 / 去重 / 屏幕上下文 / 上传 / 启动恢复段，test 与 git 状态。
> 本文只写**与第一轮不同**的内容：判断修正 + 新发现。第一轮结论除特别说明外维持。

---

## 一、对第一轮判断的修正与确认

### 1.1 双实现漂移：不是"未来会漂"，是**已经漂了**

第一轮说 Dart/Kotlin 两份 behavior 映射"将来会漂移"。代码证实当下就不一致：

- **大小写**：Dart 的锁屏判断 `behaviorId.contains('lock')`（main.dart:2920）是**区分大小写**的，`lowerBehavior` 在它之后才定义；Kotlin 全程 lowercase。`behavior_id: "Lock_screen"` 前台不弹锁屏浮窗、后台弹。
- **门槛不同**：Dart 先过 `wantsOverlay` 总闸（必须有 overlay/attention_grab/direct_act 等指示）才进入模式分支；Kotlin 的 `when` **先**匹配 lock/order 子串，**不需要任何 overlay 指示**。同一条消息：前台普通显示，后台直接弹锁屏/外卖确认浮窗。后台比前台激进，方向反了。
- **未文档化字段**：Kotlin 读 `behavior.requires_confirmation`（MobileNotificationService.kt:337），Dart 不读，`docs/protocols/mobile-channel.md` 也没写。协议文档已滞后于代码。

### 1.2 子串匹配的危险比第一轮估计的更具体

`"block".contains("lock") == true`。任何 `behavior_id` 含 `blocked` / `unblock` 的消息都会命中**锁屏确认浮窗**分支。后端 `sensor_aware` 模块恰好有 `isBlocked / blockedReason` 这一族命名——后端将来用同族词命名行为 id 的概率不低。这从"理论风险"升级为"高概率事故"。

### 1.3 一处第一轮怀疑、代码核实后排除的项

`BackendClient._endpoint(path, {token})` 接收 token 只用于"凭证为空就抛错"的前置校验，**token 不进 URL**，统一走 `Authorization` header。无泄漏。`/upload/ingest` 的 multipart 也正确带 header。

### 1.4 文档与代码的滞后点

- `ARCHITECTURE.md` 说前台主动消息流程是"追加 him 消息 → 可选悬浮窗"，但代码里前台**先过 45 秒内容指纹去重**再追加，文档未提。
- `mobile-channel.md` 的映射表与两端实现都对不上（见 1.1），三个版本各自为政。

---

## 二、新发现问题（按严重度）

### P1：FloatingBubbleService 是 START_STICKY —— 幽灵浮窗

`onStartCommand` 返回 `START_STICKY`，但浮窗的全部状态（mode/message/target）都在 intent 里。系统因内存回收后重建服务时 intent 为 null → `showBubble(null)` → mode 为空 → **凭空弹出一个默认文案浮窗**（"我在。读完回来跟我说一句。"）。用户视角：手机放着没动，浮窗自己出现。

**修复**：改 `START_NOT_STICKY`；`onStartCommand` 开头 `if (intent == null) { stopSelf(); return START_NOT_STICKY }`。两行。

### P1：锁屏确认浮窗单击即锁屏，且无防误触

`addLockContent` 的"替我锁屏"是一个 9.5sp 的 TextView，点击直接 `lockNow()`（FloatingBubbleService.kt:242,413-422）。浮窗可拖动、tap 容差 8dp，悬浮在任意 App 上层。配合 1.2（`blocked` 误触发锁屏浮窗），链路是：后端一个不相干的 behavior_id → 后台弹锁屏浮窗 → 用户在刷视频时误触一下 → 屏幕锁了。

**修复**（任选其一，建议都做）：a) 锁屏按钮加二段确认（长按或两次点击）；b) 浮窗出现后前 800ms 忽略点击（防止与正在进行的触摸流重叠）；c) 配合修掉子串匹配（白名单精确 id），从源头消除误弹。

### P1：无障碍服务在系统全局每次内容变化都做全树遍历

`accessibility_service.xml` 订阅了 `typeWindowContentChanged`，`notificationTimeout=100ms`；`onAccessibilityEvent` → `updateScreenSnapshot` 对**所有 App 的每次内容变化**做深度 8、最多 80 节点文本的树遍历 + 敏感词扫描（YexuanAccessibilityService.kt:19,68-108）。刷信息流时每秒可触发多次。这是**全系统级**的输入延迟和耗电税，且与上传开关无关——开关只控制上传，采集一直在跑。

另外 `captureScreenContext()` 被后台轮询线程直接调用 `activeService?.updateScreenSnapshot(null)`（companion:282-285），即**在轮询线程上做无障碍节点遍历**，与主线程的事件驱动遍历并发，快照可能撕裂（混合两个时刻的屏幕）。

**修复**：a) 事件回调里只记"脏标记 + 包名"，不遍历；b) 真正的遍历改为**按需**（captureScreenContext 被调用时）+ 节流（如最短间隔 5s），统一 post 到服务自己的 Handler 执行，调用方等结果；c) 上传开关关闭时连采集都不做（目前能力页调试需要采集，可以单独给调试路径放行）。

### P2：前台 45 秒屏幕上下文上传的是自己——污染后端评分

App 在前台时，`rootInActiveWindow` 就是叶瑄 App 本身。前台定时推送等于每 45 秒把**自家聊天界面的可见文本**（对话内容、按钮文字）作为"屏幕上下文"喂给后端 `sensor_aware` 客观评分。既浪费，又把聊天内容二次注入传感通道，还可能因聊天里出现"支付/密码"等词被自家过滤器拦掉产生噪声日志。

**修复**：Dart 侧推送前判断 `snapshot.packageName == 自己的包名` 时，改为只发 `{app: self, title_hint: "yexuan_app"}` 的最小事件（后端仍知道"用户正在看我"），不带正文。

### P2：敏感过滤是"默认放行的黑名单"，方向错了

`sensitivePackageHints` 黑名单约 15 个子串（alipay/bank/weixin…）。未覆盖：密码管理器（Bitwarden/1Password/KeePass）、邮箱、Telegram/QQ、笔记类、相册。任何新装的 App 默认**允许全文上传可见文本**。对"任意屏幕文本上传到后端"这种能力，默认放行黑名单是错误的安全方向；known-issues 里"继续扩充黑名单"治标不治本。

**修复**：改为**白名单模式**（仅用户明确勾选的 App 允许上传正文，其余只上报包名/App 名），能力页给勾选 UI。黑名单保留作白名单内的二次拦截（如美团里的支付页）。

### P2：后台通道完全没有去重，前台的指纹去重护不到它

45 秒指纹去重只存在于 Flutter 内存（`_recentAssistantReplies`）。场景：用户发消息 → 后端同步响应已在前台显示 → 用户立刻退后台 → 同一条回复从 mobile queue 被后台服务取走 → **弹通知，通知的还是用户刚看过的那句话**。第一轮提的"id 去重 + ack"在后台侧同样必须做；短期可在 SharedPreferences 存最近 N 条已展示消息 id（前后台共写就要约定单写者：建议改为"前台显示过的同步回复 id 由 Flutter 写入，服务只读"）。

### P2：购物车辅助点击会点到任何含"购物车"的节点

16 秒窗口内点击**第一个**文本/描述含"购物车"的节点的可点击祖先（YexuanAccessibilityService.kt:184-211）。美团/淘宝首页的"购物车满减""加入购物车"banner、商品卡片按钮都会命中——可能把商品**加进购物车**而不是打开购物车页，这恰好越过你们"不自动加购"的红线。

**修复**：匹配条件收紧为"文本**等于**'购物车'或 viewId 含 cart 的导航类节点"（已开 `flagReportViewIds`，可用 `viewIdResourceName`）；找不到就放弃，不降级模糊点击。

### P3：HTTP 层 15 份复制粘贴样板

`BackendClient` 每个端点手写一遍 `HttpClient` 创建/header/超时/状态码/JSON 校验/异常翻译（约 1.5k 行重复）。改鉴权、加重试、改超时要改 15 处。**修复**：收敛成一个 `_request()` 私有方法 + 各端点只写 path/解析器。这是拆 main.dart 前最划算的第一刀（纯机械、低风险、立刻减 1k+ 行）。

### P3：仓库卫生——`yexuan-Flutter (1)/` 是桌面端 JSX 设计稿

根目录混着一份桌面前端参考实现（app.jsx/chrome.jsx/design-canvas.jsx…）。你担心的"codex 照着电脑前端跑"会被它持续强化：任何全仓检索的 agent 都会把这些 JSX 当作本项目代码参考。`build/`、`tmp/` 也在根目录。**修复**：移出仓库或挪到 `docs/reference/desktop-jsx/` 并在 AGENTS.md 声明"仅设计参考，禁止照抄实现"；`.gitignore` 补 `build/ tmp/`。

### P3：git 历史只有 5 个粗粒度 checkpoint

最近提交 06-09，单次提交动辄全仓。即将进行的 main.dart 拆分和本审计的修复需要**小步提交**才可回退；建议先约定：一个修复 = 一个 commit，拆分期间禁止混入功能改动。

---

## 三、诊断捷径（新增，针对"通知不生效"）

代码里有个现成的不对称可以利用：能力页 `debugBackgroundDelivery` 不带 behavior 时**直接调 `showMessageNotification`，绕过静音/冷却闸门**；带 behavior 时走真实闸门链路。所以：

- debug 无 behavior 能弹、真实消息不弹 → 问题在闸门（静音/冷却）或轮询链路（服务没活/Doze/解析）。
- debug 无 behavior 也不弹 → 问题在权限/渠道（POST_NOTIFICATIONS 被拒或渠道被用户静音过——渠道重建继承旧设置，代码救不回，只能换渠道 id）。

这个二分比第一轮给的排查顺序更快，建议直接做。

---

## 四、修复优先级（仅新增项，与第一轮清单合并执行）

| 序 | 项 | 成本 |
|---|---|---|
| 1 | FloatingBubbleService 改 START_NOT_STICKY + null intent 防御 | 10 分钟 |
| 2 | behavior 映射改精确白名单（同时修掉 1.1 的大小写/门槛不一致；未知 id 一律降级普通通知） | 2 小时 |
| 3 | 锁屏按钮二段确认 + 浮窗出现 800ms 内忽略点击 | 1 小时 |
| 4 | 无障碍采集改按需 + 节流 + 单线程化 | 半天 |
| 5 | 前台上下文自指过滤（packageName == self 只发最小事件） | 1 小时 |
| 6 | 购物车匹配收紧为精确文本/viewId | 1 小时 |
| 7 | 屏幕上传改白名单模式 | 1 天 |
| 8 | BackendClient 样板收敛 `_request()` | 半天 |
| 9 | 仓库卫生（JSX 移位、.gitignore、提交纪律） | 半小时 |

第一轮的"可观测性先行 + 电池豁免 + 消息所有权"仍是通知问题的主线；本轮 1–3 是**安全边界**问题，建议插队到主线之前——它们是"用户会被误锁屏/误加购"级别的事故源。
