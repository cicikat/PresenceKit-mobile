# yexuan_memery — 开发说明

## 运行测试

本机使用系统代理（`HTTP_PROXY=http://127.0.0.1:7897`），Dart 的 HTTP 客户端会把对
`127.0.0.1` 的连接也路由到代理，导致 flutter_tester 内部通信失败：
`HttpException: Connection closed before full header was received`。

运行测试前必须设置 `NO_PROXY`：

```powershell
$env:NO_PROXY = "localhost,127.0.0.1,::1"; flutter test
```

或在 CI / 无代理环境中直接运行 `flutter test`（无需额外设置）。
