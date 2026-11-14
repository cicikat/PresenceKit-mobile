# 手机 #48：Kotlin 跨盘缓存规避

## 根因及范围

Windows 本机项目在 D:、Pub Cache 在 C:。Kotlin 2.1.0 增量缓存把 `package_info_plus-8.3.1` 的 C: 源文件相对于 D: Android 项目记录时触发 `this and base files have different roots`，导致缓存关闭失败、daemon 编译失败并回退。#50 的 dev 构建已真实复现且最终成功；用户原先的 prod release 也已成功。原问题是编译异常与回退噪声。

当前 Flutter3.32.0、Dart3.8.0、AGP8.7.3、Gradle8.12、Java21.0.10。既有根配置无同名属性；AA1/AA3 调用 scripts/build_release.ps1 的普通 Flutter CLI，没有找到仓库 CI 工作流。

仅在 `android/gradle.properties` 追加说明及 `kotlin.incremental=false`。这使本项目及插件 Kotlin 编译不使用该增量缓存，保留 daemon；Flutter SDK 的独立 included build 可继续使用其自身增量配置。没有迁移全局 Pub Cache、删缓存、升级依赖或工具链；本次无需清理生成目录。

配置对所有使用者/CI生效，Kotlin 源码变化后可能增加重编耗时。以后工具链修复或将 Pub Cache 与项目安排在同盘后，可移除追加的三行并重新验证。可选同盘方案需用户自行规划缓存位置并在本机会话设置 `$env:PUB_CACHE` 后运行 pub get；本单未改机器环境变量，也不要求迁移现有缓存。

## 验收（2026-11-14）

先检查 ignored 的 `android/key.properties` 完整且其引用的历史 keystore 存在，并用 keytool 核对配置 alias 的证书等于发行文档中的历史 identity；未输出或改写密码/私钥。

`flutter pub get` 成功（8.90秒）。以下原命令连续执行两次，退出码均为0：

```powershell
flutter build apk --release --flavor prod --build-name 1.3.0 --build-number 74
```

| 运行 | 总耗时 | Gradle阶段 | 结果 |
|---|---:|---:|---|
| 第一次 | 88.19秒 | 83.8秒 | APK成功 |
| 第二次 | 34.17秒 | 29.6秒 | APK成功 |

额外在 android/ 运行 `.\gradlew.bat :package_info_plus:compileReleaseKotlin --rerun-tasks --info --console=plain`，退出码0、`BUILD SUCCESSFUL in 24s`、10项任务全部执行。日志确认目标 Kotlin 源文件来自 C: Pub Cache，目标编译任务实际执行；该任务没有 `Using Kotlin/JVM incremental compilation`。该文字仍可出现在 Flutter SDK 独立 included build 的任务，不能据此误判项目规避失效。

对两份完整 release 日志及强制重编日志逐项扫描：`different roots`、`Could not close incremental caches`、`Daemon compilation failed` 均为0。完整日志及每次退出码/耗时在本机 ignored 的 `build/review/mobile-kotlin-48/`。

第二次明显快于第一次是本次实际观察，没有同条件旧版 Release 耗时基线，因此不能据此断言关闭增量编译提高性能。#50 的旧 dev 构建不是有效 Release 性能对照。

## 产物与签名

- 路径：`build/app/outputs/flutter-apk/app-prod-release.apk`
- 大小：47,288,274字节（Flutter显示45.1MB）
- SHA-256：`836B07A013C170A4C961D8D3D60BADE888FAB269562556B42F334646C6CA04C8`
- aapt：`com.presencekit.mobile`，versionName `1.3.0`、versionCode `74`。
- apksigner verify退出码0；certificate SHA-256 `1869b348d9e26f13d8213ff60933bcf933fe6e8779d13198f655a4d7c0791fae`，subject `C=US, O=Android, CN=Android Debug`，与仓库历史固定identity一致。沿既有release签名配置使用历史证书，没有创建新key或切换到Gradle debug signing fallback。
- apksigner另报既有META-INF条目未受JAR签名保护的警告，未作为本次Kotlin故障处理。

这是原构建命令的验证产物，未安装、未发布；没有修改pubspec版本或依赖、prod flavor、applicationId及签名配置。没有设备，不能声称覆盖安装/侧栏版本已经验证。仅构建配置与文档，**无跨端影响**；不新增设置、状态、接口或能力，不需修改后端/桌面管理面。
