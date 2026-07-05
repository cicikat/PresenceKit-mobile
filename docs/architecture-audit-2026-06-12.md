# 架构审计 2026-06-12

> 范围：根目录 md + docs/ + AndroidManifest + 全部 Kotlin 原生层 + `lib/main.dart` 生命周期/轮询/HTTP 关键段。
> 结论先行：通知不生效大概率不是单点 bug，而是「常驻轮询对抗 Android 平台」这一架构前提 + 三个消费者抢一个队列 + 闸门全静默叠加的结果。下面按"为什么不生效"→"会反复返工的结构问题"→"修复顺序"展开。

---

## 一、通知栏不生效：根因链（按可能性排序）

### 1. Doze / OEM 杀后台：前台服务救不了网络

`MobileNotificationService` 是 dataSync 前台服务 + 裸线程长轮询。关键事实：

- **前台服务不豁免 Doze 的网络挂起**。息屏静置几分钟后进入 Doze，应用网络被系统挂起，`getJson()` 的长轮询会阻塞/超时，只有 maintenance window 才放行。表现就是"息屏后一条都收不到"。
- 没有申请电池优化豁免（manifest 无 `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`），没有 WakeLock，没有 AlarmManager/WorkManager 兜底唤醒。
- 目标设备明显是国产 ROM（美团/淘宝包名）。MIUI/HyperOS、ColorOS 等默认会杀掉非白名单应用的前台服务，且不走 START_STICKY 重启。用户从最近任务划掉 App 后服务直接死亡，重启前不会再活。
- 设备重启后无 `BOOT_COMPLETED` 接收器，服务永远不会自启。

**这是结构性的：轮询常驻方案在现代 Android 上"默认就是不工作的"，能工作才是例外（豁免 + 白名单 + 厂商不抽风）。**

### 2. 服务启动路径脆弱：可能根本没起来

- `MainActivity.onStop()` 里 `startForegroundService()`。Android 12+ 对"后台启动 FGS"有限制，onStop 时机处于离开前台的边缘窗口，部分 ROM/时机会抛 `ForegroundServiceStartNotAllowedException`，**代码没有 try/catch**，等于每次退后台赌一把。
- `onStartCommand()` 先查闸门（token/origin）、不过就 `stopSelf()`，**之后才** `ensureForeground()`。被 `startForegroundService()` 拉起的服务若没在时限内调 `startForeground()`，系统抛 `ForegroundServiceDidNotStartInTimeException` 直接崩。正确顺序是：进入 onStartCommand 无条件先 startForeground，再判断闸门，不满足再 stopForeground+stopSelf。
- targetSdk 跟 Flutter 默认走。**Android 15 对 dataSync FGS 有 6 小时/24h 运行上限**，到点系统回调 `onTimeout()` 并停服务——代码完全没处理，意味着在新系统上"用半天后通知悄悄失效"。

### 3. 闸门把消息吞了，而且吞得毫无声息

- 静音时段 23:30–06:30 + **30 分钟全局冷却**：一批消息里只有第一条能弹，之后半小时内全部静默；夜间测试一条都看不到。
- 被吞的消息只体现在 IMPORTANCE_MIN 常驻通知的文字里（基本不可见）。
- 轮询失败无退避（known-issues P1），且注释明说 "service stays quiet"——**后台层所有错误零上报**。断网、token 失效、origin 不被信任、解析失败，全都表现为"什么也没发生"。
- `POST_NOTIFICATIONS` 在 `onCreate()` 直接弹，用户拒绝两次即永久拒绝，之后 `notify()` 静默无效；服务侧不检查也不提示。

### 4. 三分钟定位法（建议先做）

1. 能力检查页跑 `debugBackgroundDelivery`（这条不走轮询直接进通知管线）→ 能弹说明通知管线本身通，问题在服务/轮询/闸门；不能弹说明权限/渠道问题。
2. 退后台后看**常驻通知"叶瑄后台接收"是否存在** → 不存在 = 服务没起来或被杀（根因 1/2）；存在但收不到消息 = Doze/闸门/队列竞争（根因 1/3 和下文二.1）。
3. `adb logcat -s YexuanMobileService` + `adb shell dumpsys deviceidle` 确认 Doze 状态。

