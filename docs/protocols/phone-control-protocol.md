# 手机自动化协议（phone control / "computer use 手机版"）

> 状态：v1，2026-07-25 起草。后端四步（契约/敏感拦截/循环端点/工具注册）与 Android 三步
> （`YexuanAccessibilityService` 观察执行原语、`PhoneControlService` 循环协调、`FloatingBubbleService`
> `control` 模式确认浮窗）均已实现。视觉模型路由由用户自行在后端 `config.yaml` 的
> `vision`（或专用 `phone_control_vision`）段配置，本文档只定义协议契约，不涉及具体模型选型。

## 定位

给角色一个"帮用户在手机上完成一个多步操作任务"的能力（点外卖导航到支付页、操作没有开放
API 的玩具官方 App 等），复用现有 `desktop`/`system` 工具的门禁思路：后端只决定"要不要做、
每一步做什么"，真正的截屏/读屏幕/点击执行永远在设备本地完成。

**硬边界（不是产品建议，是代码要拦的）**：识别到密码、支付、验证码、银行等敏感页面时，
后端和设备两端都必须独立拒绝返回/执行任何点击动作，直接把控制权交还给用户，不允许视觉模型
自己判断"这个可以点"。到达这类页面即视为任务边界，不是任务失败。

## 整体流程

```text
对话中 LLM 判断要发起任务
  → 调用 phone_control_start 工具（dangerous=True，先过 chat 内"确认/取消"）
  → 危险模式门禁（复用 desktop/system 的 2 小时 danger window，见 GET/POST /system/meta-mode）
  → 生成 behavior_id=phone_control_task，挂在下一条消息上，走 mobile 通道下发
       （复用 MobileChannel.send_with_behavior，与 takeout_order 同一条路）
  → 手机收到 behavior → FloatingBubbleService 起手确认（"要帮你……，开始吗？"）
  → 用户确认后开始循环：
        本地截屏 + 无障碍节点树
          → POST /phone_control/step（上报观察）
          → 后端敏感页面拦截器先过一遍
          → 过了才调视觉模型，返回下一步动作
          → 设备本地也做一次敏感页面二次校验（防御性，不完全信任后端）
          → 执行动作 → 下一轮观察 → 循环
  → status=done / need_confirmation / refused 时循环结束，全程可在通知/悬浮窗一键取消
```

## 触发 behavior payload

挂在 `record_assistant_turn` 的 `payload["behavior"]` 上，走 `mobile` 通道（未来桌面端要接的话，
同一个 payload 也应该能被 desktop 通道消费，字段不做手机专属设计）：

```json
{
  "behavior_id": "phone_control_task",
  "task_id": "3f1c...-uuid",
  "task": "把购物车里选好的东西下单到支付确认页为止，别点最后一步"
}
```

Android 端 `MobileNotificationService.modeFor()` 已加入 `phone_control_task → "control"` 映射
（与 `lock_screen`/`takeout_order` 同级），`FloatingBubbleService` 的 `control` 模式浮窗展示任务描述，
用户点"开始"后调用 `PhoneControlService.start()` 转交循环协调服务。

## `POST /phone_control/step`

鉴权：与 `/mobile/*` 同一套 scoped token（`mobile` profile，见鉴权节）。

### 请求（设备 → 后端）

```json
{
  "task_id": "3f1c...-uuid",
  "step": 3,
  "package_name": "com.taobao.taobao",
  "screen_title": "购物车",
  "nodes": [
    {"id": "n1", "text": "去结算", "clickable": true, "bounds": [x1, y1, x2, y2]},
    {"id": "n2", "text": "", "content_desc": "增加数量", "clickable": true, "bounds": [x1, y1, x2, y2]}
  ],
  "screenshot_base64": "<jpeg, 可选但强烈建议带——node text 覆盖不到纯图标按钮>",
  "last_action": {"type": "tap", "target_node_id": "n0"},
  "last_action_result": "ok"
}
```

- `nodes`：无障碍节点树摘要，只给可点击/可读的节点，不做全量 dump。
- `screenshot_base64`：可选，但视觉定位坐标基本靠它——纯文本节点树覆盖不到图标类按钮。
- `step`：从 1 开始，后端按 `task_id` 维护步数上限（默认 20）和超时（默认 3 分钟），
  超限直接 `refused`，不依赖设备自己数。

### 响应（后端 → 设备）

```json
{
  "status": "continue",
  "action": {
    "type": "tap",
    "target_node_id": "n1",
    "target_point": null
  },
  "message": null
}
```

`status` 取值：

| status | 含义 | `action` |
|---|---|---|
| `continue` | 继续执行下一步 | 必有 |
| `done` | 视觉模型判断目标已达成 | 通常为 `null` |
| `need_confirmation` | 命中敏感页面拦截器，或视觉模型主动请求人工接手 | `null`，`message` 说明原因 |
| `refused` | 步数超限/超时/视觉模型调用失败 | `null` |

`action.type` 取值：`tap` / `type`（另需 `text` 字段）/ `scroll`（另需 `direction`）。
`target_node_id` 优先；模型给不出精确节点匹配时可退化为 `target_point: [x_ratio, y_ratio]`
（0~1 归一化坐标，设备按自己实际分辨率换算，不依赖后端知道设备分辨率）。

## 敏感页面硬拦截

后端侧：`core/phone_control/sensitive_filter.py`（关键词 + 包名，双重命中即拦截），命中时
**不调用视觉模型**，直接返回 `need_confirmation`。

设备侧：执行动作前必须用同一套关键词做本地二次校验（无障碍节点文本/包名），后端判断有误
或响应被篡改时仍有兜底。两边独立判断，任一方拦截即停止，不是"后端说了算"。

## 诊断与测试入口（能力检查页）

- `GET /phone_control/status`：只读，`BackendDiagnosticsCard` 新增两行——角色是否已在
  `tool_categories` 里授权 `phone_control`、视觉模型 `base_url`/`model` 是否都已配置。
  不暴露 `api_key` 本身，只给布尔判断。
- `POST /phone_control/debug/start`：`PhoneControlTestPanel`（能力检查页新增面板），填一句任务
  描述直接发起，跳过 LLM 判断和 chat 内二次确认；但仍然过 danger-mode 门禁，安全模式下会原样
  返回后端的拒绝文案，不是绕过安全闸的后门，只是绕过"要不要调用这个工具"的 LLM 决策环节。

## 未决事项

- 视觉模型 provider/route：用户自行接入（GLM 或其他 OpenAI-compatible 视觉模型），后端只留
  `core/phone_control/vision_client.py` 的调用点，参考 `core/perception/vlm_client.py` 已有的
  `vision` config 段读取方式。已配置：通用 `vision` 段用 GLM-4V，`phone_control_vision` 覆盖
  `model: glm-4.6v`（点击坐标定位更准），`api_key`/`base_url` 继承自 `vision` 段。
- 桌面端（Emerald-client）接入：本协议字段不做手机专属设计，desktop 通道理论上可以复用同一个
  `/phone_control/step` 端点，但客户端实现不在本仓库范围内。
