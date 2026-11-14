# 工单 #48｜修复 Flutter Android Release 构建时的 Kotlin 跨盘符增量缓存异常

## 施工记录（2026-11-14）

- [x] A：已核对Flutter3.32.0/Dart3.8.0、Kotlin2.1.0、AGP8.7.3、Gradle8.12、Java21.0.10；项目D盘、Pub Cache C盘。#50 dev构建真实复现different-roots/daemon异常，fallback后成功。当前无kotlin.incremental设置；AA1/AA3沿普通Flutter CLI构建，未找到CI工作流。
- [x] B：android/gradle.properties:6设置kotlin.incremental=false。对全仓开发者/CI生效，可能增加Kotlin重编耗时；不禁daemon、不迁全局缓存。工具链/盘符调整后可移除这三行回滚，需重新验证。
- [x] C：pub get成功；原prod release连续两次退出0（88.19/34.17秒），强制目标重编10任务执行成功（24秒）。三份日志异常计数全0；包名/1.3.0+74/历史证书、大小及SHA-256已核验，见docs/quality/kotlin-cross-drive-48.md。
- [ ] D：文档已更新；待换行检查与独立提交。无跨端影响。

- **项目**：PresenceKit Mobile（现工作目录可能仍名为 `D:\ai\Emerald-mobile`，以实际仓库为准）
- **优先级**：P2 / 构建稳定性
- **性质**：非阻塞异常治理；不是功能故障
- **执行者**：Codex
- **边界**：仅处理 Android/Flutter 构建链，不改业务、协议、配置数据或版本策略

## 一、背景与证据

用户执行的命令：

```powershell
flutter build apk --release --flavor prod --build-name 1.3.0 --build-number 74
```

**重要：用户确认该次 APK 构建最终成功。** 不得把日志中的 `e: Daemon compilation failed: null` 解读为整个构建失败；这是需要清理的 Kotlin 编译器异常/回退噪声。

日志关键特征：

```text
e: Daemon compilation failed: null
Could not close incremental caches in D:\ai\Emerald-mobile\build\package_info_plus\kotlin\compileReleaseKotlin\...
this and base files have different roots:
C:\Users\10434\AppData\Local\Pub\Cache\hosted\pub.dev\package_info_plus-8.3.1\android\src\main\kotlin\...\PackageInfoPlugin.kt
and D:\ai\Emerald-mobile\android
```

初步判断：Windows 下 Pub Cache 在 C:、项目在 D:，Kotlin 增量编译缓存对跨盘符路径进行相对路径计算，触发 `IllegalArgumentException`；需验证完整日志是否为该问题、是否触发 fallback。`33 packages have newer versions` 和字体 tree-shaking 不是本次故障。

## 二、任务目标

1. 在不影响现有 APK 产物的前提下，消除（或有证据地规避）`Daemon compilation failed` / `Could not close incremental caches` / `different roots` 这组异常。
2. 保持现有 `prod` flavor、签名、版本号、产物路径及 Release 行为不变。
3. 方案可解释、可回滚，不做无关升级或大规模清缓存操作。

## 三、实施步骤

### 48-A｜检查当前构建配置与复现

1. 确认实际仓库位置、`android/gradle.properties` 内容、Flutter/Kotlin/Gradle 版本、`PUB_CACHE` 实际路径及本次 release 构建最终退出状态。
2. 检查仓库中是否已有 `kotlin.incremental` 设置、专用打包脚本、CI Windows/Android 构建配置，避免重复或冲突。
3. 如果日志可复现，记录异常出现位置，以及构建最终为 SUCCESS 还是 FAILURE；若不可复现，至少确认所给日志和路径足以支撑处理。
4. 先保留原配置和构建日志，勿以升级 Flutter/Kotlin/插件作为第一选择。

### 48-B｜最小修复

**优先采用仓库级、可复核的修复：** 如果已确认异常来自跨盘符增量缓存，并且需要稳定地消除它，可在 `android/gradle.properties` 添加：

