
```markdown
# 16 · 设置页按用户心智重排，关掉的开关不要假装还在生效

## 给执行者

前置：13、14、15 已合入（默认                                   infoStrip、背景预 置页）。
用中文。小步 commit。双 ARB + `flutter gen-l10n`。              禁止发明后端新接  抄 desktop-jsx。
`proactiveRate` 在整个 lib/android **没有消费者**（仅 YxPrefs + 设置 UI）。夜深静`MobileNotificationService`（原生把 23:30–06:30 **写死**）。不要 控制他。

## 目标

打开设置的人能分 是连接。开关要么真生效，要么标明「尚未接通」或先从 UI 拿掉。

## 现状

`lib/widgets/settings_widgets.dart`「外观」段（约 L255–451）顺序是
                                              1. 资料（头像/名
2. 主题：纸色/夜里 chip + **日间**预设按钮    3. 聊天背景
4. 又一行「夜里」预设                         5. 对话信息栏
6. 正文字号（只改气泡，Composer 写死 15px，见 `chat_widgets.dar
7. 显示我的头像
8. **主动消息频率内存`_prefs`，`updatePrefs`（`app_shell.dart` 约               L941）不持久化、
9. **夜深时段静音** —— 文案承诺                            23:30–06:30，原生
                                                           `YxPrefs` 的infoStrip/fontSize/showYouAvatar/proactiveRate/nightSilent 目前基本只活在内 arance`。重启后信息栏/字号很可能回到默认。本单要修「用户以为改了就算数」。

## 要做

### A. 分区

保持现有「通用 / 连接与账户 / 通知」在上。其后：

**外观**（只剩看得见的皮肤）

- 主题：一行说清楚。纸色/夜里切换 + 日间预设 + 夜间预设。不要把
「夜里」拆成主题 中间。
- 聊天背景（含 15 若已加的透明度滑杆）
- 正文字号：同时  若没改Composer，本单改）。范围可仍 14–20。
- 显示我的头像
- 对话信息栏（13 已改默认和副文案则沿用）

**通知与主动**（从外观挪走）

- 后台通知、通知测试模式（已在通知段则不要重复）
- 夜深静音：见 B
- 主动频率：见 C

资料仍可放外观最上，或单独「他」一段；不要跟频率混。

### B. 夜深静音必须接通或拿掉

原生已有静音时段（`MobileNotificationService.kt`
`quietStartMinute

选一条，不要做假

**推荐：** 加 Met时段」（默认true，与现在行为一致）。Flutter
开关改这个值。`dos.md` 同步。Dart的 `AppSettingsStore` / `PlatformSettingsChannel` /
`MainActivity.kt`）。

不要本单去改 23:3

若你判断加 channe ：把开关从设置 UI **删除**，在 `docs/known-issues.md`
写明「静音时段目 一个点了没反应的Switch。

### C. 主动频率

没有后端字段就不要做 SegmentedButton。

- 在 `docs/known-issues.md` 记一条：设置项曾存在但未接后端调度。
- UI 删除该行。
- 不要为了让按钮动起来去猜 `POST` 一个不存在的 rate API。

三面闭环：查过 `docs/backend/integration.md` /
`docs/protocols/me density字段。不要在 catalog 里把删除 UI 写成「功能完成」。

### D. 持久化真正会被用到的外观 prefs

`infoStrip` / `fontSize` / `showYouAvatar`
需要跨进程活下来 ttings`已有读写模式（看 `AppSettingsStore` 里其它 bool/double
怎么存），不要新

`updatePrefs` 现store。重启后字号/信息栏/自己头像开关应还在。

聊天背景已有独立 appearance 存储，不要重复造。

### E. 不要做

- 不要重做主题编辑器。
- 不要把 lorebook
- 不要在本单改聊天气泡布局（那是 13/14）。

## 代码落点

| 文件 | 动作 |
|---|---|
| `lib/widgets/settings_widgets.dart` |
重排；删除假频率
| `lib/pages/app_shell.dart` | updatePrefs 持久化；字号传到
Composer（若 Comp
| `lib/widgets/chat_widgets.dart` | Composer 字号跟随
prefs（小改） |
| `lib/services/app_settings_store.dart`
`platform_setting.kt` |仅当接通夜深静音或持久化外观时 |
| `docs/android/nnel 变更必更 |
| `docs/known-issues.md` | 频率未接后端；若隐藏静音也记 |
| `lib/l10n/app_z 、诚实副文案 |
| `test/method_channel_contract_test.dart` | channel
有增必改合同 |

## 验证

```text
flutter gen-l10n
flutter analyze
flutter test

手工：

1. 外观里看不到主动频率。通知段能解释夜深静音真实行为（或该项已
消失且 known-issu
2. 改字号，回聊天，气泡和输入框都变；杀进程重开仍在。
3. 切信息栏、显示
4. 主题：日/夜预设不再夹在背景两侧。
5. 若接通静音：关称「他不会找你」与开关矛盾（测试模式逻辑保持原样）。

依赖 / 并行

- 前置 13、14、15。
- 不要与前面三张

---