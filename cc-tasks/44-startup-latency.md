# 44 启动卡顿与 0.2s 首屏（本地缓存优先，网络后台补）

目标：冷启动 200ms 内首帧可见头像+缓存聊天记录可交互（本地缓存优先）；新鲜网络数据后台补齐。SQLite/落盘缓存、合并 bootstrap 端点均未做，见 known-issues。

- [x] P0：`profile_appearance.loadPromptAssets` 先本地 `applyActiveCharacterPresentation`（头像/名称不挡在网络后面）。证据：`profile_appearance_controller.dart:260-273`
- [x] P1：`BackendClient` 单例复用 `HttpClient`（keep-alive），`isAllowedBaseUrl` 按 baseUrl 缓存，`connectionTimeout` 8s→3s。证据：`backend_client.dart` `_newClient/_isAllowedBaseUrl`、`http_request_budget.dart` `closeClient` 共享不强关
- [ ] P0/P1 已恢复原时序：启动仍串行等 promptAssets+bind、历史/activate/replay 时序不变（结构契约 `app_shell_structure_test`、catch-up 静态渲染由原时序保证）。真正的本地缓存/解耦需新落盘缓存+分步解耦施工，未做
- [x] 验收：`flutter analyze` 无问题；相关 60 项通过（含 profile_appearance/chat_recovery/mobile_catchup/app_shell_structure）。真机冷启动打点 not-run，未量测 200ms
- [x] 三面闭环：无新增落盘字段/设置/接口/Android 权限，无跨端影响（纯本仓连接复用优化）
