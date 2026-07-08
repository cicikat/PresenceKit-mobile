# Round · 移动端硬编码「叶瑄/yexuan」去除

> 配对：`Emerald-presence/cc-tasks/25-硬编码去除-梦境流动接入-字段更名.md`（总方案，统一原则见其 §1/§3）。
> 原则：展示名一律走已有的 `_profileDisplayName` 动态机制，代码里不留字面角色名。

## 1. 现状

`lib/` 内约 27 处 `叶瑄`/`yexuan`。已有正确先例：`app_shell.dart` 的 `_profileDisplayName` 支持用户改名——但默认值与各兜底仍是字面 `'叶瑄'`，且多个 widget 各自写死。

## 2. 改动

1. **统一显示名来源**：新建 `lib/services/character_naming.dart`（或并入现有 settings store）：`characterDisplayName` 单一真值，默认取后端（`GET /prompt-assets` 的 active character name，backend_client 已有请求设施）或本地设置，兜底 `'TA'`。
2. 替换字面量（grep `叶瑄` 全清）：
   - `main.dart:55` App 标题 → 中性名（如「陪伴」，用户可后续拍板产品名）；
   - `app_shell.dart` 默认值/回填/snackbar 文案（73/145/489/499/648/687）；
   - `chat_widgets.dart:447,538` 默认参数；
   - `diary_widgets.dart:64`、`drawer_widgets.dart:115`（「{name}的日记」插值）；
   - `capability_widgets.dart:1008-1011` 系统设置引导文案里的 App 名 → 用应用实际显示名变量；
   - `profile_widgets.dart`、`settings_*_widgets.dart`、`garden_widgets.dart` 逐处同理。
3. **标识符类（低风险改法）**：`backend_client.dart:334` boundary 字符串、`:422` `title_hint: 'yexuan_app'`、`app_settings_store.dart:9` MethodChannel 名——改为中性 `presence_mobile` 一类；其中 **MethodChannel 改名须同步 Android 侧原生代码**，若本轮不便动原生，标注 TODO 并保持现值（写入白名单）。
4. **明确不做**：包名 `com.example.yexuan_memery`（`app_shell.dart:538` 的判断随包名走）、仓库名——需重装/迁移，用户单独拍板。

## 3. 验收

- `$env:NO_PROXY = "localhost,127.0.0.1,::1"; flutter test` 通过。
- grep `叶瑄` 结果为 0；`yexuan` 仅剩包名相关白名单处。
- 改角色卡后 App 内标题、日记、聊天页显示新名字。
