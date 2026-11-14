# 手机 #51：顶栏与组件回归修正

2026-11-14，基于 `2fe2cab`。纯 UI 与组件复用，无跨端影响。

## 问题与修正

#50 在聊天 Stack 右上角新增独立圆角状态按钮，和原顶栏静态“在场/手机端在线”重复。现在删除浮块及顶栏状态文字，五种聊天布局共用 `ChatConnectionAvatar`，内部复用 `YxAvatar`；头像右下角内收一个无动画红绿点，点击头像进入原 `ChatDeliveryDetails`。失败气泡的安全恢复入口仍可用。

圆点直接读取既有 `mobileActive && mobileError == null`：绿色表示 mobile channel 已激活且当前没有收件错误，否则红色。它不表示模型正在生成，也不是独立的实时网络探针；断线反馈仍受原收件错误检测时间影响。待发数量、历史读取失败与 outbox 错误可在详情查看。主页面不显示内部诊断。

#49 的感知权限使用默认 `ListTile`/`SwitchListTile`，与周围组件不一致。现在只读观察复用 `CapabilityRow`，编辑复用 `SettingsRow`；屏幕读取失败、设置感知入口、FCM 和兼容通知开关也沿用现有组件。保留未知/失败/不支持、重试、授权、撤销、返回刷新及读取代际逻辑。普通手机宽度下状态行紧凑排列，仅窄屏或大字且存在操作控件时分层。

`EdgeRefresh` 接收当前 `YxPalette`，文字取 `ink2`，箭头和进度取 `character`。上下沿手势与触发阈值沿用原逻辑。

## 截图证据

- [修改前组件总览：10 张](ui-51/before.png)
- [修改后组件总览：22 张](ui-51/after.png)

以上为真实 Flutter widget 离屏渲染，使用合成聊天、模拟系统通道与 Windows 测试字体，不是真机截图。聊天与权限组件分别覆盖日夜；五种顶栏覆盖 320px、1.8 倍字号、长名字及连接切换。权限截图是组件对齐 fixture：下方额外的“自动播放语音”设置行用于比较排版，不代表能力观察页有编辑开关。能力观察页是否只读由原页面分支与权限测试验收。

原始 PNG 在本机 `build/review/ui-51/before/` 和 `after/`。已逐格检查总览，并检查聊天、设置、权限、书信大字与刷新原图；头像点无位移，长标题省略，无布局异常。原始图不入库，总览随本报告保存。

修改后截图可按下列命令重新导出（Windows 已安装微软雅黑）：

```powershell
flutter test --no-pub --dart-define=UI_51_CAPTURE=true test/ui_regression_51_test.dart --reporter expanded
```

修改前截图是在改动前保存的证据，不使用当前实现重新生成。

## 验证与边界

- `flutter analyze --no-pub`：零问题。
- `flutter test --no-pub --reporter expanded`：全量 425 项通过；涵盖聊天顺序/历史与工具活动、失败恢复、滚动锚点、权限重试和原投递契约。
- UI/权限/结构定向 14 项通过；新增 UI 用例 9 项，含五种顶栏、头像详情点击、圆点内接几何和日夜刷新颜色。
- `flutter build apk --debug --flavor dev --no-pub`：成功，Gradle 24.9 秒。
- APK：`build/app/outputs/flutter-apk/app-dev-debug.apk`，SHA-256 `D1F1C842E6C7F1FE794A5F241D2343678786C6E497A0503214DB521D87FAA012`。

无连接设备：真机视觉、触摸、权限往返、ROM 通知、切网、安装升级均 **NOT RUN**。未安装、未正式发布。#49 统一 effective/最近上报观测、#50 scoped running 查询仍按原报告保留 open。

仅调整 Flutter 展示与组件组合，未新增设置项、持久状态、接口或跨端行为；管理面、桌面、Android 原生无需同步。沿用原输入 → controller → 后端/mobile channel → UI/通知链，鉴权、关联键、去重、ACK、TTL 与 fallback 没有变更；AppShell 只传入既有状态和回调，无新增领域状态。复用中英本地化，无新增可见文案 key。
