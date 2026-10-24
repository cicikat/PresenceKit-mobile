# 42 手机消息可靠收件施工（R0/R1）

日期：2026-10-24；依据工单41。用户已授权手机与后端联动施工。目标：代理/网络变化不能永久占住收件任务，前台连续补收，ACK真实落盘后才确认，前后台消息可重放。

范围：兼容现有mobile HTTP、身份/seq/TTL/用户权限；桌面只读。第一施工阶段R0/R1；R2独立mobile WS在可靠补收验收后实施，R3多手机游标不纳入本单。不得复用desktop WS，不强制绕VPN，不自动重跑未知结果。

- [x] R0a：先补CONNECT不响应/打开请求/正文卡住/取消的失败测试；所有BackendClient网络路径使用总期限，连接阶段有独立上限，超时真实关闭资源。
- [x] R0b：前台接收任务可取消，暂停/恢复/身份和网络变化使旧轮次失效；Android网络回调经独立轻量服务通知ChatController，不给AppShell增加领域状态。
- [x] R1a：将固定5秒tick改为连续有界长轮询，收到即补下一页、异常退避；历史加载不挡首次收件；保留发送/历史/poll对账与取消代际。
- [x] R1b：后端ACK先写盘成功后返回；注入False/异常/恢复验证；mobile持久镜像不再等其他网络通道完成。
- [x] R1c：本机pending改成非删除读取+按scope/身份确认，前台先持久完整信封再后端ACK；保留artifacts/sticker/behavior，提供既有状态入口只读数量/容量。
- [x] R1d：后台signal回源失败保留补收意图并有界退避重试，网络恢复即重连/补拉；不改变授权与通知闸门。
- [ ] R1e：同步三面文档/ABI与跨仓总账、更新known-issues；Flutter/Android/后端相关回归和分析、Dev APK构建，独立提交各修复。
- [ ] 现场验收（not-run直到真机证据）：V2Ray开/关/切节点、Wi-Fi/流量切换、前后台/杀进程/Doze、真实模型；安装/服务器部署版本核对，首条/整条到达p50/p95。

验收证据逐项补入；静态/单测/Dev构建不等于真机。新落盘状态/观测同单提供；服务端业务真值与token权限不变。先后关系：R0a→R0b→R1a；后端R1b可独立；R1c→R1d→R1e；R2依赖上述可靠补收。
R0a证据：test/backend_transport_recovery_test.dart真实CONNECT黑洞/正文卡住先2失败；修复后含取消不误伤发送共3项通过，HTTP相关合计36 passed。资源关闭有代理端EOF验证。审计临时脚本改存build/review/mobile-delivery-audit/audit_transport_probe_test.dart.txt，避免被analyzer当生产代码扫描。
R1b证据：后端19176cc；ACK False/exception/恢复与慢通道镜像测试先失败后52 passed。

R0b/R1a证据：mobile_receive_loop_test三项（旧poll迟到不能清新状态、历史阻塞仍排空两页、暂停后不ACK）；含现有前台/恢复/协调器共48 passed。MobileNetworkObserverTest验证合并/取消注册，Gradle BUILD SUCCESSFUL。请求预算提交1ae32a9。

R1c/R1d证据：Flutter全量393 passed / analyze 0 issues（日志build/review/mobile-delivery-audit/flutter-final.log与analyze-final.log）；Android MobileDeliveryStateStoreTest14、SettingsChannelDeliveryTest5、MobileNotificationDeliveryTest1、MobileNetworkObserverTest1、MobilePullRecoveryTest3，共24 passed。覆盖stash失败不ACK、旧代peek可重放、精确scope/id/seq确认、完整元数据、失败后不依赖新signal即可补收、退避上限、终止auth失败与signal合并。已有轮询节拍/历史串行的3个旧测试按新合同更新后全量通过。

网络恢复收尾：新增带宽估值/重复LinkProperties噪声测试先断言失败（expected1/actual2）；MobileNetworkObserver仅在网络归属、可达性、传输类型、DNS/路由/代理/MTU变化时重连，忽略纯带宽/信号变化，避免健康收件被频繁取消。Android观察器2项、相关合计25 passed；Flutter最终393 passed/分析零问题保持有效（Dart未再变更）。
