# 60 手机环境上传排查与恢复

- [x] 真机定位：已安装 build 83；前台光照与重力监听活跃，使用情况访问已允许；服务器当前角色的环境读回均 unavailable。
- [x] 为静默失败补充不含凭据、地址或观测值的阶段日志，复现实际失败：build 85 日志显示采样为空；`AmbientSensors.sample()` 的 buildMap receiver 将 keys 解析为空结果字典的键集合。新增 `AmbientSensorsTest` 修复前在第 26 行业务断言失败：预期三项事实，实际空集合。最终版本仅保留失败阶段、异常类型和 HTTP 状态码日志。
- [x] 修复根因并通过相关回归：`AmbientSensors.sample()` 显式引用传感器类型列表。`AmbientSensorsTest` 1 项通过；Flutter `device_controller_sensor_permission_test.dart` 与 `ambient_permissions_test.dart` 共 13 项通过；最终 `flutter analyze --no-pub lib/controllers/device_controller.dart` 零问题；prod release build 通过。build 86 与原安装包签名 SHA-256 相同，使用 `adb install -r` 保留数据覆盖安装。
- [x] 真机检查服务器接收与角色读取链：build 86 安装后，当前角色 `GET /sensor/ambient?device=phone` 的 light/motion/usage 三项均为 available，均带实际来源与新鲜接收时间。读取与 `get_ambient_state` 使用同一 snapshot；未额外发送 LLM 聊天验收消息。仅前台采集、30 秒上传与后端 120 秒 TTL 保持原合同；无协议变化，后端与桌面无需修改。独立提交见本工单所在 Git commit。

验证：Flutter 定向测试与分析、正式签名一致性、真机日志及服务器只读查询；不向生产注入合成观测，不发送聊天测试消息。

交付：1.3.0+86，`build/app/outputs/flutter-apk/app-prod-release.apk`，APK SHA-256 `cf5545b96d8d85587bf78c68295a3cf328eb368b9daec46d7c5f6621762b275e`。已覆盖安装到连接设备；未发布 GitHub Release。未扩展到折叠屏开合、后台环境采集或完整应用列表。
