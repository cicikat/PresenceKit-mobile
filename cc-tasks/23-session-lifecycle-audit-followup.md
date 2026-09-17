# 23 — 会话生命周期补漏与设备验收

日期：2026-09-17。状态：open，已复核并编单，施工未开始。
来源：[9.18 补扫原报告](9.18补扫审计结果%20-%20副本.md)。复核基线：`209313d` 工作树；文件名中的 9.18 不作为本次执行日期。
前置：[22 固定会话角色与后端身份契约](22-session-scope-backend-coordination.md)。执行顺序：先 22，再 23。原报告保留，不修改运行代码、不构建、不安装、不发布。

## 复核结论与去重

以下 [x] 只表示完成源码/文档复核，不代表测试或修复通过。行号为本次基线导航，执行时按方法定位。

| 核查 | 当前证据与结论 | 归属 |
|---|---|---|
| [x] token/session reset | `ConnectionController.saveToken:60` 只保存并通知；`app_shell.dart:406–433` 已启动同步时仅刷新 UI。身份切换失效机制缺口成立；尚未复现跨 owner 数据泄漏，不定为已证实 P0 | P1；22/M1、M2 负责主链，23/A 只补遗漏领域 |
| [x] Dream 切角色 | `app_shell.dart:836–848` 清 diary/garden 并重置 chat，未重置 Dream。Dream 已有 `_generation`、exit/dispose 失效和 settings 的 token/backend guard，原报告不能解读为完全无保护；stats 等仍可迟到，角色归属不能靠猜 | P1；23/B，Dream settings 语义依赖后端 F |
| [x] Device 生命周期 | `DeviceController.start/stop` 管理 45 秒/30 分钟 Timer；`app_shell.dart:248–260` 后台只暂停 Life Records/chat，未停 device。原生后台 poll 也可上传屏幕上下文。存在交接缺口，未证实系统后台实际双采 | P1；23/C |
| [x] 定时任务索权 | `DeviceController.pushSensorData` 缺运动权限时调用 `requestActivityPermission`，start 会立即调用，之后周期调用 | P2；23/D，明确用户操作才能索权 |
| [x] 全局明文 HTTP | Manifest:18 为 `usesCleartextTraffic=true`，main/res/xml 无 network security config；native 能力文档已说明私网 HTTP 与应用层 origin 校验 | P2 防御纵深；23/E 评估，不当作已证实漏洞 |
| [x] PromptAssets race | 原报告 AppShell 直接 setState 的落点已过时；当前 `ProfileAppearanceController.loadPromptAssets/updateActiveCharacter:183–218` 仍直接写回，缺代际 guard，loading 锁还可能阻止新会话加载 | P1；22/M1 优先覆盖，23/A 查缺补漏 |
| [x] 真机矩阵 | `docs/android/device-lifecycle-matrix.json` 为 not-run/none，14 项全部 not-run | P1 验收缺口；23/F 复用矩阵，不能推断所有历史真机验证都没做过 |
| [x] pending MethodChannel 断口 | `MainActivity:104` 委托 `MobileDeliveryChannel.dispatch`；后者:66–67 已处理旧/新 consume 方法，:86 使用 native store | 旧结论已过时；21/A1–A4 已实现，不重做；A5 真机仍开放 |
| [x] delivery 单 authority | `MobileDeliveryStateStore` 已提供进程级锁，21/B 已完成；仍需 22/M2 的 scope 合同与在途校验 | 重复项；不重建 store，不宣称 exactly-once |
| [x] Chat reconciliation / AppShell 瘦身 | 21/C、E 已完成，结构文档已有 ChatSessionCoordinator 与各 controller 所有权 | 不再开重构单；23 仅处理具体生命周期缺口 |
| [x] yexuan_memery / channel 命名 | 21/H 已确认历史 ABI 保留 | 不改名；发现具体漂移再定点修订 |

## 23/0 — 接收 22 成果并锁定剩余范围

