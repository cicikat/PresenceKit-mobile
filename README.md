# Emerald-mobile

叶瑄手机薄客户端。核心人格、记忆和调度仍在 `D:\ai\qq-st-bot`，手机端只负责 UI、输入、花园/历史读取和 mobile channel 主动消息轮询。

手机发送消息走 `POST /mobile/chat`，不会占用桌宠的 `/ws/desktop`；主动消息由 `GET /mobile/poll` 每 5 秒轮询接收。

## Android 后台通知

后台/息屏收消息先走 Android 端前台服务，不写进后端核心：

- Flutter 前台：页面内 5 秒轮询 `GET /mobile/poll`，收到后直接进会话流。
- Flutter 退后台：停止页面轮询，启动 `MobileNotificationService`。
- Android 服务：激活 `/mobile/activate` 后长轮询 `/mobile/poll?wait=55`，收到内容后先过本机通知闸门，再决定是否发系统通知。
- Flutter 回前台：停止 Android 服务，恢复页面轮询。

这样后端仍然只维护平台无关的 `mobile channel`。未来 iOS 不应照搬后台常驻轮询，而是让后端或一个中继层接 APNs，把同一类主动消息投递到 iOS 推送。

### 当前通知闸门

手机端先按“宁可少打扰”的策略处理后台主动消息：

- 通知等级：当前所有 `mobile channel` 主动消息最高只发普通系统通知，不自动升级悬浮窗、全屏提醒或锁屏动作。
- 静音时段：23:30-06:30 不弹新消息通知；服务仍长轮询，前台常驻通知只显示静默收取计数。
- 冷却机制：普通通知发出后 30 分钟内不再重复弹新通知；被冷却的消息计入静默收取计数。
- 摘要提示：冷却/静音后下一条允许弹出的通知，会在展开文本里提示此前静默收取了几条。
- 前台行为：Flutter 页面在前台时仍只在会话内显示，不额外发系统通知。
- 安全边界：锁屏、悬浮窗、全屏提醒以后必须走单独授权和确认，不由普通主动消息自动触发。

### 行为 metadata 消费层

手机端不定义后端的主动行为规则，只消费 mobile channel 下发的可执行 metadata。

当前兼容两类字段形状：

- 过渡版：`kind` / `delivery`，例如 `overlay_message`、`lock_screen_confirm`、`takeout_overlay`。
- 阶段 6/7 版：`level` / `behavior_id`，例如 `attention_grab`、`direct_act` 和具体语义标签。

手机端执行边界：

- `attention_grab` / `direct_act` 可以映射为悬浮提醒或确认浮窗。
- 带 `lock` 语义的行为只显示锁屏确认浮窗，不直接锁屏。
- 带外卖/订单语义的行为只显示外卖确认浮窗，不自动加购、下单或支付。
- 不带高强度 metadata 的主动消息仍走普通通知闸门：静音时段、30 分钟冷却、静默摘要。

## 后端连接

开发插线调试时可以继续用默认值：

```powershell
D:\soft3\AndroidSDK\platform-tools\adb.exe reverse tcp:8080 tcp:8080
```

此时手机访问 `http://127.0.0.1:8080` 会被 ADB 转发到电脑后端。

脱离数据线后，把 App 设置里的“后端节点”改成电脑局域网地址，例如：

```text
http://192.168.10.154:8080
```

要求：
- 手机和电脑在同一个局域网，或通过 Tailscale / VPN / 内网穿透互通。
- 后端管理服务监听 `0.0.0.0:8080` 或对应局域网地址。
- Windows 防火墙允许手机访问 8080。
- 公网节点必须使用 HTTPS；明文 HTTP 仅允许 loopback、Tailscale 或用户确认过的 RFC1918 私网精确 IPv4 origin。
- 前后台请求均拒绝自动重定向，避免跳转绕过 origin 校验。

访问凭证首次启动时由用户填写，保存在 legacy `SharedPreferences("yexuan_memery", MODE_PRIVATE)`。当前尚未接入 Android Keystore，只适合自用内测。

也可以在打包时预置后端地址。若预置 RFC1918 私网 HTTP origin，首次使用时仍需在 App 内确认该精确 origin：

```powershell
D:\soft3\flutter\bin\flutter.bat build apk --release --dart-define=BACKEND_BASE_URL=http://192.168.10.154:8080
```

当前 Android release 仍使用 debug signing，仅适合自用内测安装，不用于正式分发或上架。

## 待捋逻辑

这些不是当前代码必须马上完成的功能，而是后续适合集中问清楚、再写成稳定方案的部分。

### 角色资料

