# 自动记账 330：实现与验收

## 使用入口与边界

生活记录 → 自动记账。先在后端管理面「消息分发与客户端设置 → 服务配置总览 → 自动记账」启用同步，再由用户在手机系统授予通知读取权限，最后开启本机收集。两边默认均关闭。固定范围是微信支付、支付宝、工商银行、建设银行、招商银行的已审计文案；其他渠道或缺失通知可手动记录。

支付通知不是官方账单 API，ROM/支付应用可能隐藏、折叠、延迟或漏发。汇总通知和重连旧通知不补猜。未确认项不会计入流水。退款、转账/还款独立显示；相同金额时间接近只提示疑似重复，不自动吞并两次消费。用户可确认、修正金额/方向/分类/商户、忽略、撤销确认和删除；删除为保留历史的墓碑。不会自动付款、扣库存或向聊天插入消费消息。

## 模块与协议

- Android `finance/`：PaymentParser 独立保守规则，BigDecimal→Long整数分；PaymentNotificationListenerService 独立收集；FinanceStore 私有SQLite；FinanceSync 有界HTTP、回执匹配及退避；FinanceBridge/JobService 只做桥接和后台调度。
- Flutter `finance_service/controller/widgets.dart`：Channel、作用域与迟到结果、既有生活记录风格页面。未往 AppShell/MainActivity 塞业务，MainActivity 只注册一行桥接。
- `presence_mobile/finance`：snapshot、permissionSettings、setEnabled、manual、edit、sync、detail、acceptServer。参数 origin/owner 来自当前可信连接，不含 token、char 或通知全文。
- 正式 API 为 `/finance/capabilities`、`/finance/candidates[/sync|/{id}]`；mobile profile 新增 finance_ingest scope，显式旧 scopes 需管理员补发。完整合同在后端 `docs/finance-ingest.md`，两仓匿名 fixture 分别为 `tests/fixtures/finance-v1.json` 与 `android/app/src/test/resources/finance-v1.json`。

账本归用户，角色只经后端默认关闭的 character_readable 和 read_finance_records 只读工具查询；不触碰 inventory_log。桌面无原生消费者，复用后端管理页，不新增桌面设置真值。

## 队列、纠错与恢复

`finance_v1.db` 位于本应用私有数据库目录，只保存规范化候选、指纹、不可变操作快照和同步状态，不保存通知原文或凭据。采用最小化持久化，没有另行宣称整库加密。先保存后请求，每个操作ID稳定；超时保持待同步并重发同载荷，不能创建第二笔。用户在离线时修改会保留 desired record，原操作收到回执后再产生下一 revision 的纠错操作，原交易ID一直保留。

收集开关和队列按规范化后端origin+owner隔离，角色切换不另建账本。切账号/后端不发送旧作用域，迟到UI结果丢弃。撤销通知读取后不再采集/上传自动候选，恢复须系统授权；暂停保留未发送项。JobScheduler 是尽力调度，强停/OEM后台限制不承诺实时；打开页面可查看并手动同步。401/403、后端关闭、冲突、断网、限流均不伪装成功。409保留本机记录，用户可采用服务端版本后重新编辑。

服务端 SQLite 同事务保存候选/历史/操作回执；由原 backup-state inventory覆盖。需要备份时按项目现有create/verify/coverage流程，不另写全量复制。回滚先关后端与本机收集，保留数据库后回退330程序提交。卸载会丢失未同步条目，换机前先同步；服务端可分页回取。页面最多展示本机最近1000条，支出统计明确限定缓存中的已确认且已同步 CNY 支出，不冒充完整月报。

## 验证命令与证据

330-A 审计提交 5a1ef45；330-B 原生收集提交 b7fdf61；后端330-C提交 a0596b2。

常规定向：`flutter analyze --no-pub`、`flutter test --no-pub test/finance_test.dart test/life_records_test.dart test/localization_contract_test.dart`、Android `gradlew.bat :app:testDevDebugUnitTest --tests com.presencekit.mobile.FinanceTest`。Flutter截图可加 `--dart-define=FINANCE_CAPTURE=true`，结果位于 build/review/finance330。