- [ ] 记录 22 的实际提交、后端版本、capability/字段 fixtures、scope 与 credential epoch 的实现位置、自动测试和未验收项。不得只凭工单勾选认定已完成。
- [ ] 重新核查上表及当前差异：22 已覆盖的条目写明证据并标“由 22 完成”，不重复改造。22 未落实请求/身份隔离时先回填 22，不能另建一套 SessionEpoch 绕过。
- [ ] 按事件列清节点、token 替换/清空、owner 变化、本机角色切换、服务端 active 变化、前后台及 dispose 的影响域。凭据变化必须使旧授权工作失效，但不把 token 字符串当 owner，也不把同 owner 换 token 等同删除业务数据。

## 23/A — 身份切换剩余领域闭环（P1）

依赖 23/0；复用 22 的会话身份与代际。落点：ConnectionController、ProfileAppearanceController、Diary/Garden/ProfileStatus 等现有 controller；AppShell 仅组合与转发事件。

- [ ] 核对 token/owner/节点所有保存入口及保存失败路径，统一触发身份变更；失败不能留下内存新凭据、native 旧凭据的半切换。相同值保存保持幂等。
- [ ] 逐域清理旧显示、错误、loading 标志并失效在途结果；成功、catch、finally、Timer 和延迟 UI 回调都校验原代际，旧请求不能清掉新请求 busy 状态。保留本机主题/权限/用户资料，未发送内容按原 scope 保留或明确处理，不能直接清空全部存储。
- [ ] PromptAssets 的 load/save/presentation 后续链共用冻结身份，切换后允许新加载，旧资产/错误不得覆盖新角色。固定角色行为沿 22，不恢复通过全局 active 切换实现本机会话的旧方案。
- [ ] 核对 LifeRecords 已有 connectionChanged 和原生队列隔离，仅补实际缺口，不重写 outbox、不丢 pending。delivery/cursor/seen 继续归 22/M2 与现有 store；不能每换 token 就无条件清 cursor。
- [ ] 用可控延迟覆盖 A→B→A、换 token/清空 token、owner/节点切换、持久化失败、旧成功/旧异常/旧 finally、取消对话框和新会话重载；验证旧结果不展示、不触发旧身份后续写请求。

## 23/B — Dream 独立生命周期（P1）

- [ ] 为 DreamController 提供与 22 会话机制对接的本地失效入口：停止轮询、终止 reveal 等待、隔离 messages/state/stats/settings/options/错误与 busy；所有异步入口及其错误/finally 校验身份。不要在 AppShell 逐字段清状态。
- [ ] 节点/凭据/owner 改变时旧 Dream 请求必须失效；角色切换时按实际 Dream session 归属处理，不能自动把旧会话当新角色会话。清本地展示不等于向后端发 exit/wake/归档，保留既有退出确认与失败语义。
- [ ] 读取后端综合工单 F 的 Dream settings 归属结论和 fixtures 后，才接入 per-user/per-character 设置刷新。合同未明确则该子项保持 blocked，其他本地失效修复继续；不得猜字段、迁移设置或复用 Reality pending。
- [ ] 扩展 `test/dream_regression_test.dart`：state/stats/settings/options/chat/enter/wake 的迟到成功与失败、发送/reveal 中切换、后台恢复、不自动退出/归档、旧 finally 不干扰新 loading。

## 23/C — 前后台采集交接（P1）

- [ ] 固定最小边界：Flutter 定时采集仅在前台；native 保留已有后台屏幕上传路径。停止 Dart Timer 不等于 native 已承担电量/步数周期上报，不新增后台采集能力或绕过后台通知开关。
- [ ] 对齐 resumed/hidden/paused/detached、初始化 restore 尚未完成、快速往返和 dispose；start/stop 幂等。inactive 与权限弹窗/系统选择器的短暂失焦单独验证，不粗暴等同后台退出。
- [ ] stop/身份变更使在途采样失效；在 await 采样前冻结 backend+token+scope，上传前再核对授权、开关、前台状态和代际，防止“旧 token + 新 backend”。已发出的请求按原身份处理，不能假称可撤销服务器已接收请求。
- [ ] 核对 MainActivity onResume/onStop 与 MobileNotificationService 的启动/停止窗口；验证原生迟到任务不会在新会话采集上传。沿用敏感页过滤、默认关闭与按需截图独立授权，不扩大采集范围。
- [ ] 可控 Timer/延迟测试证明后台无新增 Dart 周期工作、恢复只有一组 Timer、restore 晚到不重启后台 Timer、切换/关闭授权后不继续上传、通知服务禁用时不偷偷启动替代后台任务。

