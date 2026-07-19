# Flutter 本地化

## 支持范围

Flutter 前端支持“跟随系统”“简体中文”“English”三种选择。设置入口位于设置页第一行，始终排在访问 Token 之前；切换后根 `MaterialApp` 立即重建，无需重启应用。

本地化覆盖客户端自带的导航、页面、弹窗、状态、表单、诊断和测试提示。后端返回内容、用户输入、角色文本、协议字段、文件名和主题/角色等用户自定义名称保持原文，不做源文本替换。

## 代码与持久化

- `lib/l10n/app_zh.arb`、`lib/l10n/app_en.arb`：语义化文案键的唯一来源；两份 catalog 必须保持相同消息键。
- `lib/l10n/generated/`：`flutter gen-l10n` 的检入产物。
- `lib/l10n/l10n.dart`：`BuildContext.l10n` 与枚举/稳定协议值到展示文案的映射。
- `lib/controllers/locale_controller.dart`：当前语言、即时通知和持久化协调。
- `lib/services/language_preference_store.dart`：Android MethodChannel 与 Web localStorage 的语言偏好存储。
- Android 使用 `presence_mobile/settings` 通道的 `getAppLanguage` / `setAppLanguage`，在 legacy `SharedPreferences("yexuan_memery")` 中保存 `appLanguage`。允许值只有 `system`、`zh-CN`、`en-US`。

## 新增文案

1. 在中英文 ARB 中添加同名、能表达业务含义的 key；禁止用中文原文或组件位置作 key。
2. 占位符的名称和类型在两份 ARB 中保持一致。
3. 在 Widget 中通过 `context.l10n` 读取；模型中的稳定枚举值通过 `lib/l10n/l10n.dart` 映射，不修改后端协议值。
4. 执行 `flutter gen-l10n`、`flutter analyze` 和 `flutter test test/localization_contract_test.dart test/locale_controller_test.dart test/widget_test.dart`。

`test/localization_contract_test.dart` 会阻止中英文 key 集合漂移和空翻译；`LocaleController` 测试覆盖 `中文 → English → 中文` 的即时切换与持久化往返。
