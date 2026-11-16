# 330-A 固定版本审计

2026-11-16。外部仓库已由施工者克隆至本机第三方仓库目录，工作区干净后 detached checkout 固定 SHA。

| 来源 | 精确版本 / 许可证 | 代码证据 | 决策 |
|---|---|---|---|
| https://github.com/huanghhcri/SmartLedger | d3a3ba009aa6463ab576390d7bc57df9523783eb / MIT，Copyright (c) 2026 SmartLedger | service/NotificationParser.kt、DedupHelper.kt、PaymentNotificationListener.kt、test/service/DedupHelperTest.kt | adapt 规则理念；rewrite 金额、去重、监听和队列；不复制源码 |
| https://github.com/FridayKoi/WhereIsMyMoney | e29ae0315fd66605057cd86c29466bd0b048b8e0 / Apache-2.0 | service/PaymentNotificationListener.kt、ui/permissions/PermissionsScreen.kt、ui/import_screen/ImportViewModel.kt | 只读研究授权与手动纠错；不引入依赖或代码 |
| https://github.com/Skybaby-T/AutoBook | 未独立确认许可证/版本 | 本轮不克隆、不采纳源码 | reject；OCR 不在 V1 范围 |

SmartLedger 使用 Android minSdk 26、compile/target 35、JVM 17；AGP 8.7.3、Kotlin 2.0.21、KSP 1.0.27，Room 2.6.1、Compose BOM 2024.12.01、WorkManager 2.10.0；依赖来源为 Gradle Google/Maven Central。上游构建入口为 android Gradle 项目根的 `gradlew.bat assembleDebug testDebugUnitTest`，本轮仅审计、不构建第三方 App。实际解析直接依赖 Android Log 和 Double；DedupHelper 依赖 TransactionDao/Transaction/Category、CurrencyUtil 和协程 Mutex，不能原样抽入本项目。数据库入口 data/db/AppDatabase.kt 和 DAO 管理正式交易，监听在 onListenerConnected 启动 KeepAliveService，不采纳其保活策略。

| 能力 | SmartLedger 实现 | WhereIsMyMoney 实现 | PresenceKit 取舍 |
|---|---|---|---|
| 渠道 | 钱包、电商、银行（含包名片段匹配） | 微信/支付宝白名单 | 精确白名单，先微信/支付宝及选定银行 |
| 收支/退款 | 退款匹配列入 income，金额 Double | 解析后直接写交易 | 独立 refund/transfer/unknown；整数分，用户确认后才计入 |
| 折叠 | extras/bigText、同组 child 补全 | 多 extras 拼接 | 跳过汇总，缺字段保留未知，不扫描历史通知 |
| 去重 | 通知指纹 + 同渠道15秒/跨渠道180秒窗口 | 保存交易时处理 | 精确事件；跨渠道相同金额只标疑似，不自动吞单 |
| 误报/异常 | 推广过滤、strong signal、confidence | 解析缺金额后提示补录 | 版本化规则，推广/OTP/聊天拒绝；金额截断不猜 |
| 隐私 | 本机 Room，监听可启动常驻服务 | 调试 Log 输出通知各字段及全文 | 原文不落盘、不打印、不上传；本机私有 SQLite，仅结构化字段 |
| 测试 | DedupHelperTest 覆盖时间、渠道提示、配对及商户 | 未运行其测试，不声称覆盖质量 | 自有 fixture、SQLite、权限、HTTP 幂等回归 |
| 接入成本 | Room/Compose/协程/保活耦合 | 自有数据库/UI/通知纠错耦合 | 独立原生模块 + MethodChannel + Flutter；不整合 App |

可移植清单：成功证据优先、推广拒绝、保守金额、通知事件指纹、双通道关联提示、人工纠错体验。需改写清单：Double 金额、退款分类、金额时间窗口自动合并、账户作用域、事务回执、持久队列、权限与后台恢复。拒绝：短信、自动更新、悬浮确认、watchdog、支付/无障碍操作、Room/Compose/Activity。没有实质源码复制，因此无新增第三方许可资产；后续若复制须先补 THIRD_PARTY_NOTICES.md 及原 MIT 文本。

Android 授权依据：[NotificationListenerService 官方合同](https://developer.android.com/reference/android/service/notification/NotificationListenerService)：使用专用绑定服务和系统通知读取授权，不能以 POST_NOTIFICATIONS 替代；监听不承诺 ROM 完整通知或实时到达。
