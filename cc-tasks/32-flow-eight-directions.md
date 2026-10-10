# 32 · Flow 梦境八方向

范围：仅 mobile-design-reference/flow/directions 独立视觉稿，复用经典卷曲(mode=2)和伪随机流体(mode=0)。无跨端影响，无后端请求、落盘或真实发送。

- [x] 建立八套独立风格、布局、配色以及总览入口；证据：directions/designs.js 八方向配置、structures 八种布局，index.html 4+4 总览。
- [x] 本地消息、提示、梦境片段、暂停交互；证据：validation.json 八套 textSafe/prompt/reset/moves/paused 均通过，三套 fragment 通过。
- [x] 浏览器截图、320/390/430 宽度、动画与减少动态效果检查；证据：evidence/c1–c4、f1–f4.png；validation.json 三种宽度无溢出、reducedFrozen=true。真实设备 GPU/键盘/功耗 not-run。
- [x] README、CRLF、JS 语法、diff 检查与独立提交。证据：三份 JS/CJS node --check 通过；git diff --check 通过；README 换行忽略前后统计均为 4 行新增；全部新文本 UTF-8 CRLF。提交见 git log 本工单对应提交。