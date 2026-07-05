# 工单：移动端后端状态/诊断页 + 主对话双发统一

> 仓库：`D:\ai\yexuan_memery`（Flutter 薄客户端）。先看 `AGENTS.md`，但**注意下面这条前提**。
> 后端 `D:\ai\qq-st-bot` 本工单**不改动**（两项都能在手机端单独解决）。

## ⚠ 前提：AGENTS.md / known-issues.md 已过期，按真实代码施工

文档里写 `lib/main.dart` 是 8k+ 行巨石、`chat_page.dart`/`api_service.dart`/`message_bubble.dart` 是空壳——**这个重构早做完了，别照文档找**。真实布局：
- `lib/main.dart` 现在 64 行，只是入口。
- 主体在 `lib/pages/app_shell.dart`（2185 行）。
- HTTP 封装在 `lib/services/backend_client.dart`（507 行）。
- 模型在 `lib/models/app_models.dart`，组件在 `lib/widgets/*`。
- known-issues 里 "P2：代码集中在 main.dart" 其实**已解决**，顺手把那条标成已修复。

---

## Fix 1：主对话双发（同步整段 + poll 分段，二者都渲染）

**现象**：发一条消息，助手回复出现两次——一次是按换行切好的多条气泡（同步路径），一次是不分段的整段（poll 路径）。

**根因（已定位，纯手机端可修）**：
1. 后端 `/desktop/chat` 流式路径返回 `msg_id = _stream_msg_id`（流式专用 id），同时也返回了 `turn_id`。
2. 后端把这同一轮 fanout 到 mobile 队列时，用的 id 是 **`turn_id`**（见后端 `core/turn_sink.py`：desktop/mobile 共享 canonical turn_id）。
3. 手机端 `BackendChatResponse.fromJson`（`lib/models/app_models.dart:856`）：
   ```dart
   final rawMsgId = json['msg_id'] ?? json['turn_id'];  // 优先 msg_id
   ```
   于是同步回复记进 `_synchronousAssistantReplyIds` 的是 `_stream_msg_id`，而 poll 消息的 `msg.id` 是 `turn_id` → **两个 id 对不上** → `_pollMobile` 里 `_synchronousAssistantReplyIds.contains(msg.id)`（`app_shell.dart:1143`）命不中 → poll 整段那条没被去重，重复渲染。
   （内容指纹兜底也救不了：同步那份记的是整段指纹，poll 那份也是整段，本应命中，但流式下两路文本处理/到达时序不一致时会漏，根治要靠 id 对账。）

**修法（保留"分段显示"为准，抑制 poll 整段回显——与 QQ 的分段输出对齐）**：

1. `lib/models/app_models.dart` `BackendChatResponse`（:846）**新增独立字段 `turnId`**，不要再把 msg_id/turn_id 揉进一个字段：
   ```dart
   final String? msgId;     // = json['msg_id']
   final String? turnId;    // = json['turn_id']  ← 新增
   ```
   `fromJson` 分别解析两者（各自 trim、空转 null）。
2. `lib/pages/app_shell.dart` `_shouldAppendSynchronousReply`（:1320）：把 **`response.turnId` 也注册进 `_synchronousAssistantReplyIds`**（连同现有的 `msgId`，两个都登记）。这样 poll 回来的 `msg.id == turn_id` 会被 :1143 的判断拦下。
   - 同样在 `_seenMobileMessageIds` / 指纹去重链路里，确保 turn_id 维度也参与对账。
3. 保持同步路径的 `_appendHimReplySegments`（:1258）作为唯一可见渲染（即用户看到的分段气泡）。**poll 路径只负责主动消息**（调度器推送、跨设备续传），不再回显 owner 自己刚发这轮。

**不做**：不改后端；不在手机端复刻后端分段规则（换行切分维持现状，"分段规则与 QQ 完全一致"是另议的优化，不在本工单）。

