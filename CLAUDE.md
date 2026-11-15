# PresenceKit-mobile — Claude 入口

协作约定、开发环境（Windows）、强制规则与文档入口以 AGENTS.md 为唯一来源：

@AGENTS.md

## 聊天发送回归约束（工单55）

修改发送队列、会话准备、持久化或消息菜单时，必须保留并运行 test/chat_recovery_upload_test.dart、test/mobile_outbox_deadline_test.dart、test/chat_interaction_regression_test.dart。尚未派发消息排队满一分钟即停止自动发送并显示失败；排队可取消；已派发等待回复不能套用这一期限；重启不得补发过期/取消消息；手动重试须刷新排队时间，取消与派发必须原子互斥。原54未知/失败不得阻塞后续的测试同样不可删除或弱化。CI全量flutter test继续覆盖这些用例。
