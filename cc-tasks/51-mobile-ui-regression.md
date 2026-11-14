# 工单 #51｜顶栏状态与组件对齐回归修正

基于2fe2cab，分支fix/mobile-ui-regression-51。仅视觉与组件复用，无跨端影响；不改投递/权限/连接协议及持久状态。

## 根因

- #50 chat_scene.dart将详情做成Stack右上角圆角18的Material/TextButton.icon，独立于顶栏布局，文字状态与原顶栏重复。
- 经典ChatTopBar仍使用PresenceSnapshot.current静态“在场/手机端在线”文字，不能作为实际连接证据。
- #49 AmbientPermissions默认ListTile/SwitchListTile/裸Text，与CapabilityRow的16px边距、图标、细分隔线和字体不同；设置感知入口及屏幕读取失败也混用默认ListTile。
- CapabilityRow在宽度430以下无条件分为两层，状态块另起一行，造成手机列表节奏松散。
- EdgeRefresh未指定文字/图标/进度色，继承Material默认色，和YxPalette页面主题分离。

## 施工与验收

- [x] A 保存真实Flutter组件修改前离屏截图（聊天、刷新、能力/控制与设置关键区域）。证据：test/ui_regression_51_test.dart，6项通过，build/review/ui-51/before/日夜10张；合成数据，不能当真机截图。
- [x] B 删除悬浮状态文字；所有聊天布局头像右下角一个无动画红/绿点，复用YxAvatar；详情由点击头像进入，失败气泡恢复入口保留。证据：ui_regression_51_test的all headers用例覆盖5布局、320px、1.8倍字、长名、连接切换圆点几何及头像进入详情；foreground_mobile_delivery_contract_test原详情与心情契约通过。app_shell结构用例通过，无新增领域状态。
- [x] C Ambient/屏幕失败/设置入口复用现有CapabilityRow/SettingsRow，能力行手机上紧凑对齐。证据：ambient_permissions_test四项、screen_observation_settings_test原授权/读取期限/重试用例通过；能力页无开关，设置仍允许撤销。Fcm及兼容通知开关同样复用SettingsRow，不改通知逻辑。
- [x] D 刷新文字使用页面ink2、图标/进度使用页面character。证据：ui_regression_51_test日夜刷新进度与颜色断言通过；chat_interaction_regression_test上下沿刷新原用例通过。前后截图见build/review/ui-51/；实际设备未验收。
- [x] E 导出修改后22张截图并逐格检查；定向14项、全量425项通过，analyze零问题，dev APK成功（24.9秒），SHA-256 D1F1C842E6C7F1FE794A5F241D2343678786C6E497A0503214DB521D87FAA012。证据：docs/mobile/ui-regression-51.md、ui-51/before.png与after.png。无设备，真机/权限往返/切网/安装升级NOT RUN。
- [x] F 文档与CRLF/diff检查。证据：docs/mobile/ui-regression-51.md记录组件/调用链/风险；普通与ignore-cr-at-eol统计一致（419增/277删），git diff --check通过，改动文本工作区CRLF。
- [ ] G 独立提交、push并创建PR；记录SHA/URL。main远端尚缺既有5个提交，基础改动与#51分层交付，#51以2fe2cab为基线。

用户提供了真机现象描述，本会话没有可读取的原截图附件；前后对比采用同一Flutter离屏fixture，实际ROM/设备效果仍须真机复核。桌面参考仅视觉原则，不复制桌面实现。
