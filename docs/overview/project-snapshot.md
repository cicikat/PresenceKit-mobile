# 项目快照

`Emerald-mobile` 是一个 Flutter 移动端薄客户端，当前 Android 能力最完整。它不保存核心人格和记忆，不承担主动行为裁决，只连接 Emerald-presence（旧名 qq-st-bot）后端并消费 mobile channel。

## 已实现

- 主对话 UI：历史加载、发消息、回复分段展示（前端展示效果，不是服务端逐字流）；前台每 5 秒轮询主动消息并直接写入会话流。
- 后端节点设置：支持默认 `127.0.0.1:8080`、ADB reverse、局域网地址。
- 资料页：本机备注名、本机头像导入/裁切/保存。
- 日记页：读取 `/diary/list` 和 `/diary/{date}`。
- 花园页：读取 `/garden/state`，展示槽位、阶段、收获/花瓶计数。
- 能力检查页：通知、悬浮窗、无障碍、设备管理器、后台服务、后端连接、屏幕上下文、行为测试。
- Android 后台收消息：前台服务以 ntfy SSE 接收 signal，再回源 `/mobile/poll` 拉取正文；中继连续断开 15 分钟后由 AlarmManager 补偿，按静音和冷却发通知。
- Android 行为层：悬浮短句、锁屏确认、外卖/购物确认浮窗。
- 屏幕上下文：无障碍读取并在本机过滤当前 App、窗口标题、可见文字和可点击文字摘要；独立上传开关默认关闭，开启后才会上报非敏感快照到 `/sensor/realtime`。
- 活动与群聊：阅读、五子棋、国际象棋活动页，以及独立群聊列表/会话；群聊手机端用 HTTP 轮询等待回复，不使用逐字流式。
- 设置与诊断：提示词资产、Dream 设置、后端/资产诊断与能力检查均已拆到领域组件，由主壳保留状态与安全确认。

## 当前结构特点

- Flutter 入口 `lib/main.dart` 仅保留启动和 `MyApp`；数据模型、HTTP、本机设置、主壳状态和领域 UI 已分别位于 `models/`、`services/`、`pages/`、`widgets/`，当前仍通过 Dart `part` 保持同一 library。
- Android 原生层按能力拆成多个 Kotlin 类，边界相对清楚。
- `pubspec.yaml` 依赖很轻，目前主要使用 Flutter SDK、Material、Cupertino Icons。
- 多平台模板目录仍存在，但实际能力集中在 Android；iOS/macOS/windows/linux/web 基本是 Flutter 模板。

## 外部依赖

- Emerald-presence（旧名 qq-st-bot）后端必须运行并暴露 8080。
- 插线调试依赖 ADB reverse。
- 脱线调试要求手机能访问电脑局域网 IP 或 VPN/内网穿透地址。
- Android 悬浮窗、无障碍、设备管理器和通知权限都需要用户单独授权。

## 文档迁移说明

原 `docs/sensor_event_protocol.md` 已归入 `docs/protocols/sensor-event-protocol.md`。README 中的旧链接已更新为新路径。