- 手机端改名先按“本机备注名”处理：默认显示后端里的角色名，用户可以在手机端覆盖显示名，但不直接写回后端的核心 config。
- 当前已实现手机端本机备注名：存放在 Android 本地 `SharedPreferences`，影响顶部栏、抽屉和偏好页显示。
- 后续需要决定是否允许“同步备注名到后端”。如果要做，建议做成单独确认按钮，避免手机端误改核心人格配置。
- 当前已实现头像导入：Android 系统相册选择图片，Flutter 内拖拽/缩放裁切，保存到 App 私有目录 `profile_avatar.png`。
- 当前头像只作为手机端本地头像，影响顶部栏、抽屉和偏好页显示；不上传到后端。
- 需要确认头像的作用域：只影响手机端 UI，还是作为全端角色头像源。

### 通知与主动消息

- 现在后台收消息的通道已经打通，手机端先实现了本机通知闸门：23:30-06:30 静音、普通通知 30 分钟冷却、静默计数摘要。
- 当前 `mobile_queue` 只有 `content/user_id/timestamp`，没有优先级或 trigger 元数据，所以手机端不根据内容自动判断紧急程度。
- 后续如果后端增加 `priority` / `trigger` / `ttl`，再把通知强度分级扩成：静默记录、普通通知、悬浮窗建议、全屏提醒建议、锁屏建议。
- 任何悬浮窗、全屏、锁屏都必须保留单独授权和用户确认，普通主动消息不能自动升级。
- iOS 未来不能照搬 Android 前台服务，应该走 APNs 或中继推送。后端侧保持平台无关的 mobile channel。

### 悬浮窗与屏幕上下文

- 当前悬浮窗已经能显示在桌面和其他 App 上层，用于短句提醒、订单确认、回到聊天。
- 当前手机端已经接入“屏幕陪伴层”的文本上下文：无障碍服务会读取当前 App 包名、App 名、窗口标题、可见文字和可点击文字摘要。
- 屏幕上下文上传使用独立开关，默认关闭。开启后，前台 App 每 45 秒推送一次经过本机过滤的非敏感快照；退后台后 `MobileNotificationService` 每轮长轮询前也会推送一次。
- 能力检查页里有“屏幕上下文调试”，可以手动读取当前快照、查看经过本机过滤的可见/可点文字，并在上传开关开启且快照非敏感时推送到后端。
- 能力检查页里有“主动行为测试”，可以写入普通通知、悬浮短句、锁屏确认、外卖确认四类 mobile queue 测试消息。
- 后端 `sensor_aware` 会把这些上下文纳入客观评分，并把行为 metadata 通过 mobile channel 一起下发给手机端。
- 截图/OCR/视觉识别暂不自动上传；如果后续要接 vision API，必须做成明确的手动确认或独立开关，避免把敏感屏幕内容外发。
- 更稳的交互方向仍然是：叶瑄看到当前页面后给建议，而不是强行代替用户点击。
- 需要决定哪些内容可以进入后端记忆，哪些只作为一次性屏幕上下文使用，避免把敏感页面长期写入记忆。

### 外卖/购物辅助

- 当前安全边界：可以打开美团/淘宝、切到购物车、显示确认悬浮窗；不自动支付。
- “填购物车但不支付”可以先放后。更稳的交互是：叶瑄催吃饭 -> 打开外卖页 -> 根据当前屏幕推荐 -> 用户自己点。
- 如果未来要自动加购，需要先定安全策略：只加收藏/白名单店铺，遇到规格弹窗或价格变化就停下确认。
- 永远不自动点击支付、提交订单、确认收货、解绑银行卡等高风险动作。

### 权限与设备控制

- Android 已涉及通知、悬浮窗、无障碍、设备管理器锁屏、后台服务。
- 需要做一个“能力检查页”：显示每项权限是否开启，点击跳系统设置。
- 强制息屏只在用户明确授权设备管理器后执行，并且每次动作最好仍保留角色确认。
- 应用控制类能力要区分“打开页面”“建议操作”“辅助点击”“高风险动作”，逐级授权。

### 多端与硬件

- 未来硬件可以视为新的客户端/输入端：传感器 -> 后端 -> mobile channel/desktop channel -> 角色反应。
- 已补充协议草案：[多端与硬件传感器事件协议](docs/protocols/sensor-event-protocol.md)。
- 需要设计事件格式，例如压力、气压、触摸、距离、环境光等都归一成 sensor event。
- 需要决定哪些硬件事件进入长期记忆，哪些只触发短期反应。
- 多端同时输入时，后端需要继续保持队列/锁/失败兜底，避免记忆写入阻塞或丢失。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

* [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
* [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
