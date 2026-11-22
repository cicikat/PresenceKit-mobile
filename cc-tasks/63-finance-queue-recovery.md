# 63 财务同步 P1 / P2

- [x] P1：复现暂停自动账目阻塞手动账目，修复选择可发送操作；回归手动可同步、自动保留且操作 ID 稳定。
- [x] P2：区分网络退避与人工处理，验证后台停止重试及显式恢复；冲突/拒绝仅隔离对应记录。
- [x] 核对测试矩阵与 CI，新增 ci.yml/finance-native；后端 docs/testing-matrix.md 按实际触发条件修正，真实设备边界保持未验收。
- [x] 在当前 main 施工并完成本地验证和差异检查；不创建分支或 worktree。
- [x] 已提交并推送当前 main，fetch核对远端完整SHA一致；已跟进当前提交检查，最终状态以 Actions 和交付聊天为准。

范围：手机原生队列与后台调度；后端仅同步合同文档，无桌面运行代码、后端设置/权限/HTTP schema 变化。真实支付通知、权限往返、后台/强停/重启不在合成测试中宣称通过。

P1红灯：build/finance63-p1-red.log，pausedAutomaticRecordsDoNotBlockManualSync 未上传手动账目的断言失败。P2红灯：build/finance63-p2-red.log，人工状态被设置定时重试、后续账目未发送、后台任务延迟缺失三条业务断言失败。

修复后Java21/API28定向与真实隔离HTTP合同：FinanceTest 13、FinanceBackendContractTest 1、LifeRecordsTest 25、BackendSecurityPolicyTest 2，共41项，零失败/错误/跳过；日志build/finance63-contract.log及JUnit XML。通知测试先启用收集再由since构造时间，修复旧有10ms时序假设，不放宽去重/授权断言。后端Python3.12 tests/test_finance.py 10项通过。

Flutter定向：flutter test --no-pub test/finance_test.dart test/life_records_test.dart test/localization_contract_test.dart，31项通过（build/finance63-flutter.log）。UTF-8/workflow YAML结构校验、git diff --check、逐文件普通/ignore-cr-at-eol差异统计一致。未改Flutter可见文案/控件，无新增本地化或Admin静态资源验收需求。

实现提交 f60063c；后端合同/矩阵提交4aeeef3，用户授权的旧工单删除0604ded。桌面Cargo.toml只有工作区换行标记，没有内容差异，刷新索引后干净。初次ci 45016933355在setup-android默认安装已下线tools包时失败（未执行财务测试）；显式packages=platform-tools，保留NDK安装和全部断言，按action.yml实际输入修复。