```properties
# Work around Kotlin incremental-cache errors on Windows when PUB_CACHE and the project are on different drives.
# Revisit after toolchain/path changes; non-incremental Kotlin compilation may increase build time.
kotlin.incremental=false
```

注意：

- 先检查是否已存在同名属性；只保留一处，避免冲突。
- 这是**规避方案**，不是修复 Kotlin 编译器本身；关闭 Kotlin 增量编译可能增加构建耗时，且此仓库配置会影响所有使用者与 CI。请记录影响与回滚方法。
- 若现有仓库已有更合适的 Windows 局部配置方式，并能在普通 Flutter CLI 构建中可靠生效，可优先采用该方式，避免无谓影响其他平台；但不要为了局部化引入脆弱复杂的 Gradle 改造。
- **不要**默认迁移/删除用户全局 `C:\Users\...\Pub\Cache`，不要擅改机器级环境变量 `PUB_CACHE`。把“将 Pub Cache 与项目置于同一盘符”列为可选的长期优化，并附手动操作说明即可。
- 不要通过禁用 Kotlin daemon、降级 Kotlin、随意修改 `package_info_plus` 源码或升级所有依赖来压制日志。

### 48-C｜清理受影响的构建缓存并验收

1. 如修改后仍受旧缓存影响，停止本项目 Gradle daemon；优先只删除 **仓库内**受影响的生成构建缓存。若必要，执行 `flutter clean`，但不得碰业务数据、用户文件或全局缓存。
2. 执行 `flutter pub get`，使用原有命令重新构建：

```powershell
flutter build apk --release --flavor prod --build-name 1.3.0 --build-number 74
```

3. 核验退出码为 0、APK 文件实际存在且非空；记录路径/大小（如可行，记录 SHA-256）。
4. 在完整新日志中核查：不再出现该跨盘符 Kotlin 异常；不要把其他正常提示当成失败。
5. 如果条件允许，连续构建两次，验证第二次也没有异常，并记录与原构建的耗时差异（不要求绝对性能相同）。
6. 运行仓库现有与本变更直接相关的检查；不要借此扩大测试和修复范围。

## 四、禁止范围

- 禁止修改 `lib/` 业务逻辑、后端接口、角色配置、权限逻辑、用户数据及生产服务。
- 禁止修改 `pubspec.yaml`/`pubspec.lock` 依赖版本（除非发现此次异常有明确、可核验的必要修复，须单独说明）。
- 禁止变更 `prod` flavor、applicationId、签名、`versionName`/`versionCode`、打包命令的预期语义。
- 禁止删除全局 Pub/Gradle 缓存、覆盖凭据或重置开发环境。
- 不应仅因出现一段 Kotlin stack trace，就声称 APK 构建失败。

## 五、完成标准（DoD）

- [x] 指出异常的具体来源及为何“报错但最终构建成功”：增量缓存跨盘异常后fallback成功，见#48报告。
- [x] 最小修复已落实：gradle.properties关闭Kotlin增量编译。
- [x] `prod` release APK 按原命令成功生成，产物路径已核验，见#48报告。
- [x] 验收三份完整日志中该三类异常计数均0。
- [x] 未改动运行数据、业务逻辑、依赖版本或签名配置；仅构建配置和文档，无跨端影响。
- [x] #48报告给出变更、命令、结果、性能取舍及移除三行回滚办法。
- [ ] 如按仓库正常流程需要提交代码，独立 commit/PR，不混入其他工单。

## 六、回报格式

请按下面格式回报：

```text
48 结果：完成 / 部分完成 / 未处理
根因：
修改文件：
采用方案及原因：
验收命令与结果：
APK 路径 / 大小 / SHA-256（如取得）：
日志异常是否消失：
对构建耗时的影响：
剩余风险与回滚方法：
Commit / PR（若有）：
```

> 原则：**成功的打包结果优先保住，再治理日志异常；不为修一条 Kotlin 编译提示扩大改造面。**
