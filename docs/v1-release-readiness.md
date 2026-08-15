# v1 Android 发布就绪度

> **2026-08-10 reconciliation**：文件曾记录一条 2026-08-02 的后续验收注记，声称正式包与同签名覆盖安装已完成。该结论在当前 checkout 中无法由可复现的候选 APK、keystore 和真机证据支持，因此只能作为历史记录，不能覆盖下方当前审计证据。当前仍以本文件的 2026-07-29 快照及现行 fail-loud 构建约束为准：正式签名候选包和真实设备升级矩阵尚未验证，发布状态保持 blocked。

## 签名 lineage 审计（2026-07-29）

本审计使用 public [v0.2.2 GitHub Release](https://github.com/cicikat/PresenceKit-mobile/releases/tag/v0.2.2) 附带的 APK，而不是从 v0.2.2 source tag 重建的 APK。下载的 asset 是 `app-release.apk`；GitHub asset SHA-256 与下载文件 SHA-256 都是 `60fc680ee19ae336b2760aec9027dbbf57142395a53433774f937b85b5f37b87`。

| 样本 | SHA-256 | versionName / versionCode | signer certificate SHA-256 | subject | `apksigner verify` |
| --- | --- | --- | --- | --- | --- |
| 已发布的 GitHub v0.2.2 `app-release.apk` | `60fc680ee19ae336b2760aec9027dbbf57142395a53433774f937b85b5f37b87` | `0.2.2 / 1` | `1869b348d9e26f13d8213ff60933bcf933fe6e8779d13198f655a4d7c0791fae` | `C=US, O=Android, CN=Android Debug` | passed (v1/v2) |
| 已存在的 `dist/PresenceKit-mobile-v0.2.2.apk` | 与已发布 asset 相同 | `0.2.2 / 1` | 与已发布 asset 相同 | 与已发布 asset 相同 | passed (v1/v2)；历史副本，不是当前 candidate |
| 当前 commit `a351d08` 的正式 release candidate | 未生成 | n/a | n/a | n/a | 未运行 |
| 已配置的 release keystore | 当前 checkout/environment 不可用 | n/a | n/a | n/a | n/a |

现有本地 v0.2.2 APK 与 public asset 字节级相同，并且早于 commit `a351d08`；因此本文有意不把它称为当前 candidate。在允许的本地搜索范围内没有找到 keystore、`android/key.properties` 或历史私有签名 key。历史 certificate 可以从 APK 恢复，但私钥不能恢复。

因此，`apksigner` 只能证明真实 public v0.2.2 APK 使用 debug 签名。它不能证明 v1 有固定的 release identity，也没有当前 `a351d08` 的正式签名 candidate 可供比较。缺少所需 keystore 时 release build 仍会 fail-loud；此前本地 Gradle build 还因为 Gradle distribution 未缓存且网络访问被拒绝，在 project configuration 之前就被阻塞。

### 结论与升级 gate

签名 lineage 兼容性**尚未建立**。真实已发布 APK 不是所需 fixed-release-key upgrade gate 的有效 baseline，真实设备矩阵也**尚未执行**。尤其没有证据证明在 public APK 之上执行 `adb install -r` 后，token 保留、relay 连续性或重启行为正常。

这不是两个有效 release identity 之间的“不同 key”结论：v1 candidate 和配置的 release certificate 都不可用。v1 signing/token readiness 应保持 **blocked：签名 identity 未配置，真实升级未验证**。不能用旧 source 重建的 APK 或 debug-signed package 替代 public Release APK。

签名和迁移决策记录在 [release-signing-and-upgrade.md](android/release-signing-and-upgrade.md)。维护者必须选择：恢复并永久复用历史签名 identity，或声明 transition release，并要求重新安装加 settings export/import。本文不自动作出选择。

## Identity 与凭据存储 preflight

| 阻塞项 | 状态 | 证据 |
|---|---|---|
| 固定 release identity | 已实现；仍需人工配置签名 key | Release Gradle task 与 AA2 在 keystore 不完整或不存在时失败；tag workflow 要求四个签名 secret。 |
| Keystore-backed access/relay token | 已实现；仍需设备升级验证 | `AndroidKeystoreCredentialStore` 使用不可导出的 Android Keystore key 加密值，并以事务方式迁移 legacy 明文。 |
| 已安装应用的无损升级/恢复 | 在设备验证前保持 open | 必须使用同一 release key 签名的两个 APK 执行。 |

`SharedPreferences("yexuan_memery")` 是不可变的兼容名称，继续保存 backend URL、owner ID 等普通设置。敏感的 `adminToken` 和 `relayToken` 优先从 secure storage 读取。第一次 secure read 时，legacy value 会被安全写入；并且只有在写入成功后才从 legacy preferences 删除。secure write 失败会保留 legacy value。

## 必需真机验收

1. 安装旧的已签名 APK，设置 backend URL、owner ID、access token 以及（如使用）relay token。
2. 在不清除 app data 的情况下，以相同 signing identity 将 v1 signed APK 覆盖安装到其上。
3. 重启两次：connection 和后台通知行为必须正常，无需重新输入 token；使用授权的本地检查确认 legacy token key 已不存在。
4. 替换每个 token，重启，然后 delete/logout 并再次重启；不能再有凭据可用。
5. 分别执行无 token 的全新安装，以及手动输入 token 的全新安装。

升级步骤不得使用 `adb uninstall`、clear app-data、debug-signed APK 或不同 signing key；这些操作都会使验收条件失效。
