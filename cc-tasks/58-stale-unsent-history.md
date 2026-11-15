# 58 升级后未发送历史残留排查

日期：2026-11-15。范围：手机聊天恢复；后端仅只读取证，不修改业务数据，不自动重放旧消息。

- [x] 核对安装包、旧消息来源与关联键，复现上次清理遗漏。验收：安装 metadata、历史只读统计、控制器回归红灯。
- [x] 修复已证实的恢复遗漏，保留正常历史、迟到回复与相同正文的新消息。验收：刷新、重建、分页及原发送回归。
- [x] 完成三面检查、分析与测试。验收：build/mobile58-full.log 全量458项通过；build/mobile58-analyze.log 零问题。提交与push见后续交付。
- [x] build82 同签名正式包构建、覆盖安装与重启首屏核对。证据见下。
- [ ] 对8条旧记录逐条翻页比对，以及弱网/前后台/OEM完整矩阵（not-run）；不能用首屏观察替代。

已核对手机正式包 build81，来源提交6f0cb40，与上次修复一致；手机锁屏，正式包不可run-as，尚未读取私有队列。未删除任何用户数据。
取证：线上11月15日233条中有8条user-only，均无request_id/turn_id/user_ts，且保留writer footer；11月14日245条中无此类记录。仅输出数量和字段存在性，未改线上数据。build/mobile58-red.log两个58回归均失败：旧草稿作为普通消息返回；恢复unknown留在sent尾部。

修复证据：ChatLogEntry.fromJson保留旧writer-only块证据，ChatController历史投影跳过无身份、无回复、无媒体/工具的旧块；不按正文相似度删除，不改历史正文或服务端数据。reconcileChatHistory将有持久创建时间的unknown旧消息放回历史相应位置，保留unknown与request_id。两个58用例修复前失败、修复后通过；相关发送/期限/菜单/历史106项通过。

三面闭环：后端管理面仍拥有执行真值，无新增设置、默认值、权限、观测端点、落盘字段或schema；桌面不消费手机私有恢复排序，无需同步设置。输入→原子outbox→会话鉴权→chat/upload→HTTP/WS/poll/history的request_id、载荷、去重、TTL、ACK、后台通知不变。仅手机历史视图兼容旧块；unknown不会被当作明确失败或自动重发，迟到回复仍沿原身份对账。正常未回复且无writer尾注的历史、带结构化身份/媒体/工具的条目保持原行为。真机升级、前后台与线上实际气泡尚未验收。

交付证据：实现1c4d106；PR14 CI Flutter通过（2m5s），已合并11106306d6a27bb4a10c6ad93d6bdefeadeaab47。全量458项通过，分析零问题。第二次只读历史查询236条，原8条均精确匹配本次过滤规则（不输出正文、不删除线上记录）。

正式包：dist/release/PresenceKit-mobile-v1.3.0-build82.apk；pubspec与aapt、手机dumpsys及侧栏均为1.3.0+82；已拉取手机build81并核对两包certificate SHA-256均为1869b348d9e26f13d8213ff60933bcf933fe6e8779d13198f655a4d7c0791fae。adb install -r成功，原头像/布局/连接与真实最新对话保留；强停重启后主页面仍以16:38正常回复结尾，未见旧失败消息追加到末尾。截图/metadata在build/mobile58-{before,after,restart,drawer82}本地文件中，不提交私人聊天。未发送测试消息、未改服务端数据，未对外发布。

构建入口说明：既有build_release.ps1拒绝versionCode等于已更新pubspec（82），因此未修改脚本或回退版本；使用flutter build apk --release --flavor prod --no-pub，并独立完成apksigner、aapt、历史安装包签名比对及安装。产物hash与build-info在dist/release保存。
