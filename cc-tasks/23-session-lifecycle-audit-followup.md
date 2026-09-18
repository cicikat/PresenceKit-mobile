# 23 — 会话生命周期补漏与设备验收

日期：2026-09-17。状态：partial — 23/0、23/A、23/B（settings 子项 blocked）、23/C、23/D、23/E 已完成；23/F 自动测试本轮验收，真机/真实后端仍 not-run。
来源：[9.18 补扫原报告](9.18补扫审计结果%20-%20副本.md)。复核基线：`209313d` 工作树；文件名中的 9.18 不作为本次执行日期。
前置：[22 固定会话角色与后端身份契约](22-session-scope-backend-coordination.md)。执行顺序：先 22，再 23。原报告保留。

## 复核结论与去重

以下 [x] 只表示完成源码/文档复核，不代表测试或修复通过。行号为基线导航，执行时按方法定位。

| 核查 | 当前证据与结论 | 归属 |
|---|---|---|
| [x] token/session reset | **已由 23/A 修复**：persist-first 凭据写入 + 全域 identity 失效 | P1；current |
| [x] Dream 切角色 | **已由 23/B 修复**本地失效；settings 归属等后端 F，子项 blocked | P1；current / blocked |
| [x] Device 生命周期 | **已由 23/C 修复**：Dart Timer 仅前台；native 后台路径保留 | P1；current |
| [x] 定时任务索权 | **已由 23/D 修复**（`d552d02`）：定时/start 不再索权 | P2；current |
| [x] 全局明文 HTTP | **已由 23/E 评估结案**：不改 Manifest，保留应用层守卫 | P2；current |
| [x] PromptAssets race | **由 22 完成**（`d1436df`）：代际守卫 + 允许新加载覆盖 | 不重复；23/A 仅查缺补漏 |
| [x] 真机矩阵 | 18 项仍 not-run（原 14 + 本单 4 项） | P1；23/F |
| [x] pending MethodChannel / delivery / Chat / ABI | 21 已完成；不重做 | — |

## 23/0 — 接收 22 成果并锁定剩余范围

- [x] 记录 22 的实际提交、后端版本、capability/字段 fixtures、scope 与 credential epoch 的实现位置、自动测试和未验收项。
  - 手机提交：`d1436df`（whoami 发现、`POST /v1/sessions` bind、`X-Presence-Session` 覆盖 chat/upload/media/history/calendar/reasoning；缺失 capability fail-loud）。文档记录 `4f6506c`。本机会话角色与 stash 的前序提交为 `67c812c`。
  - 后端：`session_scope=v1` 已由 22 消费；capability/fixtures 见 22 工单。真机/真实后端联调仍 **not-run**。
  - 实现位置：`SessionScope` / `PresenceSessionGrant`、`ProfileAppearanceController.ensurePresenceSession`、`ChatController` 冻结校验、`get/setSessionCharacterId`、`stashPendingMobileEnvelopes`。
  - 自动测试：见 22 工单 M4；真机/真实后端：**not-run**。
- [x] 重新核查上表：PromptAssets race / 本机会话与 poll stash **由 22 完成**；token 全域失效、Dream、Device Timer **由本单 A/B/C 完成**。不另建 SessionEpoch；复用 `SessionScope` + controller generation。
- [x] 事件影响域（锁定，施工落在后续子单）：
  | 事件 | 必须失效/隔离 | 不得误伤 |
  |---|---|---|
  | 节点 URL 变化 | chat/dream/device 在途、delivery cursor（既有 clear）、会话角色槽按新 origin | 主题/字体/本机用户资料 |
  | token 替换/清空 | 所有需 Bearer 的在途与后续写；凭据半切换禁止 | 同 owner 换 token ≠ 删业务数据；不清 cursor（归 22/M2） |
  | owner 变化 | 同上 + LifeRecords realm/队列绑定（既有） | 主题等本机外观 |
  | 本机角色切换 | chat reset（既有）、日记/花园（既有）；Dream 本地展示（23/B） | 不写服务器 active（22）；不自动 exit Dream |
  | 服务端 active 变化 | **不**改变本机会话（22） | — |
  | 前后台 | Dart 采集 Timer（23/C）；native 后台路径保留 | 不新增后台采集 |
  | dispose | 全部在途 apply 失效 | — |

## 23/A — 身份切换剩余领域闭环（P1）

依赖 23/0；复用 22 的会话身份与代际。落点：ConnectionController、ProfileAppearanceController、Diary/Garden/ProfileStatus 等现有 controller；AppShell 仅组合与转发事件。

- [x] 核对 token/owner/节点所有保存入口及保存失败路径，统一触发身份变更；失败不能留下内存新凭据、native 旧凭据的半切换。相同值保存保持幂等。
  - 证据：`ConnectionController.saveToken/saveOwnerUserId/saveBaseUrl` persist-first，同值 no-op 返回 `false`；`AppSettingsStore.saveBackendBaseUrl` 不再吞 `PlatformException`。Token 对话框与后端设置对话框失败不 pop。URL persist 不再 deactivate 旧 token（deactivate 仍在 token 对话框）。
