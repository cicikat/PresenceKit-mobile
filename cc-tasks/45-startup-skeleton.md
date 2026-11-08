# 45 启动骨架屏与本地头像并行

- [x] `_restoreBackendAndStart`：本地头像 `applyActiveCharacterPresentation` 与后续 promptAssets 并行（仅此一行，`app_shell.dart:266`）
- [x] 验收：`flutter analyze` 无问题；全量测试 399/400 通过，唯一失败 `foreground_mobile_delivery_contract_test` 在 stash 前后均失败，属既存失败，与本单无关
- [ ] 骨架屏、启动打点已撤回（行数红线 1499 + 组合根不加逻辑）；真机冷启动打点 not-run，不冒充 200ms
- [x] 三面闭环：纯本仓 UI/时序，无新增落盘/设置/接口/Android 权限，无跨端影响
