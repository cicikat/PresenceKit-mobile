# 36 — 微信单聊 CSS 数据校准

来源：doubleZ0108/Wechat-Chat-Interface，commit ab5e62c084b25f947388f884334f4afe07691f54。只读取 index.html/style.css，不复制项目或 JS、资源、消息逻辑。
- [x] 提取原始值、有效 light/dark 覆盖和换算规则，记录截图补齐项。
- [x] 以聊天视口308 CSS px为基准映射 Flutter：头像、间距、正文、气泡宽度/圆角/尖角/内边距与日夜颜色。
- [x] 顶栏/时间外观按来源落地，缺失的底部输入与引用沿真实截图；10分钟逻辑与消息链不变。
- [x] 静态分析、相关回归、深浅渲染图和 dev debug APK。
- [ ] 真机字体/键盘/系统安全区：无设备时 not-run。

无跨端影响，无设置字段、接口、持久化或后端改动。

源码值与换算见 docs/mobile/messenger-visual-reference.md；应用位置为 conversation_presentation.dart、chat_widgets.dart、chat_scene.dart。31项相关Flutter回归通过，最终3个文件静态分析零问题；390px深浅渲染图目检通过。真机延续无设备not-run。

最新dev debug APK构建成功，未安装/未发布。