- [x] 逐域清理旧显示、错误、loading 标志并失效在途结果；成功、catch、finally、Timer 和延迟 UI 回调都校验原代际，旧请求不能清掉新请求 busy 状态。保留本机主题/权限/用户资料，未发送内容按原 scope 保留或明确处理，不能直接清空全部存储。
  - 证据：`AppShell._invalidateIdentity` 转发 garden/diary/profileStatus/device/dream/profileAppearance/chat.reset。Diary/Garden/ProfileStatus 代际 + `_disposed`。同 owner 换 token 不清 cursor（`ChatController._syncDeliveryScope` 仅 origin/owner 变化清）。LifeRecords 仍走既有 `connectionChanged` realm。
- [x] PromptAssets 的 load/save/presentation 后续链共用冻结身份，切换后允许新加载，旧资产/错误不得覆盖新角色。固定角色行为沿 22，不恢复通过全局 active 切换实现本机会话的旧方案。
  - 证据：`ProfileAppearanceController.invalidateForIdentityChange` 抬 `_assetsGeneration` / `_sessionBindGeneration`；realmChanged 才按新 origin+owner 重载 sessionCharacterId。
- [x] 核对 LifeRecords 已有 connectionChanged 和原生队列隔离，仅补实际缺口，不重写 outbox、不丢 pending。delivery/cursor/seen 继续归 22/M2 与现有 store；不能每换 token 就无条件清 cursor。
- [x] 用可控延迟覆盖 A→B→A、换 token/清空 token、owner/节点切换、持久化失败、旧成功/旧异常/旧 finally、取消对话框和新会话重载；验证旧结果不展示、不触发旧身份后续写请求。
  - 自动：`test/connection_identity_test.dart`、`test/identity_domain_invalidation_test.dart`、`test/method_channel_contract_test.dart` identity persistence、`test/profile_appearance_controller_test.dart`。真机 **not-run**。

## 23/B — Dream 独立生命周期（P1）

- [x] 为 DreamController 提供与 22 会话机制对接的本地失效入口：停止轮询、终止 reveal 等待、隔离 messages/state/stats/settings/options/错误与 busy；所有异步入口及其错误/finally 校验身份。不要在 AppShell 逐字段清状态。
  - 证据：`DreamController.invalidateLocalSession({required bool clearSettings})`；`_live(generation)` 覆盖 state/stats/enter/send/wake/resume/exit/settings。
- [x] 节点/凭据/owner 改变时旧 Dream 请求必须失效；角色切换时按实际 Dream session 归属处理，不能自动把旧会话当新角色会话。清本地展示不等于向后端发 exit/wake/归档，保留既有退出确认与失败语义。
  - 证据：token/owner/节点 → `clearSettings:true`；本机角色切换 → `clearSettings:false` 且不 POST exit/wake。`exit` finally 只清本代际的 transitioning。
- [x] 读取后端综合工单 F 的 Dream settings 归属结论和 fixtures 后，才接入 per-user/per-character 设置刷新。合同未明确则该子项保持 **blocked**，其他本地失效修复继续；不得猜字段、迁移设置或复用 Reality pending。
  - **blocked**：仍用当前后端 Dream settings 合同；未猜 per-character 字段。
- [x] 扩展 `test/dream_regression_test.dart`：state/stats/settings/options/chat/enter/wake 的迟到成功与失败、发送/reveal 中切换、后台恢复、不自动退出/归档、旧 finally 不干扰新 loading。

## 23/C — 前后台采集交接（P1）

- [x] 固定最小边界：Flutter 定时采集仅在前台；native 保留已有后台屏幕上传路径。停止 Dart Timer 不等于 native 已承担电量/步数周期上报，不新增后台采集能力或绕过后台通知开关。
- [x] 对齐 resumed/hidden/paused/detached、初始化 restore 尚未完成、快速往返和 dispose；start/stop 幂等。inactive 与权限弹窗/系统选择器的短暂失焦单独验证，不粗暴等同后台退出。
  - 证据：`DeviceController.handleAppLifecycle`；`AppShell` 注入 `restored` / `foreground`（resumed + inactive）。
- [x] stop/身份变更使在途采样失效；在 await 采样前冻结 backend+token+scope，上传前再核对授权、开关、前台状态和代际，防止“旧 token + 新 backend”。已发出的请求按原身份处理，不能假称可撤销服务器已接收请求。
- [x] 核对 MainActivity onResume/onStop 与 MobileNotificationService 的启动/停止窗口；验证原生迟到任务不会在新会话采集上传。沿用敏感页过滤、默认关闭与按需截图独立授权，不扩大采集范围。
  - 证据：native `onResume`/`onStop` 未改；`ScreenObservationClient.credentials()` 与 `MobileNotificationService.postScreenContext` 仍在请求前冻结 origin+token。
