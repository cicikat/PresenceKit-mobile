# 62：手机环境事实参与 Autonomy

- [x] 独立于采集/Usage Access 的后端授权开关和三项来源设置，默认关闭。
- [x] 设置页可编辑，能力页只读；显示后端实际 effective，保持角色/会话隔离。
- [x] 进入后台尽力清除短期事实，离线由120秒TTL兜底，不新开后台采样或定时器。
- [x] 控制器/widget4项及既有权限/生命周期14项通过；analyze零问题。
- [x] Android锁屏回归失败先行（ComparisonFailure），修复后 AmbientSensorsTest 2项通过。
- [x] 最终18项Flutter回归通过、analyze零问题；dev debug APK构建成功（Java21）。
- [ ] 真机、正式APK、实际模型/生产端到端验收。当前状态 partially verified。

后端唯一权威：sensor/ambient/policy 与 observability/phone-ambient。
既有30秒前台上传与120秒TTL不变，不上传应用名或推断人体状态。
