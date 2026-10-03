# 25 — 分类提交并推送现有改动

日期：2026-10-03。范围：仅 `Emerald-mobile` 当前工作树已有改动；不修改后端或桌面仓库。

- [x] 盘点分支、远端和未提交文件；验收：`git status --short --branch`，`main` 超前 `origin/main` 7 个提交。
- [x] 按功能分类并验证；验收：改动归入 24/A 手机电量/充电状态采集与上报，已补本仓协议、Android 能力文档和定向测试适配。
- [ ] 独立提交本组改动；验收：commit SHA 和 `git show --stat`。
- [ ] 推送当前 `main` 到 `origin/main`；验收：`origin/main..HEAD` 为空。
