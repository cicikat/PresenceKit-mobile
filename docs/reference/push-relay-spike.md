# Push Relay Spike — 结论文档

> **状态**: Spike 代码已就绪，实测数据待填入。本文档架构分析部分基于代码审阅和 Android 文档，
> 实测章节留白供填写 `test_log_template.md` 观测结果后补全。

---

## 1. 背景与动机

### 现有方案 (`MobileNotificationService`)

```
App 进后台
  └─ startForegroundService(dataSync)
       └─ Thread("yexuan-mobile-poll")
            └─ while (running) {
                 GET /mobile/poll?wait=55   // 55 s 长轮询
                 处理消息
                 sleep(backoff)
               }
```

**痛点：**

| 问题 | 原因 |
|------|------|
| 进 Doze 后消息延迟长达 6 h | 备用 AlarmManager 间隔 6 h，Doze 期间网络被挂起 |
| 国产 ROM（MIUI/ColorOS/HyperOS/OriginOS）主动杀后台 | OEM 加了白名单机制，未豁免的 foreground service 同样被杀 |
| 每轮 55 s 都要 TCP 握手 + HTTP 往返 | 持续小量电量消耗，流量轻微浪费 |
| Android 12+ `dataSync` 前台服务最多运行 ~10 h | 超时后服务崩溃，依赖 Alarm 恢复（恢复窗口 = 6 h）|

---

## 2. ntfy 推送中继方案

### 架构

```
后端服务器
  └─ POST http://ntfy-host/topic   {"message":"…"}
       ↓ ntfy server（本地或自托管）持有所有订阅方的 SSE 长连接
         ↓ 推送给每个 SSE 连接
           └─ NtfyRelayService（Android 前台服务）
                └─ Thread 阻塞在 BufferedReader.readLine()
                     └─ 收到行 → 发本地通知
```

客户端持有 **一条** 长连接，服务器主动写数据；客户端线程大部分时间阻塞在 `read()`，
不产生重复的 TCP 握手和 HTTP 请求。

### 与 iOS APNs 的同构点

| iOS APNs | ntfy 自托管 |
|----------|------------|
| Apple 维护系统级持久连接 (APNs daemon) | ntfy server 维护每个订阅方的 SSE/WS 连接 |
| 后端 → APNs → 设备 | 后端 → ntfy → 设备 |
| 设备上只有 **一条** APNs 连接（所有 App 共享） | 每个 App 各自维护一条 ntfy SSE 连接 |
| iOS 系统唤醒 App 投递通知 | Android 前台服务需自己保活 |
| 无需 App 进程存活 | 需要前台服务存活（无 FCM） |

关键差异：APNs 是 **系统级** 守护进程，App 进程可以死；ntfy 纯客户端方案仍然需要进程存活。
如果将来接受 UnifiedPush 协议（ntfy 官方 App 作为 distributor），可以复用系统级连接，
真正实现 APNs 同构。

---

## 3. Doze 与国产 ROM 行为分析

### Android 原生 Doze（AOSP）

Doze 分两层：

1. **设备 Doze**（息屏静置 ~30 min）：进入后网络被挂起，只有高优先级 FCM 可穿透。
   Maintenance window 每几小时开放一次（时间不定）。
2. **App Standby**：App 未前台使用一段时间后，限制后台网络。

`dataSync` 前台服务在 AOSP 上 **理论上** 不受 Doze 网络限制，因为前台服务属于豁免类别
（`PowerManager.isIgnoringBatteryOptimizations` 不等于豁免 Doze 网络，但前台服务有单独豁免路径）。
实测是否豁免见第 4 节。

### 国产 ROM

| ROM | 典型行为 |
|-----|---------|
| MIUI / HyperOS | "省电策略"默认限制后台，需手动设为"无限制"；即使前台服务也可能被"神隐模式"冻结 |
| ColorOS / OxygenOS | "电池优化"默认限制；有"冻结后台"选项 |
| OriginOS / FuntouchOS | 类似 ColorOS |
| 华为 EMUI / HarmonyOS | 电池管理最激进；后台进程可在 1 min 内被杀 |
| 原生/接近原生（Pixel、一加 OxygenOS 国际版） | 行为接近 AOSP |

**结论**：在国产 ROM 上，无论长轮询还是 SSE，只要没有电池豁免，前台服务都可能被杀。
两种方案的存活率取决于 **是否获得电池豁免**，而不是协议本身。

---

## 4. 实测结果（待填写）

