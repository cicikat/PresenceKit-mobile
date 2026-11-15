# 53 手机发送失败感叹号

- [x] 定位发送链与现有回归：YouMessage 当前失败文字优先打开详情；ChatController.retryMessage 复用 Outbox 请求及载荷。
- [x] 在失败用户消息旁增加红色感叹号，点击调用既有重试；保留投递详情入口。实现：lib/widgets/chat_widgets.dart 的 YouMessage，48px 点击区域与双语 tooltip。
- [x] 补充控件回归：chat_interaction_regression_test 的 failed message icon 测试验证失败图标、48px 点击区、直接重试及详情分流、成功/未知无图标；chat_theme_quote_test 各布局点击；chat_recovery_upload_test 重复调用重试不增加请求，复用附件/引用载荷回归。
- [x] 本地化生成、定向测试、静态分析：flutter gen-l10n 成功；四文件定向 65 项通过；flutter analyze --no-pub 零问题。
- [x] 差异检查：普通与忽略行尾 diff 统计一致；换行按手机仓库 CRLF 核对，最终 git diff --check 验证。

验收边界：本机控件与隔离控制器测试；真机触摸及真实网络发送未执行，不以自动测试代替。
三面闭环：仅手机 UI 入口，无跨端影响；复用现有 Outbox 状态、鉴权、scope、request_id、载荷和重试规则，无新增设置、持久状态或 wire 字段。未知结果仍走补读，不由此入口重新执行。
