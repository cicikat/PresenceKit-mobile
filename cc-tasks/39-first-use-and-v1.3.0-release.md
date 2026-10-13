# 工单 39：首次使用说明与 v1.3.0

- [x] 首次 Token 弹窗说明手机须配合服务器或电脑上的后端使用，并填写后端签发的 mobile Token；中英本地化同步。
- [x] 生成本地化，复用相关测试与 analyze 验证；纯文案无跨端影响。
- [x] 忽略 mobile-design-reference 与 .tmp，停止跟踪参考 HTML，保留本地文件。
- [x] 独立提交首次使用改动。
- [ ] 版本更新为 1.3.0，versionCode 57；推送并核对 CI。
- [ ] 复用既有 keystore，校验证书与历史 APK 一致，构建正式 APK 与 SHA256，发布并互链。

真实手机首次使用及覆盖升级 not-run，不以构建代替。三仓总工单见后端 cc-tasks/290-v1.3.0-release.md。

验证：flutter gen-l10n 成功；flutter analyze --no-pub 零问题；localization_contract_test 与 widget_test 共 11 passed。参考目录仅移出索引，保留本地。
