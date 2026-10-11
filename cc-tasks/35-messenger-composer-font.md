# 35 — 微信引用输入栏与字号校准

仅 messenger 呈现，无跨端影响，无接口或存储变更。
- [x] 待发送引用在输入框下方、与输入框同宽，灰底单段文本与圆形关闭按钮。
- [x] 头像透明、无描边；其他布局保持既有头像样式。
- [x] 正文/输入默认从 20px 缩至 16px，引用14px，标题17px，时间12px；集中字号参数并记录设置入口。
- [x] 相关回归、静态分析、深浅渲染目检、dev debug APK。
- [ ] 真机字体/软键盘/触摸（无设备时 not-run）。

已完成项证据：conversation_presentation.dart 集中字号和 MessengerReplyPreview；common_widgets.dart 的头像 transparentFrame；chat_scene.dart / chat_widgets.dart 组装引用预览。layout_interaction_test.dart 验证引用在输入框下方、取消引用不清空草稿。31项相关回归通过；最终5个文件静态分析零问题，深浅渲染图目检通过。真机延续工单34无设备的not-run。

补验：引用栏与输入框左右边缘对齐尺寸回归通过，messenger深浅渲染补验通过。
最新 dev debug APK 构建成功，SHA-256：4EC71C83C2B04150ED4FE950D0C94F814BCD08A046124090D3A20959CCEA2B23。未安装/未发布。
