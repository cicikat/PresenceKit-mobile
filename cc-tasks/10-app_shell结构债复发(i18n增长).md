# Brief 10 · app_shell.dart 结构债复发（i18n 改造推高行数）

> 背景：`test/app_shell_structure_test.dart` 的行数 ratchet（≤1499）当前是唯一
> 失败的测试——`lib/pages/app_shell.dart` 现为 1539 行，超预算 ~40 行。
> 工单 07（`app_shell` 结构债审计与拆分）此前已完成一轮下沉（连接/聊天/设备/
> Dream/Garden/Diary 状态迁去 `controllers/`），本单是同一条债务的复发，不是
> 新债务类型。发现于群聊梦境（Brief 38/100 mobile 追加）收尾时顺带跑
> `flutter test` 发现，跟群梦改动本身无关，未一并处理，故单独立项。

## 背景数据

- 三个最近的 i18n 系列 commit 净新增约 60 行到 `app_shell.dart`：
  - `6564b50 feat(i18n): add locale foundation and language setting`（+14）
  - `4aa8a85 feat(i18n): localize dialogs and upload feedback`（+118 / -73，
    净 +45，是主要来源）
  - `ab708bf feat(i18n): localize dynamic status labels`（净 0）
- `AGENTS.md`/`ARCHITECTURE.md` 明确写着 `app_shell.dart` 只应保留组合根/
  路由/生命周期协调，"禁止继续增加领域状态"。

## 跟工单 07 的差异（重要，决定修法）

工单 07 那轮下沉的是**领域状态**（业务字段 + Timer + 成组业务方法）。这次
超标的来源不同：`4aa8a85` 把内联中文字符串换成 `context.l10n.xxxMethod(...)`
调用，多参数调用被 `dart format` 拆成多行，是**格式膨胀**，不是新业务逻辑。
所以直接照搬"抽到 controllers/"的思路可能文不对题——这批改动本来就该待在
UI 层（弹窗文案、上传反馈文案），下沉到 controller 只是把字符串搬了个地方，
不解决"该不该算作 app_shell 行数"这个问题。

## 建议排查方向（未验证，需要动手前先确认）

1. 看 `4aa8a85` 具体改了哪些方法——是否有单个方法（比如某个弹窗 builder）
   本来就偏长、又被 i18n 调用进一步拉长，适合整体拆成独立 widget 文件
   （类似 `widgets/settings_editor_widgets.dart` 那种已有的拆分模式），
   而不是拆进 controller。
2. 如果确认这批改动本质是"文案外置带来的格式膨胀"而非领域状态，跟维护者
   确认是否该把 ratchet 数字本身也纳入"i18n 迁移期间的已知成本"，而不是
   一味要求下沉。
3. 若决定要拆，优先挑组合根职责最弱的部分（比如纯文案态的弹窗构建方法），
   参照工单 07 的下沉模式，构造注入到 `_CompanionAppState`。

## 验收

- `flutter test test/app_shell_structure_test.dart` 转绿（行数 ≤ 当次约定的
  ratchet，无论是靠拆分还是靠有意识调整预算线）。
- `flutter analyze` 保持零告警；`AGENTS.md`/`ARCHITECTURE.md` 里的结构描述
  与实际代码一致，若拆分改变了文件职责边界要同步更新文档。
