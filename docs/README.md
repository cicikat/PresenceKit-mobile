# docs/README.md - 文档索引

本目录按主题归档 `Emerald-mobile` 的项目文档。根目录 `AGENTS.md` 是协作者入口，`ARCHITECTURE.md` 是架构总览。

| 文档 | 内容 |
|---|---|
| `overview/project-snapshot.md` | 当前项目状态、目录和功能边界 |
| `mobile/flutter-structure.md` | Flutter 单页应用、状态、UI 组件和拆分建议 |
| `android/native-capabilities.md` | Android 原生权限、MethodChannel、服务和安全边界 |
| `backend/integration.md` | 后端接口、鉴权、轮询、数据流 |
| `protocols/mobile-channel.md` | mobile channel 主动消息和 behavior metadata |
| `protocols/sensor-event-protocol.md` | 多端与硬件传感器事件协议草案 |
| `quality/testing-and-dev.md` | 本地调试、构建、测试和安装方式 |
| `known-issues.md` | 已知 bug、风险和技术债 |

相关外部项目：

- 后端核心：`Emerald-presence` 仓库（通常与本仓库同级；旧名 qq-st-bot）
- 桌面客户端参考：`Emerald-client` 仓库（通常与本仓库同级）

维护约定：

- 改接口、字段、鉴权或轮询路径时，同步更新 `backend/integration.md` 和 `protocols/mobile-channel.md`。
- 改 Android 权限、服务、悬浮窗、无障碍或锁屏逻辑时，同步更新 `android/native-capabilities.md`。
- 改 Flutter 页面结构或准备拆分 `lib/main.dart` 时，同步更新 `mobile/flutter-structure.md`。
- 发现未修问题，先记到 `known-issues.md`。
