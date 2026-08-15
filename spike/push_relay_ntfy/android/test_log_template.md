# ntfy Relay Spike — 测试记录

每个观察到的 publish → receive 事件填写一行。
`latency_s` = `loop_publish.sh` 输出中的 publish timestamp 到设备上出现通知之间的时间。

## 设备

| 字段 | 值 |
|-------|-------|
| Model | |
| Android version | |
| ROM / OEM skin | |
| Battery mode | （default / unrestricted / restricted） |
| test run date | |

## Baseline：MobileNotificationService long-poll

| # | publish_ts | receive_ts | latency_s | publish 时设备状态 | 备注 |
|---|-----------|------------|-----------|------------------------|-------|
| 1 | | | | screen-on | |
| 2 | | | | screen-off 5 min | |
| 3 | | | | screen-off 30 min | |
| 4 | | | | screen-off 60 min | |
| 5 | | | | swiped from recents | |
| 6 | | | | after reboot | |

## Spike：NtfyRelayService SSE

| # | publish_ts | receive_ts | latency_s | publish 时设备状态 | 备注 |
|---|-----------|------------|-----------|------------------------|-------|
| 1 | | | | screen-on | |
| 2 | | | | screen-off 5 min | |
| 3 | | | | screen-off 30 min | |
| 4 | | | | screen-off 60 min | |
| 5 | | | | swiped from recents | |
| 6 | | | | after reboot | |

## 观察项

- SSE socket 是否在 30 分钟 Doze 中保持连接且无需重连？Y / N
- SSE socket 是否在 60 分钟 Doze 中保持连接且无需重连？Y / N
- OEM 是否杀掉 foreground service？（检查 `adb logcat | grep NtfyRelaySpike`）Y / N
- 1 小时内重连了多少次？（统计 logcat 中的 `SSE connecting` 行）
- 是否需要 battery optimization exemption 才能保持连接？Y / N / 未测试

## logcat 采集命令

```bash
# 连接设备，在测试期间运行：
adb logcat -v time NtfyRelaySpike:V *:S 2>&1 | tee ntfy_spike_logcat.txt

# 另一个终端 —— long-poll baseline：
adb logcat -v time mobile-poll:V *:S 2>&1 | tee longpoll_logcat.txt
```
