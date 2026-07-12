# docs/README.md - 文档索引

本目录按主题归档 `Emerald-mobile` 的项目文档。根目录 `AGENTS.md` 是协作者入口，`ARCHITECTURE.md` 是架构总览。

| 文档 | 内容 |
|---|---|
| `overview/project-snapshot.md` | 当前项目状态、目录和功能边界 |
| `roadmap-notes.md` | 待梳理的路线与后续议题 |
| `mobile/flutter-structure.md` | Flutter 单页应用、状态、UI 组件和拆分建议 |
| `mobile/background-notification-design.md` | 后台通知与前台服务的设计说明 |
| `android/native-capabilities.md` | Android 原生权限、MethodChannel、服务和安全边界 |
| `backend/integration.md` | 后端接口、鉴权、轮询、数据流 |
| `protocols/mobile-channel.md` | mobile channel 主动消息和 behavior metadata |
| `protocols/relay-publish-contract.md` | 推送中继发布契约与信号语义 |
| `protocols/sensor-event-protocol.md` | 多端与硬件传感器事件协议草案 |
| `quality/testing-and-dev.md` | 本地调试、构建、测试和安装方式 |
| `known-issues.md` | 已知 bug、风险和技术债 |

参考与归档（非现役规范）：

- `reference/main-dart-split-plan.md`：已完成的 `lib/main.dart` 拆分计划。
- `reference/push-relay-spike.md`：已封存的推送中继 Spike 结论；现行发布约定见 `protocols/relay-publish-contract.md`。
- `reference/desktop-jsx/`：桌面端 React/JSX 视觉设计参考及其素材；仅供视觉比对，禁止将其中的组件结构、状态管理或实现逻辑复制到 Flutter/Android 源码。

相关外部项目：

- 后端核心：`Emerald-presence` 仓库（通常与本仓库同级；旧名 qq-st-bot）
- 桌面客户端参考：`Emerald-client` 仓库（通常与本仓库同级）

维护约定：

- 改接口、字段、鉴权或轮询路径时，同步更新 `backend/integration.md` 和 `protocols/mobile-channel.md`。
- 改 Android 权限、服务、悬浮窗、无障碍或锁屏逻辑时，同步更新 `android/native-capabilities.md`。
- 改 Flutter 页面结构或准备拆分 `lib/main.dart` 时，同步更新 `mobile/flutter-structure.md`。
- 发现未修问题，先记到 `known-issues.md`。
