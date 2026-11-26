# 64：T4 Session Scope 切断

- [x] 核对聊天、历史、媒体与产物的现有 grant 传递；poll/ACK 保持 owner 共享游标。
- [x] 删除 session_not_found 后自动重绑并重放调用的路径。
- [x] 语音转写随当前角色 grant，换角色/连接期间丢弃旧转写。
- [x] 运行 session/backend request、聊天恢复与发送期限回归。
- [ ] 真机完整对话与录音：未验收不得标通过。

后端与桌面对应总工单 T4。无新增设置、持久状态或权限；后端沿用 session-scope 只读观测。

验证：134 项 Flutter 定向回归通过；flutter analyze --no-pub 无问题。用户要求先提交检查点，真机验收保持 open，未发布。