真实HTTP合同（不访问生产）：先在后端运行 `.venv/Scripts/python.exe tests/finance_contract_server.py --state-dir .tmp/finance330-contract`，固定loopback18730和公开测试凭据；再在手机android目录运行 `gradlew.bat :app:testDevDebugUnitTest -PfinanceContract --tests com.presencekit.mobile.FinanceBackendContractTest`。此源集仅显式启用，不在普通单测中伪造服务端或新增skip。测试沿真实解析→本机SQLite→HTTP→后端SQLite→确认→模拟回执丢失重发→纠错→查询，验证一条候选、同一交易ID和三个版本。输出匿名回执 build/finance-native-live-receipt.json，未代表真实系统通知或已安装Flutter往返。

| 项目 | 结果 |
|---|---|
| 固定SHA、MIT/Apache审计与排除清单 | PASS，审计报告 |
| 原生解析、精确去重、权限撤销、汇总/旧通知过滤、SQLite重开与队列 | PASS，FinanceTest |
| 原生真实loopback HTTP→后端持久化、稳定回执与纠错 | PASS，FinanceBackendContractTest |
| 后端权限/金额/并发事务/历史/备份登记/便携schema/依赖方向 | PASS，后端测试日志 |
| 管理面默认关、保存/刷新、关闭及effective可见状态 | PASS，隔离服务浏览器实测 |
| Android14真实微信/支付宝通知与权限往返 | NOT RUN，首次无设备；后续已安装但通知权限未开启 |
| 真机后台/强停/重启/断网与卸载换机 | NOT RUN |
| 真实角色模型查询与生产部署 | NOT RUN |

未做：OCR/CSV/XLSX导入、完整报表、逐银行更多文案、自动跨渠道强证据关联、财务写工具。后续如删除旧逻辑应另开删除brief，本单不删除现有功能或测试。

## 最终本机证据

2026-11-16：`flutter gen-l10n` 成功，`flutter analyze --no-pub` 零问题（build/finance-analyze-final.log）；Flutter全量467项通过（build/finance-all-flutter-recheck.log），财务/生活记录/双语定向30项通过，真实字体320px/1.4倍字深浅主题6项通过（build/finance-ui-test.log，截图build/review/finance330/light.png和dark.png）。首次全量466通过/1失败来自既有theme_controller预设名“深夜/暖色”不一致；单独5项与再次全量均通过，未修改该领域，保留首次日志build/finance-all-flutter-test.log。

Android API28 Robolectric：FinanceTest 8、真实HTTP合同1、LifeRecords25、BackendSecurityPolicy2，共36项，零失败/错误/跳过（build/finance-native-live-final.log及XML）。最终合同使用真实注册的mobile profile测试凭据；capabilities允许，admin-only settings返回403，不要求手机持有admin。

Dev APK：`build/app/outputs/flutter-apk/app-dev-debug.apk`，SHA256 `6D75D0BCB3D3C5446C0E357497A8AB6A7826C9698FE5BFD6A39972C0AAEBEB93`，构建168.7秒（build/finance-debug-apk.log）。没有安装、正式签名发行、改发行版本或生产部署。`adb devices`为空，真机项目保持NOT RUN。后端API核心已随PR24合入main，当前联调用独立loopback fixture，不代表VPS已启用。

## 用户连接手机后的覆盖安装

用户明确授权安装后，使用既有永久签名构建 `1.3.0+87` prod release，核验历史已安装APK与新包certificate SHA256均为 `1869b348d9e26f13d8213ff60933bcf933fe6e8779d13198f655a4d7c0791fae`。`adb install -r` 成功，系统包信息确认versionCode87/versionName1.3.0；原应用已启动，既有聊天记录仍存在。未卸载、未清除应用数据，未创建新密钥或发布GitHub Release。包位于 `dist/release/PresenceKit-mobile-v1.3.0-build87.apk`，SHA256 `1FA7CB82D8DEAFC4C9D3B29B7956AEA4E2A47C1800797D0763A23C7BA42F070E`（build/finance-build87-release.log，105.7秒）。

build87 同时修正来源时间显示：原通知偏移必须显示为 +08:00/-05:00 等，不再把平移后的当地时间误标为UTC；跨月边界回归通过。最新analyze零问题，财务/生活记录/本地化31项通过（build/finance-build87-tests.log）。手机API35模拟器CI `43859169268`通过，但仍不替代支付App真通知。

只读查询确认财务NotificationListener尚未获系统授权，收集仍默认关闭；没有通过ADB授予通知读取权。真实支付通知、权限往返、确认后真实手机→生产后端、后台/强停/重启及真实模型查询仍NOT RUN。未改生产服务配置。