### 修复方案（通知专项）

| 项 | 做法 | 成本 |
|---|---|---|
| startForeground 顺序 | onStartCommand 第一行无条件 startForeground，闸门不过再 stopForeground(true)+stopSelf；startForegroundService 调用处 try/catch | 半小时 |
| 失败退避 + 心跳 | 失败指数退避 1s→60s 封顶，成功重置；每轮写 `lastBackgroundPollAt`，能力页显示"最近心跳 / 最近错误原因" | 半天 |
| 电池豁免 | 能力页加一项：检测 `isIgnoringBatteryOptimizations`，跳 `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`；附 OEM 自启动白名单引导文案 | 半天 |
| 闸门可视化 + 旁路 | 被吞计数/原因已在 prefs，搬到能力页展示；加"测试模式绕过静音和冷却"开关 | 半天 |
| Android 15 | 实现 `onTimeout()`，用 `AlarmManager.setExactAndAllowWhileIdle` 或 WorkManager 周期补轮询拉活 | 1 天 |
| 长期方向 | 自托管推送中继（ntfy / UnifiedPush）替代常驻轮询：后端有新消息时 POST 给中继，手机端只挂一条由中继维护的连接。这同时是 iOS（APNs）那条路的同构方案，README 里"中继层"的设想是对的，建议提前到 Android 上做 | 2–3 天 |

---

## 二、会反复返工的结构问题（边界与耦合）

### 1. 一个破坏性队列、三个消费者、没有消息所有权 ⚠️ 最高优先

`/mobile/poll` 是破坏性读取（读完即删），但消费者有三个：

- Flutter 前台 5 秒轮询；
- Android 后台长轮询；
- **僵尸线程**：`onResume → stopService → onDestroy` 只把 `running=false`，但在途的 55 秒长轮询（readTimeout 70s）会继续完成并**照常消费消息、照常发通知**——用户已经回到 App 里，消息却被死掉的服务领走变成通知，或反过来在交接窗口被错误一端吞掉。"她总在我刚退出/刚回来时回复"恰好是最常踩的窗口。

去重又是**45 秒内容指纹**而不是消息 id：两条内容相同的合法消息（"在吗？"×2）会被吞掉一条。

**修复：**
- 短期（纯客户端）：a) `onDestroy()` 主动 `disconnect()` 在途连接 + generation 计数器，过期轮次的结果一律丢弃；b) 去重改用 `message.id`，内容指纹只留作 `/desktop/chat` 同步回复兜底。
- 中期（动后端，一次性解决）：poll 改非破坏性 + ack 游标（`GET /mobile/poll?after=<id>` + `POST /mobile/ack`），或带 `consumer_id`。消息所有权问题从根上消失，前后台交接不再需要精确编排。

### 2. 信任策略双实现，必然漂移

origin 校验规则在 Kotlin（`BackendSecurityPolicy`）和 Dart（`_isAllowedBackendBaseUrl` / `_isConfirmablePrivateCleartextOrigin` 等）各写了一份。两边解析器不同（`java.net.URL` vs Dart 正则/Uri），未来任何一边改规则（比如想支持 mDNS 主机名、IPv6、新网段）都会出现**前台能连、后台拒连**——而后台拒连是静默的（直接 stopSelf），正是"通知莫名不工作"的再生产机制。

**修复：** Kotlin 作唯一真值，Dart 侧删除本地实现，通过 MethodChannel 加 `isAllowedBaseUrl` / `normalizeOrigin` 两个查询方法。确认对话框的 UI 判断也走同一通道。

### 3. behavior 映射双实现 + substring 匹配是语义事故源

映射逻辑 Dart（`_handleForegroundBehavior`）和 Kotlin（`overlayRequestFor`）各一份，且用的是子串匹配：

- `behaviorIdLower.contains("lock")` → `"blocked"`、`"unlock_hint"` 都会弹**锁屏确认浮窗**；
- `contains("order")` → `"reorder"`、`"border"` 都会弹**外卖购物浮窗**并尝试打开美团。

