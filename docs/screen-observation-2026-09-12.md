# 角色按需截图：Mobile 差异入口

跨仓协议、后端请求链、隐私边界和共同测试结论统一维护在后端报告：
[`Emerald-presence/docs/screen-observation-2026-09-12.md`](../../Emerald-presence/docs/screen-observation-2026-09-12.md)。

本仓只记录 Mobile 专属内容：

- Android Accessibility 截图、权限和 worker 生命周期：查 [`android/native-capabilities.md`](android/native-capabilities.md)。
- 手机本地授权设置与通道：查 [`mobile/flutter-structure.md`](mobile/flutter-structure.md) 及
  [`protocols/mobile-channel.md`](protocols/mobile-channel.md)。
- Android 真机、OEM、Doze 与无障碍验收：查 [`android/device-lifecycle-matrix.md`](android/device-lifecycle-matrix.md)
  和 [`known-issues.md`](known-issues.md)。

不要在本文件复制后端或桌面端的 payload、TTL、观测字段和测试数字。
