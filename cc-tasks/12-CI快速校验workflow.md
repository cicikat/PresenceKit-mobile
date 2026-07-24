# 12 · CI 快速校验 workflow（本仓目前无任何 CI）

## 目标

push/PR 自动跑 analyze + test，不构建 apk、不涉签名（release 流程维持
release-guide 的手动路径不变）。

## 设计

新增 `.github/workflows/ci.yml`：

```yaml
name: ci
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }
jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - run: flutter pub get
      - run: flutter gen-l10n
      - run: flutter analyze
      - run: flutter test
```

要点：

- `flutter gen-l10n` 放在 analyze 之前：CI 干净 checkout 没有生成产物，
  不生成会假红（本仓 l10n 约定见 CLAUDE.md 第 6 条）。
- test/ 目录现有均为纯 Dart 合同/逻辑测试，ubuntu 直接可跑，无需模拟器。
- flutter 版本用 stable channel 起步；若与本机版本漂移导致 analyze 规则不一致，
  再固定具体版本号（`flutter-version:`），先不预设。

## 验收

- 提 PR 触发全绿；故意加一个 analyze 警告级错误验证会红。
- 若 analyze 首跑暴露存量告警，只修阻塞级（error）；warning 存量记入
  known-issues/工单 10（app_shell 结构债）不在本单扩scope。

## 依赖 / 并行

- 独立可做，与 backend 113、client 41 并行。
