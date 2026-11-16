# 330 自动记账施工记录

- [x] A 固定版本克隆与许可审计：见 docs/mobile/auto-bookkeeping-open-source-review.md。
- [x] B 独立 Android 监听、整数金额、SQLite 队列、后台恢复：finance/ 独立模块、FinanceTest 5 项通过（API28 Robolectric）；build/finance-native-test.log。
- [x] C 用户账本 API、权限、事务幂等、版本、观测、控制面与备份：后端a0596b2，已随PR24合入main；后续3900549/42b0cd2补联调服务与实际备份验证。后端327项定向、最终85项授权/换行等与10项财务HTTP通过；管理面浏览器实测通过。
- [x] D Flutter生活记录入口、授权状态、确认/纠错/忽略、流水与同步：最终analyze零问题，Flutter全量467项通过，36项原生/真实HTTP及相邻生活记录回归通过；Dev APK构建成功，详情见交付报告。
- [x] 用户后续连接手机并授权安装：同历史签名prod release 1.3.0+87，adb install -r成功，系统版本确认，原有记录保留。详见交付报告；未外部发布。
- [ ] Android 14 真实支付通知、授权往返、断网/杀进程/重启：NOT RUN，通知读取尚未授权，未通过ADB代开权限，自动化不能替代。

不修改聊天/生活记录 wire，不搬移库存表，不部署生产或正式发行。按 A/B/C/D 独立提交。
