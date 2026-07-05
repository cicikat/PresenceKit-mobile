[English](README.md) | [简体中文](README.zh-CN.md)

# PresenceKit-mobile

[PresenceKit](https://github.com/cicikat/PresenceKit)（有长期记忆和情绪状态的 AI 陪伴后端）的 Flutter 手机薄客户端：聊天、资料、日记、花园、能力检查，以及接收主动消息的 mobile channel 轮询器。人格、记忆和调度全部在后端。

**必须搭配运行中的 PresenceKit 后端使用**，见[后端快速开始](https://github.com/cicikat/PresenceKit#快速开始)。

---

## 连接后端

**开发调试**时，手机用数据线连着跑后端的电脑：

```powershell
adb reverse tcp:8080 tcp:8080
```

这会把手机访问的 `http://127.0.0.1:8080` 转发到电脑上跑的后端。`mobile_dev_control.bat` 把这个命令（以及撤销转发）包成了一个小菜单——用前先改脚本开头的 `ADB` 路径。

**脱离数据线后**，把 App 设置里的"后端节点"改成电脑局域网地址，例如 `http://192.168.1.100:8080`。要求：

- 手机和电脑在同一个局域网，或通过 Tailscale / VPN / 内网穿透互通。
- 后端管理服务监听 `0.0.0.0:8080` 或对应局域网地址。
- 防火墙允许手机访问 8080。
- 公网节点必须使用 HTTPS；明文 HTTP 仅允许 loopback、Tailscale 或用户确认过的 RFC1918 私网精确 IPv4 origin。

也可以在打包时预置后端地址：`flutter build apk --release --dart-define=BACKEND_BASE_URL=http://192.168.1.100:8080`。

---

## 打包 / 安装

`AA打包安装到手机.bat` 会构建 debug APK 并通过 adb 安装到已连接设备。脚本开头硬编码了本机的 `flutter`/`adb` 路径，运行前请先改成你自己的路径。

当前 Android release 仍使用 debug signing，仅适合自用内测安装，不用于正式分发或上架。

---

## 更多文档

- [docs/mobile/background-notification-design.md](docs/mobile/background-notification-design.md) — 后台轮询、通知闸门与行为 metadata 处理（已实现，不是提案）。
- [docs/roadmap-notes.md](docs/roadmap-notes.md) — 尚未定型的开放设计问题。
- [docs/protocols/sensor-event-protocol.md](docs/protocols/sensor-event-protocol.md) — 多端/硬件传感器事件协议草案。

---

## 运行测试

如果本机用了 HTTP 代理，Dart 的 HTTP 客户端会把对 `127.0.0.1` 的请求也路由到代理，导致进程内测试通信失败（`HttpException: Connection closed before full header was received`）。跑测试前设置 `NO_PROXY`：

```powershell
$env:NO_PROXY = "localhost,127.0.0.1,::1"; flutter test
```

详见 [CLAUDE.md](CLAUDE.md)。CI 或无代理环境下 `flutter test` 无需额外设置。

---

## License

This project is licensed under the PolyForm Noncommercial License 1.0.0.

Noncommercial use is permitted. Commercial use is not permitted without separate permission from the author.
