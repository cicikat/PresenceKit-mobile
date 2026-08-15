# Android release 签名与升级权威说明

## 必需 identity

每个 public release 都必须使用同一个固定、非 debug 的 release keystore。keystore、密码、`android/key.properties` 和 CI secret value 必须留在版本控制之外。如果四个签名字段中的任何一个，或被引用的 keystore 缺失，release build 必须在打包前失败。永远不要用同一 source 但新生成的 key 重签来替代历史 public APK。

发布前记录 APK 文件名、SHA-256、version name/code、certificate SHA-256、certificate subject，以及 `apksigner verify --print-certs` 结果。记录中不得包含私钥材料或密码。

## 正式 release 入口

`AA1` 只创建已验证的正式 release artifact。`AA3` 使用同一 release build、签名、metadata 和 signer validation，然后在恰好一台授权 Android 设备上使用 `adb install -r` 安装已验证 APK。验证完成前它不会安装 APK。

运行 `AA1打包发行包.bat`，按提示提供两个值：

- `versionName` 是展示给用户的版本，例如 `1.0.0` 或 `1.0.0-rc.1`。
- `versionCode` 是 Android 用于比较升级的值，必须是正整数，并且每个后续 Android release 都必须递增。
- 当 package name 和 signing identity 兼容时，`1.0.0 / build 2` 这样的 release 可以升级 `0.2.2 / build 1`。

脚本会在开始前确认请求版本、当前 Git commit 以及 `prod release` build type。它运行 `flutter pub get`，然后运行 `flutter build apk --release --flavor prod --build-name <versionName> --build-number <versionCode>`；不会修改 `pubspec.yaml`。它还会拒绝缺失/不完整的签名配置、debug-signing fallback、重复使用的 artifact 名称、APK metadata 不匹配，以及不是永久 PresenceKit-mobile identity 的 certificate：

`18:69:B3:48:D9:E2:6F:13:D8:21:3F:F6:09:33:BC:F9:33:FE:6E:87:79:D1:31:98:F6:55:A4:D7:C0:79:1F:AE`

最终 APK、`.apk.sha256` 和 `.build-info.txt` 写入 `dist/release`。keystore 只用于签名，不会复制到该目录。GitHub 发布仍是后续手动步骤；脚本不会 stage、commit、tag 或 publish 任何内容。

## 升级 gate

必须先在测试设备上安装真实 public APK。只有在它的 signer certificate digest 与 candidate digest 相同后，才能用 `adb install -r` 测试 candidate。升级步骤必须保留 app data，并验证 backend URL、owner ID、普通设置、admin token、relay token、secure-storage migration、token 替换/删除、两次重启和第二次同签名覆盖安装。全新安装是独立步骤。自动迁移测试和模拟的同签名测试都不能替代真实 public-APK 测试。

## 2026-07-29 审计结果

public v0.2.2 APK 已验证，并使用 `C=US, O=Android, CN=Android Debug` 签名，certificate SHA-256 为 `1869b348d9e26f13d8213ff60933bcf933fe6e8779d13198f655a4d7c0791fae`。配置的 v1 release keystore 和当前 `a351d08` formal candidate 不可用，因此不能声称 lineage-compatible upgrade。没有运行设备升级测试。

如果恢复历史私钥，方案 1 是永久使用该 identity，并重新执行完整真机矩阵。如果无法恢复，Android 不能把历史 APK 原地升级为不同 identity 签名的 package。方案 2 是 transition release，并提供明确的重新安装路径：导出 backend URL、owner ID、普通设置以及经用户批准的 token re-entry/import；确认导出后再卸载旧 app；安装新 identity；恢复设置并输入新 token；然后在新安装上验证聊天、relay 和 token migration。项目必须在宣布 v1 readiness 前选择其中一个方案。
