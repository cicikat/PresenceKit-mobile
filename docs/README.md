# docs/README.md - 文档索引

本目录按主题归档 `Emerald-mobile` 的项目文档。根目录 `AGENTS.md` 是协作者入口，`ARCHITECTURE.md` 是架构总览。

| 文档 | 内容 |
|---|---|
| `overview/project-snapshot.md` | 当前项目状态、目录和功能边界 |
| `roadmap-notes.md` | 仍含未归档的路线与后续议题；不作为 current implementation authority |
| `mobile/flutter-structure.md` | Flutter 单页应用、状态、UI 组件和拆分建议 |
| `mobile/localization.md` | Flutter 中英文、本地化键和语言偏好持久化契约 |
| `mobile/color-mods.md` | 多颜色预设、浏览器导出和 `mods/` 打包契约 |
| `mobile/background-notification-design.md` | 后台通知与前台服务的设计说明 |
| `android/native-capabilities.md` | Android 原生权限、MethodChannel、服务和安全边界 |
| `backend/integration.md` | 后端接口、鉴权、轮询、数据流 |
| `../../Emerald-presence/docs/three-repo-interface-catalog.md` | 三仓接口、跨端设置/观测和调用链总账（通常与本仓同级） |
| `protocols/mobile-channel.md` | mobile channel 主动消息和 behavior metadata |
| `protocols/relay-publish-contract.md` | 推送中继发布契约与信号语义 |
| `protocols/sensor-event-protocol.md` | 多端与硬件传感器事件协议草案 |
| `quality/testing-and-dev.md` | 本地调试、构建、测试和安装方式 |
| `known-issues.md` | 已知 bug、风险和技术债 |

参考与归档（非现役规范）：

- `archive/main-dart-split-plan.md`：Historical；已完成的 `lib/main.dart` 拆分计划，现行结构见 `mobile/flutter-structure.md`。
- `reference/push-relay-spike.md`：已封存的推送中继 Spike 结论；现行发布约定见 `protocols/relay-publish-contract.md`。
- `reference/desktop-jsx/`：桌面端 React/JSX 视觉设计参考及其素材；仅供视觉比对，禁止将其中的组件结构、状态管理或实现逻辑复制到 Flutter/Android 源码。

相关外部项目：

- 后端核心：`Emerald-presence` 仓库（通常与本仓库同级；旧名 qq-st-bot）
- 桌面客户端参考：`Emerald-client` 仓库（通常与本仓库同级）

维护约定：

- 改接口、字段、鉴权或轮询路径时，同步更新 `backend/integration.md` 和 `protocols/mobile-channel.md`。
- 跨仓接口、设置/观测或调用链变化时，同步更新 `Emerald-presence/docs/three-repo-interface-catalog.md`。
- 改 Android 权限、服务、悬浮窗、无障碍或锁屏逻辑时，同步更新 `android/native-capabilities.md`。
- 改 Flutter 页面结构或准备拆分 `lib/main.dart` 时，同步更新 `mobile/flutter-structure.md`。
- 新增或修改 Flutter 可见文案时，同步维护中英文 ARB；改变语言持久化契约时同步更新 `mobile/localization.md`。
- 发现未修问题，先记到 `known-issues.md`。

## 当前工单与实施状态（2026-07-13）

| 工单 | 当前仓库状态 | 现状依据 |
|---|---|---|
| 旧工单 07（正文未随当前工作树提供） | T1、T2、T3 当前阶段已完成；T4 文档与守则已同步；app shell 仍有 profile/theme/capability/settings/附件协调结构债 | `lib/controllers/`、`lib/services/device_services.dart`、`docs/mobile/flutter-structure.md` |
| 其他编号工单 | 当前工作树未提供可审计的工单正文，不推断为已完成 | 先查 `git log -- cc-tasks` 或外部仓库对应工单，再补实现状态 |

当前工作树中的 `cc-tasks/` 以实际文件为准；旧工单 07 正文不在本仓库，不能继续作为链接目标。新增领域施工必须先建立对应工单或在现有工单追加“目标、代码落点、验证、遗留问题”四项，避免只改代码不留接力记录。

## 文档维护闭环

- Flutter 状态/页面边界：同步 `mobile/flutter-structure.md` 与工单状态。
- Android 权限、原生服务、MethodChannel：同步 `android/native-capabilities.md`；当前通道名是 `presence_mobile/settings`，`yexuan_memery` 仅为历史 prefs 名。
- HTTP、鉴权、轮询、owner/token/origin：同步 `backend/integration.md` 与 `protocols/mobile-channel.md`。
- relay signal-only 与补偿：同步 `protocols/relay-publish-contract.md` 和 `mobile/background-notification-design.md`。
- sensor 字段与隐私边界：同步 `protocols/sensor-event-protocol.md` 与 Android 能力文档。
- 验证命令与环境故障：同步 `quality/testing-and-dev.md` 和 `known-issues.md`。