## 23/D — 运动权限仅显式申请（P2）

- [ ] 从启动/定时 `pushSensorData` 移除索权；缺权限跳过 steps，电量可用时仍正常上报，不以伪造 0 步替代未知。
- [ ] 复用或补齐“系统配置 → 权限与功能”的显式申请入口；能力检查页只读状态和刷新，不放可编辑开关。拒绝/永久拒绝不周期重弹，权限返回刷新状态。
- [ ] 维护中英 ARB 并生成本地化；复用周边控件样式。测试自动路径零次 request、显式点击才 request、拒绝降级、已授权读取步数。

## 23/E — HTTP 防御纵深兼容性评估（P2）

- [ ] 定点核查 Flutter BackendClient、native 服务/LifeRecords/relay/媒体等实际网络入口是否统一校验 origin、禁止重定向泄漏凭据；出现真实绕过时另列具体修复及证据，不用“未来 SDK 可能绕过”替代现有漏洞证据。
- [ ] 核对 Android Network Security Config 对当前网络栈的实际作用和动态私网 origin 支持，记录 loopback、Tailscale、用户确认 LAN/MagicDNS、HTTPS 与 prod/dev 兼容矩阵；不得假定静态 XML 能表达所有动态信任规则。
- [ ] 能兼容现有连接才提出最小配置并验证；否则文档化保留原因、应用层守卫回归与后续条件。本项允许以有证据的“不改 Manifest”评估结案，不强制 HTTPS-only，也不静默放宽公网 HTTP。

## 23/F — 验收、文档与提交

- [ ] 三面检查：管理面继续拥有授权/capability/effective state；桌面仅需 22 跨端隔离回归，无新设置；手机负责本机生命周期与权限。逐项记录理由，不在能力页新增运维面板。
- [ ] 沿输入/触发→接口/队列→Flutter/Android→UI/通知检查鉴权、scope、关联键、去重、ack、TTL、fallback；不改 22 的 queue cursor 契约，不新增永久台账。若确需新增落盘状态，先落实同单观测及后端授权，不能只在手机侧宣告完成。
- [ ] 按 `docs/quality/testing-and-dev.md` 串行执行格式、analyze、相关 Flutter 回归；原生有改动则跑对应 Kotlin 测试及必要 dev build。复用既有 Dream、poll lifecycle、channel/delivery、LifeRecords、安全策略测试；禁止测试与 Git mutation 并行。
- [ ] 复用 `docs/android/device-lifecycle-matrix.json` 与说明文档，补会话切换、无自动索权和采集交接场景，记录设备/Android/app/backend 版本、时间和脱敏证据。22/M4 与 21/A5/G5 已有同环境有效证据可引用；代码变更影响到的场景重测，未测仍 not-run。
- [ ] 真机覆盖离线通知、Doze、kill/swipe/reboot、relay 中断、权限拒绝、OEM 策略及快速前后台/身份切换；没有设备则标 blocked/not-run，不将矩阵格式测试或模拟器当真机通过。安装、清数据或发行包验证遵守各自授权与签名要求，不为跑矩阵擅自卸载数据。
- [ ] 同步实际受影响的 flutter-structure、native-capabilities、known-issues；接口变化才同步 integration/mobile-channel，跨仓总账通过已授权的后端协作回填 open/observe。未解决 Dream 合同明确保留。
- [ ] 每完成独立修复并验收后单独 commit，仅暂存本单文件；记录自动测试/真实后端/真机分别结果。全部已实现与验证项才勾选，不能以“代码写完”关闭真机项。

## 顺序与可并行边界

22 → 23/0 → A → B/C → D → F；E 的只读评估可独立准备。B 与 C 设计可并行，但共享 AppShell/session/native 文件的修改串行；D 与 C 共用 DeviceController，串行提交。Dream settings 合同未落定只阻塞 B 对应子项，不阻塞 C/D/E。此说明不自动授权启动并行代理。

本次交付仅工单与 known-issues 登记。未重跑历史测试，未完成任何本单施工或真机验收。
