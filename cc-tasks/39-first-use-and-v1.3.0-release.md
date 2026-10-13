# 工单 39：首次使用说明与 v1.3.0

- [x] 首次 Token 弹窗说明手机须配合服务器或电脑上的后端使用，并填写后端签发的 mobile Token；中英本地化同步。
- [x] 生成本地化，复用相关测试与 analyze 验证；纯文案无跨端影响。
- [x] 忽略 mobile-design-reference 与 .tmp，停止跟踪参考 HTML，保留本地文件。
- [x] 独立提交首次使用改动。
- [x] 版本更新为 1.3.0，versionCode 57；ca8e5aa 已推送，Flutter CI 38398576729 与 Android 仪器测试 38398576691 均 success。
- [x] 复用既有 keystore，校验证书与历史 APK 一致，构建正式 APK 与 SHA256，发布并互链。prod release 构建成功，apksigner verify 与 aapt 核对通过；v1.3.0 两项资产已公开。

真实手机首次使用及覆盖升级 not-run，不以构建代替。三仓总工单见后端 cc-tasks/290-v1.3.0-release.md。

验证：flutter gen-l10n 成功；flutter analyze --no-pub 零问题；localization_contract_test 与 widget_test 共 11 passed。参考目录仅移出索引，保留本地。

APK SHA256：a7924c922f17a455383df1a6ca44c0840d32d847de83a9cefbdad7cf6e0597f8。
签名证书 SHA256：1869b348d9e26f13d8213ff60933bcf933fe6e8779d13198f655a4d7c0791fae，与公开 v1.1.0 相同。使用现有 key.properties 指向的历史密钥，未生成新 key 或回退签名。
打包脚本要求输入 build 大于 pubspec 当前 build，版本预先提交后无法输入同一 build；本轮按后端 release-guide 的直接 flutter build prod release 入口构建并手动完成相同证书/版本/hash 验证。
