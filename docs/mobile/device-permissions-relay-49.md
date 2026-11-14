# 手机 #49：感知入口与常驻通知

## 已确认的根因与改动

`AmbientPermissions._load()` 之前在通道不可用时直接返回，读取失败后以空组件隐藏。现在设置 → 系统设置 → **设备感知与权限** 进入既有系统控制页；环境光、手机摆放、使用情况与电量保持可见。不可用、读取失败、硬件不支持和未知分别展示，读取失败可重试，返回前台重新读取。使用情况分享意愿与 OS grant 分开，未授权时提供系统设置入口；已开启但硬件不可用仍可撤销分享。普通能力检查只读，不放禁用开关。

电量复用 `readBatteryStatus`，只是当时的本机读数。运动/步数沿既有运动权限入口；屏幕上下文、无障碍、通知与后台接收沿既有控制页。按需屏幕观察增加8秒读取期限、失败重试、返回刷新及销毁时取消期限计时器；系统设置读取实际无障碍授权，不再默认假设已授权。没有新增后台采集或自动权限请求。

原生 `activateRelayConsumer()` 每次 SSE 建连都会更新常驻通知，即使文字没有变化。`ensureForeground()` 在重复 start 时又会把文字重置为“等待新消息”。现在服务内串行比较最后成功渲染文字，相同文字直接返回；重复 start 保留当前文字，销毁后拒绝迟到更新。复用既有60秒不可用阈值作为瞬断宽限，持续失效仍显示真实周期补偿状态。无新持久状态、队列或设置项。

## 通道责任与三面检查

- 前台 `MainActivity.onResume()` 停 native service 和补偿 alarm，由 Flutter WS final_only / HTTP 补读负责收件。
- 退后台仅在未启用 FCM、用户开启后台接收且凭据/origin 有效时启动 SSE 服务。FCM 沿现有选择；本单未发现可据以删除的重复消费者。
- SSE 是唤醒信号，仍经 HTTP poll → 原生 inbox 持久化 → 服务端 ACK；Flutter 接收后按原 id/seq/scope 确认。断线补偿、TTL、鉴权、pending 上限及关联键均不改。
- `NotificationChannels.MESSAGE_ID` 的真实角色消息提醒保持原重要性，常驻通知继续使用低重要性静音频道。没有删除重建用户频道；新增日志仅记录状态发生变化，不含正文、token、topic 或用户资料。
- 后端管理面继续拥有允许/有效状态。手机本地授权不代表后端允许或收到；桌面无需要同步的新配置。既有 `presence_mobile/settings` / screen_observation 方法及 legacy prefs 不改字段或含义。

## open / observe

**open：** 本单未提供逐项硬件支持、后端 effective、最近成功上报/错误的统一观测。当前运动权限不等于计步硬件支持；本机电量/环境读数也不代表上报成功。需要独立后端观测依赖与手机消费闭环，禁止推导假阳性。手机请求 running 查询仍按 #50 报告 open。

**observe：** 无连接 Android 设备，权限授权/撤销往返、SSE 每5秒断连10次、FCM/无FCM、前后台10次、Wi-Fi/蜂窝/VPN、ROM常驻通知呈现、录屏/logcat、杀进程和正式原位升级均 **NOT RUN**。自动化只覆盖合成时序，不代表已复现用户 ROM 的视觉弹跳。

## 本地验收（2026-11-14）

`flutter gen-l10n` 成功；`flutter analyze --no-pub` 零问题；`flutter test --no-pub --reporter compact` **416项通过**。新测试覆盖读取失败/重试、不支持平台、使用情况 grant 与 consent 独立、返回刷新、只读无开关、屏幕观察失败恢复；既有聊天/布局/历史/队列继续全量通过。全量运行曾检出关闭设置页的未取消计时器，修复后重跑通过。

Java 21 下执行 `android/gradlew.bat :app:testDevDebugUnitTest --tests com.presencekit.mobile.MobileNotificationDeliveryTest --tests com.presencekit.mobile.MobileDeliveryStateStoreTest --tests com.presencekit.mobile.MobilePullRecoveryTest --console=plain`：**19项通过**（通知2、收件存储14、回源恢复3）。覆盖同状态10次/重复start不重写、持续失效显示fallback、销毁后不复活通知，以及不同消息正常提醒/重复投递去重。

`flutter build apk --debug --flavor dev --no-pub` 成功，Gradle阶段20.0秒；产物 `build/app/outputs/flutter-apk/app-dev-debug.apk`，SHA-256 `1CDFDBF3BC2CDEF4DDF817A0932901BEEBDF5D51D7583D948A60575CD4CFD1F3`。未安装、未发布。回滚可撤销本单提交；无持久状态迁移，原有授权与偏好保留。
