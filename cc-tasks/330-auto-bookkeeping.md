# 330 自动记账施工记录

- [x] A 固定版本克隆与许可审计：见 docs/mobile/auto-bookkeeping-open-source-review.md。
- [ ] B 独立 Android 监听、整数金额、SQLite 队列、后台恢复；运行原生回归。
- [ ] C 用户账本 API、权限、事务幂等、版本、观测、控制面与备份；运行 HTTP 回归。
- [ ] D Flutter 入口、授权状态、确认/纠错/忽略、流水与同步；分析、widget/controller 测试、Dev APK。
- [ ] Android 14 真实支付通知、授权往返、断网/杀进程/重启：NOT RUN，自动化不能替代。

不修改聊天/生活记录 wire，不搬移库存表，不部署生产或正式发行。按 A/B/C/D 独立提交。
