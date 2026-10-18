# 工单 40：无线连接与 APK 传输入口

范围：新增 AA4 BAT 与 PowerShell 辅助脚本，使用 Android 11+ 原生无线调试配对/连接，并向指定无线设备安装已有 APK。复用现有 SDK 定位约定，不构建或发布新包，不修改应用、后端或桌面端。

- [x] 检查现有 AA1/AA2/AA3、SDK 定位和 Android 官方无线调试说明。证据：scripts/build_dev.ps1、scripts/build_release.ps1；官方 https://developer.android.com/tools/adb 。
- [x] 实现首次配对、已配对直连、仅连接与已有 APK 安装，明确两种端口；所有设备动作绑定指定无线 serial，失败不卸载、不降级。证据：scripts/wireless_phone.ps1:115 起的配对/连接/安装流程；AA4无线连接并传给手机.bat:7。
- [x] 更新开发文档，说明手机设置、同 Wi-Fi、配对码、现有打包入口和后端隧道边界。证据：docs/quality/testing-and-dev.md 的“无线传输 / 安装 APK（AA4）”节。
- [x] 验收 Windows PowerShell 语法、BAT 入口与模拟 ADB 成功/失败路径，检查 UTF-8/CRLF 与 scoped diff。证据：Windows PowerShell 5.1 运行 10 项隔离假 ADB 场景全部 PASS（仅连接、指定设备/空格路径安装、connect 退出 0 但 offline、安装签名失败、显式 reverse、配对码经 stdin、配对失败即停止、无效地址、APK 缺失、按文件修改时间选择）；真实 BAT 对无效地址退出 1；四文件 UTF-8/CRLF 检查通过；git diff --check 通过；文档普通/ignore-cr-at-eol diff 均为 28 行新增。脚本工具改动，无需 Flutter 构建或测试。
- [ ] 真机首次配对、无线安装和 Wi-Fi 断线重连：not-run（需要手机开启无线调试并提供现场地址/配对码）。

三面检查：仅开发机 ADB 工具，无跨端影响；后端管理面、桌面/手机设置、mobile channel、通知和权限契约均无变更。ADB 配对信任由 Android/ADB 管理，本工具不落盘配对码、地址或新业务状态。仅连接后可继续用 AA2/AA3；原脚本要求恰好一个设备，USB 与无线同时连接会被原脚本拒绝。后端 8080 隧道仅按用户菜单选择建立，断开后需要重跑。