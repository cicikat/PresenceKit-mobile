# 33 · 梦境 Flow 主题接入与外观预设

范围：Flutter 手机/手机网页，两种新增梦境主题「金色剧场」「靛蓝轨道」。沿用 DreamController 的业务状态、请求、逐段 reveal、醒来门控与草稿生命周期。不改后端业务或桌面代码；允许同步跨仓总账。

- [x] 审计调用链、现有设置和原生落盘接口；证据：ThemeController 持久主题 JSON、ProfileAppearanceController 拥有既有文字/图片 prefs，DreamController 仍独占业务；原 manageThemes 的 Navigator.pop 关闭父设置，已定位。
- [x] 模型/ThemeController：独立两主题日夜颜色与参数预设、选择、编辑、新建、旧数据兼容；证据：dream_appearance_test.dart 五项读写/隔离/坏数据/失败重试/并发/native JSON 用例通过。
- [x] 原生 Shader 与两主题 Dream UI：真实状态/消息、光学玻璃、日夜默认、生命周期/减少动态效果与降级；证据：web Shader 编译通过，原 Dream 回归与新草稿/颜色字号透明度 widget 回归通过；原生实际 GPU 仍 not-run。
- [x] 设置「夜间外观主题」和「日间背景」之间新增梦境外观主题；预览共用实际渲染，切换两主题、编辑/保存/选用预设；迁移原梦境 UI 设置；修复关闭子窗口返回父设置。证据：320px 预设新建/选用测试通过，实际 AppShell 的日间/梦境子窗口关闭回父设置测试通过，原 UI 分组从 settings_widgets 迁入 manager。
- [x] 双语 l10n、三面闭环、结构/known-issues/总账同步（证据：docs/mobile/dream-flow-appearance.md、native-capabilities、known-issues 与后端总账）。无新业务权限、接口或后台行为；本机外观状态通过既有主题 JSON 存储，编辑器就是只读观测/预览入口，无需后端观测端点。
- [x] 顺序执行格式/l10n/analyze、必要测试、web/dev APK 构建，实际 Flutter 网页截图预览，检查 CRLF/diff 并小步提交。证据：analyze 0 issues，全量 376 passed；web 与 Dev debug APK 构建成功；build/review/dream-flow 四张日夜截图与 browser-validation.json，previewErrors 为空、returnedToSettings=true；启动时被拦截的后端连接异常不算连接验收。
- [ ] 真机 GPU、软键盘、相册/OEM、重启与功耗验收（not-run，不能以浏览器/测试替代）。