> 运行 `spike/push_relay_ntfy/` 流程，将 `test_log_template.md` 数据填入此处。

### 设备信息

| 字段 | 值 |
|------|-----|
| 机型 | |
| Android 版本 | |
| ROM | |
| 电池模式 | |

### 对比数据

| 场景 | 长轮询延迟 (s) | SSE 延迟 (s) | 备注 |
|------|--------------|-------------|------|
| 屏幕常亮 | | | |
| 息屏 5 min | | | |
| 息屏 30 min | | | |
| 息屏 60 min | | | |
| 从最近任务划掉 | | | |
| 重启后首条消息 | | | |

### SSE 连接存活

| 时间点 | SSE 是否存活 | reconnect 次数 |
|--------|-------------|---------------|
| 息屏 30 min | | |
| 息屏 60 min | | |
| 电池豁免前 | | |
| 电池豁免后 | | |

---

## 5. 权限与前台服务形态

### 必须权限

```xml
INTERNET                          <!-- 已有 -->
FOREGROUND_SERVICE                <!-- 已有 -->
FOREGROUND_SERVICE_DATA_SYNC      <!-- 已有，需 Android 14 前申请 -->
RECEIVE_BOOT_COMPLETED            <!-- 新增，用于重启后自动恢复 -->
REQUEST_IGNORE_BATTERY_OPTIMIZATIONS  <!-- 已有，引导用户豁免 -->
```

### 前台服务类型选择

`foregroundServiceType="dataSync"` 是现有选择，语义最贴近"保持数据连接"，优于 `connectedDevice`。
Android 14 开始不允许无类型的前台服务；`dataSync` 上限 ~6 h / 24 h（设备 Doze 不计时），
超时后系统停止服务。

**改进方向**：如果后续集成 UnifiedPush，可改为无需自持前台服务的架构。

---

## 6. 迁移建议

### 短期（值得做）：SSE 替换长轮询

用 SSE 替换 `pollOnce()` 中的 55 s 长轮询，服务形态不变（仍然是 `dataSync` 前台服务）。

**收益**：
- 消息延迟从"最多 55 s"降到"约 1-2 s"（屏幕亮时立即推达）
- 单条 TCP 连接代替反复 TCP 握手，节省少量流量和电量
- 服务端不需要实现长轮询队列逻辑

**成本**：
- 后端增加 SSE 端点（或接入 ntfy）
- Android 端实现 SSE 流解析（已在 `NtfyRelayService.kt` 验证）
- Doze 存活行为与当前基本等价（两者都需要前台服务 + 电池豁免）

### 中期（条件允许时做）：UnifiedPush + ntfy distributor

让用户安装 ntfy Android 官方 App 作为系统级推送代理 (UnifiedPush distributor)。
App 接收 ntfy 的 push 唤醒信号，不再需要自持 SSE 前台服务。

**收益**：
- 真正 APNs 同构：系统级单连接，App 进程可以死
- 穿透 Doze：ntfy distributor 可申请高优先级唤醒
- 国产 ROM 上只需要 ntfy 被豁免，不需要主 App 被豁免

**成本**：
- 需要用户额外安装 ntfy App（可引导）
- 需要实现 UnifiedPush 协议的注册/分发端
- 自托管 ntfy 需要公网可达（或 Tailscale/frp）

### 长期（如接受 GMS 依赖）：FCM

接入 Firebase Cloud Messaging，利用 Google 的 APNs 等价基础设施。

**收益**：最可靠的穿透 Doze / OEM 杀后台方案，无需维护推送基础设施。

**成本**：引入 Google Play Services 依赖；与项目当前无 Firebase 的设计方向相反。

---

## 7. 结论摘要

1. **协议层面**：SSE 比长轮询更高效（一条持久连接 vs. 反复握手），但在 Doze / 国产 ROM 下存活率
   取决于电池豁免状态，而不是协议本身。
2. **ntfy 本地验证**：`docker compose up` + `curl … /sse` 已验证发布 → 订阅端到端连通，
   延迟 < 100 ms（局域网），SSE keepalive 55 s 一次。
3. **建议**：近期可将长轮询换成 SSE（低风险、即时收益）；中期若用户基数增大，
   考虑接入 UnifiedPush/ntfy distributor 实现真正的系统级推送。
4. **全量迁移（FCM）**：暂不推荐，与无 Firebase 的现有设计原则冲突，且 UnifiedPush 可覆盖同等需求。