- [x] 可控 Timer/延迟测试证明后台无新增 Dart 周期工作、恢复只有一组 Timer、restore 晚到不重启后台 Timer、切换/关闭授权后不继续上传、通知服务禁用时不偷偷启动替代后台任务。
  - 自动：`test/device_controller_sensor_permission_test.dart`。真机交接 **not-run**。

## 23/D — 运动权限仅显式申请（P2）

- [x] 从启动/定时 `pushSensorData` 移除索权；缺权限跳过 steps，电量可用时仍正常上报，不以伪造 0 步替代未知。
  - 证据：`DeviceController.pushSensorData`；测试 `device_controller_sensor_permission_test`。
- [x] 复用或补齐“系统配置 → 权限与功能”的显式申请入口；能力检查页只读状态和刷新，不放可编辑开关。拒绝/永久拒绝不周期重弹，权限返回刷新状态。
  - 证据：`CapabilitySheet` + `onRequestActivityRecognition`；`controlsOnly` 才可点授权；`resumed` 刷新。
- [x] 维护中英 ARB 并生成本地化；复用周边控件样式。测试自动路径零次 request、显式点击才 request、拒绝降级、已授权读取步数。
  - 证据：ARB + `flutter gen-l10n`；上述单元测试。真机授权往返 **not-run**。提交：`d552d02`。

## 23/E — HTTP 防御纵深兼容性评估（P2）

- [x] 定点核查 Flutter BackendClient、native 服务/LifeRecords/relay/媒体等实际网络入口是否统一校验 origin、禁止重定向泄漏凭据；出现真实绕过时另列具体修复及证据，不用“未来 SDK 可能绕过”替代现有漏洞证据。
  - 证据：入口表见 `docs/known-issues.md`「明文 HTTP 防御纵深评估」；未发现未校验 origin 的凭据重定向实锤绕过。
- [x] 核对 Android Network Security Config 对当前网络栈的实际作用和动态私网 origin 支持，记录 loopback、Tailscale、用户确认 LAN/MagicDNS、HTTPS 与 prod/dev 兼容矩阵；不得假定静态 XML 能表达所有动态信任规则。
  - 证据：无 `network_security_config`；`BackendSecurityPolicy.isAllowedBaseUrl` 矩阵同上。
- [x] 能兼容现有连接才提出最小配置并验证；否则文档化保留原因、应用层守卫回归与后续条件。本项允许以有证据的“不改 Manifest”评估结案，不强制 HTTPS-only，也不静默放宽公网 HTTP。
  - **结案：不改 Manifest**；保留 cleartext + 应用层守卫。同步 `native-capabilities.md` / `known-issues.md`。

## 23/F — 验收、文档与提交

- [x] 三面检查：管理面继续拥有授权/capability/effective state；桌面仅需 22 跨端隔离回归，无新设置；手机负责本机生命周期与权限。逐项记录理由，不在能力页新增运维面板。
  - 管理面：无新开关。session_scope / Dream settings 归属仍在后端；本单不新增手机侧运维面板。
  - 桌面：无新设置；跨端隔离仍归 22。
  - 手机：本机 token/owner/节点失效、Dream 本地展示隔离、前台 Dart 采集交接、显式运动权限。能力页仍只读。
- [x] 沿输入/触发→接口/队列→Flutter/Android→UI/通知检查鉴权、scope、关联键、去重、ack、TTL、fallback；不改 22 的 queue cursor 契约，不新增永久台账。若确需新增落盘状态，先落实同单观测及后端授权，不能只在手机侧宣告完成。
  - 未新增落盘状态或观测端点。cursor 仍 origin+owner。LifeRecords realm 仍既有。
- [x] 本批按文档串行 analyze + 相关 Flutter 回归；未跑全量、未与 Git 并行。
- [x] 复用 `docs/android/device-lifecycle-matrix.json` 与说明文档，补会话切换、无自动索权和采集交接场景。四项仍 **not-run**。
- [x] 真机覆盖：本机无已连接设备，标 **not-run**。矩阵 18 项均无环境块/证据。
- [x] 同步 native-capabilities、known-issues、flutter-structure。Dream settings 合同明确保留 blocked。
- [x] 自动测试已记；真实后端/真机 **not-run**。功能提交 `78ccafe`。

## 顺序与可并行边界

22 → 23/0 → A → B/C → D → F；E 的只读评估可独立准备。B 与 C 设计可并行，但共享 AppShell/session/native 文件的修改串行；D 与 C 共用 DeviceController，串行提交。Dream settings 合同未落定只阻塞 B 对应子项，不阻塞 C/D/E。

本轮已完成：23/0、23/A、23/B（settings 子项 blocked）、23/C、23/D、23/E、23/F 自动测试与文档。剩余真机/真实后端联调 not-run。
