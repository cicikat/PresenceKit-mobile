# 28 · 手机视觉方向 HTML 参考

范围：根目录 mobile-design-reference/，四套独立视觉方向与对比入口。仅演示数据，不接入 Flutter/Android/后端，无跨端影响。

- [x] 01 搜索官方设计参考，记录来源与原创转译方向。证据：mobile-design-reference/README.md:14，已读取 Headspace / Day One / Calm 官方页面并检索 Owaves。
- [x] 02 制作四套手机 HTML 与统一对比页。证据：mobile-design-reference/index.html:1、app.js:1、styles.css:1；四套入口、五种页面、纯内存模拟发送已编写，node --check 通过；浏览器验收见 03。
- [x] 02b 按用户澄清重做信息架构：A 顶部分栏书信阅读、B 抽屉导航聊天工具、C 全屏场景与浮动导航、D 卡片首页与独立聊天入口。证据：app.js:34 的四套不同首屏、setupLayout 导航结构、styles.css 布局段；overview.jpg 可见差异。
- [x] 03 检查桌面与窄屏呈现、脚本语法、相对资源引用。证据：1600px 对比页、338px iframe 无横向溢出；四套导航/模拟发送/设置切换通过，D 首页返回保留消息；node --check 通过；overview.jpg。离线 file 协议受工具限制 not-run；Flutter/真机 not-run。
- [x] 04 检查 CRLF 与修改范围，独立提交。证据：文本 CRLF 扫描通过；暂存 diff --check 通过，两种 stat 一致；本提交仅本工单与参考目录，原有 .tmp/ 未纳入。

依赖：01 → 02 → 03 → 04；不开展正式前端接入，选型由用户决定。
