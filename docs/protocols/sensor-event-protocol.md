# 多端与硬件传感器事件协议

目标：所有设备都只负责上报“客观事实”，不直接扮演叶瑄、不直接决定行为。后端统一做评分、冷却、行为映射和记忆分层。

## 入口

现有入口：

- `POST /sensor/realtime`：短窗口实时状态，给主动触发和屏幕陪伴用。当前 Android 已接入无障碍文本上下文。
- `POST /sensor/push`：低频聚合数据，写入用户画像摘要。适合步数、电量、位置这类一天内缓慢变化的数据。
- `POST /sensor/activity`：桌面端活动快照，偏桌宠/桌面状态。

建议新增或统一的逻辑入口名：

```text
POST /sensor/event
```

暂时不一定马上实现新接口；可以先让各端按下面的 envelope 组织数据，再由现有接口兼容接收。

## Event Envelope

```json
{
  "event_id": "uuid-or-device-ts",
  "schema_version": "sensor_event.v1",
  "source": {
    "device_id": "android_phone_main",
    "device_type": "android_phone",
    "client": "Emerald-mobile",
    "platform": "android",
    "trust": "user_device"
  },
  "observed_at": 1779026400.0,
  "received_at": 1779026401.2,
  "window_seconds": 45,
  "type": "screen_context",
  "category": "screen",
  "priority_hint": "normal",
  "privacy": {
    "tier": "ephemeral",
    "contains_sensitive_text": false,
    "allow_memory": false,
    "allow_external_vision": false,
    "retention_seconds": 180
  },
  "facts": {
    "app_package": "com.sankuai.meituan",
    "app_label": "美团",
    "window_title": "外卖",
    "visible_text": ["附近商家", "购物车", "去结算"],
    "clickable_text": ["购物车", "去结算"]
  },
  "metrics": {
    "confidence": 0.76,
    "sample_count": 1
  },
  "dedupe_key": "android_phone_main:screen_context:com.sankuai.meituan"
}
```

## 事件类型

当前可落地：

- `screen_context`：当前 App、窗口标题、可见文字、可点击文字。只作为实时上下文，默认不进长期记忆。
- `foreground_app_changed`：App/类别变化，例如从工作切到外卖。
- `late_night_active`：深夜仍活跃。
- `long_focus`：长时间停留在同一 App/类别。
- `focus_scattered`：短时间频繁切换。
- `presence_left` / `presence_returned`：离开/回来。
- `long_stillness`：久坐或长时间无明显活动。

后续硬件可接：

- `touch_presence`：硬件被触摸、握住、靠近。
- `ambient_light_changed`：环境光明显变化。
- `ambient_noise_changed`：环境噪声变化，只存分贝级别，不存录音。
- `room_motion`：人体/毫米波/红外检测到靠近或离开。
- `desk_pressure`：坐下、起身、趴桌等压力变化。
- `heart_rate_summary`：心率摘要或异常趋势，来自 Apple Watch/HealthKit 时只存粗粒度。
- `sleep_state_summary`：睡眠/起床摘要，只存阶段和时间段，不存原始健康明细。

## 记忆策略

三层处理：

```text
raw event -> realtime candidate -> memory candidate -> profile summary
```

### ephemeral

只用于当下评分和行为触发，不进记忆。

适合：

- 屏幕可见文字
- 当前 App
- 当前页面标题
- 可点击按钮文字
- 支付、银行、验证码、聊天隐私页面

处理：

- 后端内存保留 1-3 分钟。
- 可进入 `sensor_judge` 做客观评分。
- 不写入长期记忆和日记。
- 默认不送外部视觉模型。

### session

当天或短期会话级摘要，可帮助叶瑄理解状态，但不长期固化。

适合：

- “今天多次深夜活跃”
- “下午连续工作两小时”
- “中午多次停留外卖页面”
- “今天手机电量长期偏低”

处理：

