# 43 独立手机实时连接（R2，roadmap）

前置：工单42的R0/R1代码与自动验收；现场代理/弱网基线仍observe，不用新传输掩盖不可达。当前工单只定义下一阶段验收，不代表已接入WS。

- [ ] 定义独立/ws/mobile（或有client_type/device身份的订阅层）、mobile最小权限、owner/char绑定、连接代际；旧mobile token兼容，不能发admin或复用ws.desktop权限。
- [ ] 后端持久队列为canonical，WS只承载实时事件/流片段；HTTP负责发送/附件/历史与断点补收，保留request_id/turn_id/msg_id/seq的独立含义，不对token片段推进最终ACK。
- [ ] 手机独立订阅、心跳、失败退避、网络取消与HTTP降级；前后台交接复用工单42的inbox，不引入双消费者互相推进游标。
- [ ] 要获得token首字，后端必须接入mobile专属stream分支与作用域隔离，不能只新增socket地址；工具与生成过程不广播到不匹配的owner/角色。
- [ ] 同单提供无正文连接/重连/延迟/补收观测；若新增可运营传输策略，补管理面热更新、默认值、effective state及手机设置/降级。
- [ ] 验证桌面与手机同时在线不互踢、旧连接ACK/pong隔离、断流HTTP补收、撤权、角色切换、重复帧与canonical对账、代理/Doze/弱网；明确真实设备边界。

与R3多手机独立游标区分：不顺手改变现有全局ACK删除前缀合同。部署/发布不在本单默认授权范围。