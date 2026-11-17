# 61：第一轮安全 Markdown 展示

上游：后端 cc-tasks/PresenceKit_Round1_P0-P1_and_Features.md，F2。

- [x] 助手正文支持约定 Markdown 子集，保留旧内联样式与逐字显示。
- [x] 代码块、表格、列表在 live/poll/history 分段时保持完整（含缩进代码）。
- [x] 禁止远程图片自动加载、危险链接与 HTML 执行；复制与原文不改写。
- [x] 98项相关 widget/发送/历史回归通过；7项 Markdown/链接/日夜大字复验通过。
- [x] Android dev debug APK 构建通过（Java21），未安装或发布正式包。
- [x] Flutter analyze --no-pub 零问题；Dream 14项回归通过。
- [ ] 检查深浅主题、窄屏/大字与真实设备；未完成项保持 not verified。

范围：展示层，无新后端数据、权限或运营配置。Dream 复用 AnimatedRevealText，需回归。

视觉证据：build/review/round1-markdown-light.png 与 dark.png。
离屏图使用实际字体；深色引用块已改为主题底色与强调竖线，宽表独立横滚。
构建产物：build/app/outputs/flutter-apk/app-dev-debug.apk。
