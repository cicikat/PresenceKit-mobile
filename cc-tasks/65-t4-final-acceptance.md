# 65：T4 最终验收与结构回归

日期：2026-11-25；状态 partial；本单不授权生产部署或正式发布。

- [x] 核对指定基线 24b8867b11e43e14f130a3f63c417c3420a9275a。
- [x] 运行完整 Flutter 测试：478 passed，1 failed；T4 为组合根新增一行，触发既有 1499 行结构上限。
- [x] `lib/pages/app_shell.dart` 使用 ensurePresenceSession 方法引用替换转发闭包；净减 5 行，不提高上限、不降低业务断言。
- [x] 完整 Flutter：479 passed（63s）；`flutter analyze --no-pub`：No issues found（57.1s）。日志保存在本机 ignored build 目录。
- [x] `flutter build apk --debug --flavor dev --no-pub` 成功（156.5s），仅独立 dev 调试包，无正式发布。
- [ ] 测试手机独立 dev 包联验：首次 ADB 可见，安装前 USB 连接消失；等待恢复连接，不把构建成功计为设备通过。
- [ ] 真实聊天、角色切换、录音/转写/语音回执、前后台、过期、重启、断网恢复与不重放证据。
- [ ] 与最终后端、桌面 SHA 重新跑合同矩阵；证据在后端 T4-02 报告与 protocol-matrix.json 汇总。
- [x] 2026-11-26 按用户最新指令合并 PR #21，测试/设备/独立审查状态如实保留，不再作为合并门禁。
- [x] 当前 main 的 Flutter/native CI 与 Android instrumented 均通过，见集成文档链接；不等于真机验收。
- [ ] 2026-11-26 再次检查 ADB 设备列表为空，十项真机验收 NOT RUN；等待测试手机连接。

入口：`lib/pages/app_shell.dart` 中 ChatController 的 resolvePresenceSession 组合。
验证保留 `test/app_shell_structure_test.dart`、全部聊天恢复、发送期限、交互和协议用例。