**验收**：
- 发一条消息 → 只出现**一组分段气泡**，没有多出来的整段重复。
- 调度器/主动消息（只走 poll，无同步响应）仍正常显示且不丢。
- 流式与非流式两种后端配置下都验一遍（`config.yaml` 的 LLM 流式开关）。
- `flutter analyze` 通过；`flutter test` 见 `CLAUDE.md`（需先 `$env:NO_PROXY=...`）。

---

## Fix 2：后端状态 / 资产诊断页（防"接错接口、调到莫名其妙的地方"）

**目标**：手机端能一眼确认"我连的是哪个后端、哪个数据目录、当前加载的是哪张角色卡/世界书/破限/梦境配置"，避免接错节点或落到测试沙盒还不自知。**纯只读**，不提供任何编辑（编辑属管理面板）。

**放哪**：不新增底部导航 tab（导航保持以聊天为中心）。加进**能力检查页**（`lib/widgets/capability_widgets.dart`）或系统设置页（`lib/widgets/settings_widgets.dart`）里，做一张"后端 / 资产状态"卡片。推荐能力检查页——它本就是"东西接对没"的体检面。

**数据源（后端均已存在，全部 GET；先各调一次看返回结构再写解析）**：

| 展示项 | 接口 | 字段 | 为什么要 |
|---|---|---|---|
| 后端节点 | 客户端已有 backendBase | URL | 确认连的是哪台 |
| **数据目录** | `GET /system/data-path` | `data_prefix` | **最关键**：一眼看出是生产 `data` 还是 `data/test_sandbox/...` |
| 元模式 | `GET /system/meta-mode` | `mode`(safe/danger) + `expires_at` | 当前是否在危险模式 |
| 模型 | `GET /status` | `config_summary.llm_model` / `llm_provider` / `short_term_rounds` | 接的哪个模型 |
| 当前角色卡 | `GET /characters/active-info` | `char_id` / `name` | 加载的是不是预期角色 |
| 世界书 | `GET /lorebook` | 条目数（与名称/启用项） | 世界书有没有加载对 |
| 破限 | `GET /jailbreak-entries` | 条目数 | 破限条目在不在 |
| 梦境配置 | `GET /dream/settings` | 当前梦境设置摘要 | 梦境配置对不对（字段以实际返回为准） |

**实现要点（守 AGENTS 规则：HTTP 只在 `lib/services/backend_client.dart`，不在 widget 里裸发）**：
1. `backend_client.dart` 新增对应只读方法（仿现有 `pollMobile`/`loadGarden` 的鉴权+解析写法）：`fetchSystemStatus()` / `fetchDataPath()` / `fetchMetaMode()` / `fetchActiveCharacter()` / `fetchLorebookSummary()` / `fetchJailbreakSummary()` / `fetchDreamSettings()`。能合并就合并，减少往返。
2. 模型字段加进 `lib/models/app_models.dart`。
3. UI：一张卡片，**数据目录 + 后端节点放最显眼**（非生产目录或非预期节点时用警示色标出，比如 `data_prefix` 含 `test_sandbox` 就高亮提醒）。其余项列表展示。加一个"刷新"按钮 + 拉取失败的错误提示（别静默）。
4. 任一接口失败只让该项显示"读取失败"，不要整页崩。

**验收**：
- 进诊断页能看到真实的后端节点、数据目录、模式、模型、当前角色卡、世界书/破限条目数、梦境配置。
- 故意把 `config.yaml` 的 `data_prefix` 指到测试沙盒并热重载 → 诊断页醒目提示当前在沙盒。
- 全只读，无任何写入入口。
- `flutter analyze` 通过。

---

## 执行顺序
1. **前提**：先按"真实布局"核对，顺手修正 AGENTS.md / known-issues.md（10 分钟，避免后续踩空）。
2. **Fix 1**（双发）——影响日常体验，优先。
3. **Fix 2**（诊断页）——独立可交付。

> 文档维护：Fix 1 改了消息对账逻辑 → 更新 `docs/mobile/flutter-structure.md`；Fix 2 加了接口 → 更新 `docs/backend/integration.md`。