- 写入当日 sensor summary。
- 可进入 prompt 的“今日手机感知”。
- 过日清理或只保留低维统计。

### profile

长期偏好/习惯，必须从多次 session summary 提炼，不能由单次屏幕事件直接写入。

适合：

- “工作时容易连续专注很久”
- “深夜容易拖延睡觉”
- “午饭经常需要提醒”
- “更接受轻提醒，不接受强打扰”

处理：

- 至少 3 次以上同类事件，且跨天出现，再进入候选。
- 需要 LLM 归纳，但输出必须是习惯摘要，不包含原始屏幕内容。
- 敏感源永不提升为 profile。

## 行为映射

行为层必须根据 `score + risk + privacy.tier + category` 一起决定：

- `score < 35`：静默丢弃。
- `35 <= score < 55`：普通通知或仅入当日摘要。
- `55 <= score < 75`：悬浮短句，前提是非敏感页面且悬浮窗权限开启。
- `late_night_active && score >= 50`：可弹锁屏确认，但不能自动锁屏。
- `takeout/shopping && score >= 52`：可弹外卖/购物确认浮窗，但不能自动加购、下单、支付。
- `risk >= 75` 或 `privacy.contains_sensitive_text=true`：只静默记录或完全丢弃。

## Apple Watch 路线

Android 手机不能直接读取 Apple Watch 的健康数据。

可行路线：

1. iPhone 快捷指令手动触发：读取健康样本，POST 到后端。最省事，但自动化弱。
2. 自写 iOS App + HealthKit：用户授权后读取 iPhone/Apple Watch 同步到 HealthKit 的数据，再推送到后端。
3. watchOS App：可以更贴近手表传感器，但开发和权限成本最高。

建议先用快捷指令上报低风险摘要：

```json
{
  "type": "health_summary",
  "category": "body",
  "privacy": {
    "tier": "session",
    "allow_memory": false,
    "allow_external_vision": false
  },
  "facts": {
    "steps_today": 4200,
    "stand_hours": 5,
    "latest_heart_rate_bucket": "normal",
    "workout_recent": false,
    "sleep_last_night_hours": 6.5
  }
}
```

不要上传：

- 原始心率序列
- ECG 原始数据
- 精确经纬度轨迹
- 健康诊断/用药明细
- 任意可识别的医疗记录

## 可买硬件方向

低风险、好接入：

- ESP32 + BLE/Wi-Fi：按钮、触摸、电容、光照、温湿度。
- 小米/米家类传感器：如果能走 Home Assistant，再由 HA webhook 推后端。
- Aqara/Thread/Matter：适合门磁、人体、温湿度，但生态网关成本更高。
- 桌面压力垫/FSR：判断坐下/起身/趴桌。
- 毫米波存在传感器：判断人在不在桌前，比摄像头隐私友好。

暂缓：

- 摄像头常开识别。
- 麦克风常开录音。
- 自动上传截图识别。
- 与支付/下单强绑定的自动点击硬件。

## Emerald-mobile 当前实现（2026-07-13）

- Android 无障碍层按需采集 `packageName`、`appLabel`、`className`、`windowTitle`、`visibleText`、`clickableText`，先过滤密码、验证码、支付/银行/医疗页面和敏感应用。
- `DeviceController` 前台每 45 秒推送一次允许的屏幕上下文；独立上传开关默认关闭，正文只有在 `screenTextUploadAllowedPackages` 白名单内才上传。
- `DeviceController` 每 30 分钟读取电量/步数并通过 `POST /sensor/realtime` 上报；权限未授予时不伪造步数。
- 屏幕上下文属于 `ephemeral` 实时客观事实，手机端不把正文直接写入长期记忆；能力页调试采集与自动上传是两条独立路径。
- Android 后台 `MobileNotificationService` 只在补偿 poll 前尝试上传过滤后的快照，上传失败不阻塞主动消息消费。