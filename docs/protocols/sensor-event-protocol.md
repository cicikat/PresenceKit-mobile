# 多端与硬件传感器入口协议

> 当前事实核对：2026-07-29。本文只记录已经存在的 endpoint、真实调用方、鉴权和 payload
> 边界；不定义统一 sensor event bus，也不把规划中的 envelope 当作当前协议。

## 共同边界

设备和客户端只上报客观事实，不直接扮演角色、不直接决定行为。后端负责校验、冷却、行为
映射和记忆分层。所有下列写入口都使用管理面 Bearer token，并要求 `sensor.write` scope；
读取侧使用对应的 `state.read` scope。

手机端不直接读写后端数据文件。后端物理路径以 backend 的 `docs/data-taxonomy.md` 与
`core/data_paths.py` 为准，客户端不得依赖。

## 当前 endpoint

### POST /sensor/push

| 项目 | 当前事实 |
|---|---|
| 真实调用方 | mobile `lib/controllers/device_controller.dart::pushSensorData()` → `BackendClient.pushSensorData()`；启动时一次，之后每 30 分钟一次 |
| 鉴权 | Bearer token，`sensor.write` |
| 用途 | 低频聚合手机事实；后端更新最近快照，并按写入边界聚合到用户 profile |
| payload | JSON object；`steps` 非负整数、`battery` 0–100 整数、`screen_sessions` 可选整数、`location` 可选字符串；字段可省略 |
| 响应/错误 | 成功返回接收消息和归一化 data；字段非法返回 422；客户端不依赖后端物理存储 |

### POST /sensor/realtime

| 项目 | 当前事实 |
|---|---|
| 真实调用方 | desktop Rust sensor publisher；mobile `DeviceController.pushScreenContext()`；Android 后台 `MobileNotificationService` 在补偿 poll 前的过滤快照上报 |
| 鉴权 | Bearer token，`sensor.write` |
| 用途 | 短窗口实时状态，供 presence/sensor_aware 与屏幕陪伴读取；后端只保留内存中的最新快照，重启清空 |
| payload | `window_seconds` 1–300；`ts`；`sensor_version`；`input`（非负 `keystrokes`、`mouse_clicks`、`mouse_distance_px`、`idle_seconds`）；`focus`（`app`、`title_hint`、非负 `switch_count`）；可选 `screen`（package/app/title/visible/clickable 文本数组） |
| 隐私边界 | 敏感窗口由 producer 和 backend 双重拦截；后端对 `title_hint`、窗口标题和文本数组做边界截断；实时正文不直接进入长期记忆 |
| 响应/错误 | 无敏感窗口时返回 `{ok:false, skipped:"sensitive_window"}`；正常返回 `{ok:true, received_at}`；schema 错误返回 422 |

对应读取 endpoint 是 `GET /sensor/realtime`，需要 `state.read`，无样本时返回
`{ "_no_data": true }`。客户端把它当作正常空状态，不将其解释为全零快照。

### POST /perception/visual

| 项目 | 当前事实 |
|---|---|
| 真实调用方 | desktop Rust `src-tauri/src/sensor/visual.rs`；mobile 当前没有调用方 |
| 鉴权 | Bearer token，`sensor.write` |
| 用途 | 本地视觉观察 shadow ingress；后端按 source 冷却，后台处理观察结果，不把图片落盘 |
| payload | `multipart/form-data`：`image` 文件和 `source`（当前允许 `screen` 或 `camera`）；图片内容只作为本次处理输入 |
| 预检 | desktop 先读 `GET /perception/visual/config`；该读取也要求 `sensor.write`，只返回 producer-safe 开关和 cooldown |
| 响应/错误 | 接收后返回 202；关闭、冷却或处理失败均降级为 shadow trace/空结果，不改变普通聊天路径 |

诊断读取 endpoint 是 `GET /perception/visual-trace`，需要 `state.read`，只返回 shadow
trace，不返回图片正文或外部模型凭证。

### POST /watch/event

| 项目 | 当前事实 |
|---|---|
| 真实调用方 | 外部 Watch/HealthKit/快捷指令等健康事件 producer；当前 mobile 仓库没有直接调用方 |
| 鉴权 | Bearer token，`sensor.write` |
| 用途 | 接收可穿戴设备健康事件，交给后端 scheduler；不是 mobile 前台聊天入口 |
| payload | `{"type":"heart_rate","value":整数}`，或 `{"type":"sleep_end","sleep_start":"HH:MM","sleep_end":"HH:MM"}`；当前不支持的 type 返回 422 |
| 响应/错误 | `heart_rate` 返回接收消息；`sleep_end` 先缓冲合并再处理；字段缺失/类型非法返回 422 |

对应读取 endpoint 是 `GET /watch/status`，需要 `state.read`，仅返回最近事件快照。

## Historical / Removed

### POST /sensor/activity

当前 backend `admin/routers/sensor.py`、`perception.py`、`watch.py` 中没有该 route，desktop/mobile
当前调用方也未找到它。因此它不属于 current endpoint，也不应被新客户端实现或继续作为协议入口
引用。旧的跨仓审计/交接材料中若仍出现该名称，只能视为历史记录。

### POST /sensor/event

本文不提出或设计该统一入口。若未来需要协议升级，必须另立版本化工单，不能由本文件把规划
字段或 event bus 变成当前契约。

## 记忆与隐私分层

- `/sensor/realtime` 是短窗口事实；敏感正文、图片和原始健康数据不得直接进入长期记忆。
- `/sensor/push` 与 `/watch/event` 的 profile 聚合由后端 write envelope 和 profile writer 决定；
  mobile 只提交 endpoint payload。
- `/perception/visual` 是 shadow 观察；trace 仅供诊断，不等同于 prompt 或 memory source。
- 设备端不根据单个 sensor 事件自行决定角色行为；所有主动消息和行为由 backend scheduler/
  tool/permission gates 裁决。