这直接冲撞你们自己定的安全边界（"高强度行为不得由普通消息升级"）。后端将来随手起一个 behavior_id 就可能在手机上触发完全不相干的高强度 UI。

**修复：** 改为精确白名单枚举（`lock_screen_confirm`、`takeout_overlay`、显式 id 集合），**未知值一律降级普通通知**；映射表只在 Kotlin 写一份，Flutter 前台经 MethodChannel 调同一份。同步更新 `docs/protocols/mobile-channel.md`，把"未知 metadata 的默认降级行为"写进协议。

### 4. SharedPreferences 当跨组件总线

`backgroundNotificationServiceRunning`、`lastMessageNotificationAt`、`suppressedMessageNotifications` 由 Activity、Service、Flutter 三方读写，`apply()` 异步，已知会漂移（known-issues 已记 P2）。规则建议：**每个键只允许一个写者**——服务状态以 `lastBackgroundPollAt` 心跳为准（UI 只读），冷却/抑制状态归 Service 独占，Activity 不再代写 running 标志。

### 5. 生命周期是两台不同步的状态机

Flutter `didChangeAppLifecycleState` 管前台轮询的起停，Activity `onStop/onResume` 管服务起停，两边各自为政，交接窗口（见二.1）就是它们的缝。**修复：** 前/后台裁决收敛到原生一处（`ProcessLifecycleOwner`），由它发起服务起停，并通过 MethodChannel 通知 Flutter 起停页面轮询；Flutter 不再独立判断。

### 6. `/desktop/chat` 复用 + 指纹去重是协议债

手机发消息走桌面端入口，回复又可能同时从同步响应和 mobile queue 到达，客户端靠 45 秒内容指纹擦屁股。正确解法在协议层：后端给回复带 `message_id`（同步响应和 queue 里同一 id），客户端按 id 去重。这一项和二.1 的 ack 改造可以一次做完。

### 7. `lib/main.dart` 9.7k 行 god file

已知问题，但要补一个前置条件：**本机 `flutter test` 起不来（known-issues P2）→ 没有任何保护网的重构等于裸奔**。先修测试环境（或临时用 CI/另一台机器跑 test），再按 docs 既有顺序（models → services → pages → widgets）做无行为搬移。在测试可用前，只做"新代码必须写进新文件"的增量纪律，不动存量。

---

## 三、其他平台前提性风险（短句记录）

- targetSdk 随 Flutter 升级隐式漂移，Android 14/15 行为变化（FGS 限时、精确闹钟权限）无人验证——升级 Flutter 后必须过一遍后台链路。
- release 用 debug signing、applicationId 为模板包名（known-issues P3）：换包名会重置所有权限授予和通知渠道，**越晚换成本越高**，建议在下一次"需要重装"的节点顺手做掉。
- 通知渠道 delete/recreate 版本 hack：同 id 渠道重建会**继承用户旧设置**（importance 不会被代码抬升）。如果某台设备上消息渠道曾被设为静默，代码无法救回，只能换渠道 id——排查"个别设备收到但不响"时记得这条。
- 截图里 `FloatingBubbleService` 硬编码示例订单（known-issues P2）与安全边界叙事冲突，建议先撤内容只留确认文案。

---

## 四、建议执行顺序

1. **可观测性先行**（半天）：startForeground 顺序 + try/catch + 退避 + 心跳/错误原因上能力页。做完这步，"不生效"会变成一个可读的原因字符串。
2. **平台对抗**（半天）：电池豁免 + OEM 白名单引导 + 闸门测试旁路。
3. **消息所有权**（1 天客户端 / +1 天后端）：id 去重、僵尸线程终止；后端配合就上 ack 游标。
4. **单一真值收敛**（1 天）：信任策略和 behavior 映射删掉 Dart 副本，未知 behavior 一律降级。
5. **长期**：推送中继替代常驻轮询（顺便铺 iOS 路）；修测试环境后再拆 main.dart。

第 1、2 步做完后通知问题大概率直接定位或消失；第 3、4 步消的是未来反复返工的根。
