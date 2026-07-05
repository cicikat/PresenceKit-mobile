# Round · 鉴权分层 — Scoped Tokens（移动端）

> 配对文档：`Emerald-presence/cc-tasks/21-鉴权分层-scoped-tokens.md`（后端主文档，scope/profile
> 定义以其 §2 为准）、`Emerald-client/cc-tasks/13-auth-scoped-tokens-client.md`（桌面端，语义同源）。
> **前提：后端 Brief 21 已施工完毕**（scope 校验已生效，legacy secret 仍等价 admin）。

## 0. 现状盘点（已核对代码）

- 本 app 当前持有后端 **god token**：native `SharedPreferences`（`yexuan_memery` / key
  `adminToken`，明文），Flutter 经 MethodChannel（`getAdminToken`/`setAdminToken`，
  `MainActivity.kt`）读写，`MobileNotificationService.kt` 后台长轮询直接读同一 prefs
  （`BackendSecurityPolicy.adminToken()`）。
- 实际调用的后端端点全集（Flutter `lib/services/backend_client.dart` + Kotlin 原生侧）：

| 端点 | 所需 scope（按 Brief 21 §5） |
|---|---|
| `/desktop/chat`、`/mobile/activate|deactivate|poll|ack|push`、`/upload/ingest` | chat |
| `/garden/state`、`/status`、`/sensor/behavior/status`、`GET /system/meta-mode` | state.read |
| `/chat-log/dates`、`/chat-log/{date}`、`/diary/list`、`/diary/{date}` | memory.read |
| `/dream/state|settings|enter|chat|exit` | activity |
| `/settings/prompt-assets`、`/jailbreak-entries`、`/lorebook`、`/characters/active-info` | persona |
| `POST /sensor/realtime`（屏幕上下文 + self-focus 信号） | sensor.write |
| `GET /system/data-path`（仅能力检查页诊断） | **admin — mobile token 拿不到，见 §2.3** |

- 所以 **`mobile` profile = chat, state.read, memory.read, activity, persona, sensor.write**
  （不含 hardware / admin / ws.*）。手机是最易丢失的设备：丢机后攻击者拿不到危险模式开关、
  settings 写、硬件控制，且 token 可在后端一键吊销。
- ntfy 中继链路（`relayToken` / `relayTopic`）是**独立信任域**：signal-only，正文回源
  `/mobile/poll`（见 `docs/protocols/relay-publish-contract.md`），与后端 scope 模型无关，本轮不动。
- `BackendSecurityPolicy` 的 cleartext origin 信任策略（https 放行、Tailscale CGNAT 内置、
  私网需确认）已经良好，本轮不动。

## 1. 后端增补（在 Emerald-presence 仓执行；若 Brief 21 施工时已包含则跳过）

Brief 21 原稿按「手机=瘦轮询端」设计，与本仓实际不符。两处 delta（Brief 21 文件已同步更新，
以下为兜底描述，施工前先核对后端现状）：

1. `mobile` profile 的 scopes 改为 §0 的六项。
2. `/system/meta-mode` 映射拆分：**GET → state.read**（手机能力检查页只读展示），
   PATCH → hardware 不变。
3. 用 `POST /auth/tokens {label: "mobile-main", profile: "mobile"}` 签发手机 token。

## 2. 移动端改动

### 2.1 Token 配置语义（几乎零代码）

- 存储键、MethodChannel、prefs 结构**全部不改**。变的只是填进去的值：从 admin secret 换成
  mobile profile token（`emt_…`）。
- 系统设置里 token 输入弹窗的说明文案更新：「填后端签发的 mobile token（emt_ 开头）；
  旧 admin secret 仍可用但不建议」。

### 2.2 401 / 403 / 429 区分

后端新语义：401 = token 无效；403 = token 有效但 scope 不足（detail 含所需 scope）；
429 = 认证失败次数过多被临时限制。

- `backend_client.dart` `_extractError(body, statusCode)`：按 statusCode 分支文案——
  401「token 无效，请检查系统设置里的 token」；403「token 权限不足：{后端 detail}」；
  429「认证失败过多，来源已被临时限制，稍后再试」。错误信息不得包含 token 值。
- `MobileNotificationService.kt`：长轮询错误分类目前把认证失败归为 "token invalid"
  （~L602 附近）。改为：401 → 维持 "token invalid" 语义；**403 → 独立错误
  "token scope insufficient"，并停止本轮重试循环**（scope 配错重试无意义，避免刷后端审计日志
  和触发 429），记入 `recordBackgroundError` 供能力检查页展示。

### 2.3 能力检查页对预期 403 的呈现

`fetchDiagnostics()` 并发探测 7 个端点、逐项 catchError。mobile token 下
`GET /system/data-path` 会**预期性 403**：

- 诊断结果渲染时识别 403：显示中性状态「无权限（mobile token 预期行为）」，
  不渲染成红色故障。其余端点的 403 照常显示为待排查错误（说明 profile 配错）。

### 2.4 可选加固（独立提交，可跳过）

- token 存储迁移 `EncryptedSharedPreferences`（androidx.security.crypto）：
  首次启动时把明文 `adminToken` / `relayToken` 迁入加密 prefs 并清除明文键。
  注意 `MobileNotificationService` 与 `MainActivity` 读同一 prefs，必须同轮迁移，
  且迁移失败要回退明文读取（fail-open），不能让后台轮询哑火。

### 2.5 文档同步

- `docs/backend/integration.md`：新增「鉴权」小节——mobile profile scope 表、401/403/429 语义、
  token 签发/吊销指向后端 `docs/security.md`。
- `docs/known-issues.md`：记一条「已收缩：手机端不再持有 admin 全权 token」。
- `AGENTS.md` 当前实际状态段补一行 token 语义。

## 3. 验收

1. 用 mobile profile token 全流程冒烟：主对话收发、前台 5s 轮询 + 后台长轮询通知、
   chat-log/日记/花园页、dream 进出与对话、资料页、设置页（prompt-assets / lorebook /
   破限读写）、屏幕上下文上传、上传文件。任何非 data-path 的 403 = 后端映射或 profile 缺口，
   回报后端仓修表，**不得**换 admin token 绕过。
2. 能力检查页：data-path 显示「无权限（预期）」，其余全绿。
3. 故意填坏 token → 401 文案正确；故意用 sensor profile token → 403 文案正确且后台服务
   停止重试、能力检查页可见 "token scope insufficient"。
4. `flutter test` 全绿（`_extractError` 分支补单测）。
