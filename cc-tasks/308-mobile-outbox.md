# 308 手机聊天持久投递

- [x] 连发即时显示、稳定身份、串行发送，通过受控回包的 Flutter 回归。
- [x] 本地持久化、重启及连接范围隔离，未知结果凭原 ID 对账。
- [x] 附件与引用使用冻结载荷，验证上传失败及恢复边界。
- [x] 8 个相关 Flutter 测试文件共 100 项通过，flutter analyze 无问题。
- [x] Android dev debug APK 构建成功。首轮发现 Android SDK 未公开 AtomicFile.exists，改为通过 openRead 处理缺文件后重新构建通过。
- [ ] Android 真实弱网验收。ADB 暂无设备，安装、网络切换、杀进程、后台唤醒和录屏保留 observe。

先红后绿：受控第一条 HTTP 回包时，旧实现只显示 A。新实现同样的入口显示 5 个带稳定 request_id 的气泡，只有 A 进入网络槽。
恢复验证：从同一快照重建控制器，先验证超时的 A，证据出现后 B/C 按顺序发送。另覆盖角色切换、403 附件重试、5xx 未知、WS/HTTP/poll 交错及重复段落。
复用现有 scoped session、request_id、chat-log、mobile poll 和 WS，无后端 schema 差异。Android 私有快照由 settings 通道处理，回滚和容量见可靠投递文档。
