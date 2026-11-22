# 63 财务同步 P1 / P2

- [x] P1：复现暂停自动账目阻塞手动账目，修复选择可发送操作；回归手动可同步、自动保留且操作 ID 稳定。
- [x] P2：区分网络退避与人工处理，验证后台停止重试及显式恢复；冲突/拒绝仅隔离对应记录。
- [x] 核对测试矩阵与 CI，新增 ci.yml/finance-native；后端 docs/testing-matrix.md 按实际触发条件修正，真实设备边界保持未验收。
- [x] 在当前 main 施工并完成本地验证和差异检查；不创建分支或 worktree。
- [ ] 提交后推送当前 main 并核对 GitHub SHA 与当前提交的检查（结果以本次交付聊天及 Actions 为准）。

范围：手机原生队列与后台调度；后端仅同步合同文档，无桌面运行代码、后端设置/权限/HTTP schema 变化。真实支付通知、权限往返、后台/强停/重启不在合成测试中宣称通过。

P1红灯：build/finance63-p1-red.log，pausedAutomaticRecordsDoNotBlockManualSync 未上传手动账目的断言失败。P2红灯：build/finance63-p2-red.log，人工状态被设置定时重试、后续账目未发送、后台任务延迟缺失三条业务断言失败。

修复后Java21/API28定向与真实隔离HTTP合同：FinanceTest 13、FinanceBackendContractTest 1、LifeRecordsTest 25、BackendSecurityPolicyTest 2，共41项，零失败/错误/跳过；日志build/finance63-contract.log及JUnit XML。通知测试先启用收集再由since构造时间，修复旧有10ms时序假设，不放宽去重/授权断言。后端Python3.12 tests/test_finance.py 10项通过。

Flutter定向：flutter test --no-pub test/finance_test.dart test/life_records_test.dart test/localization_contract_test.dart，31项通过（build/finance63-flutter.log）。UTF-8/workflow YAML结构校验、git diff --check、逐文件普通/ignore-cr-at-eol差异统计一致。未改Flutter可见文案/控件，无新增本地化或Admin静态资源验收需求。
