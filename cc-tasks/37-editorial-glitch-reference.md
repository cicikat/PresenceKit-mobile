# 37 · 双方案视觉探索

范围：仅 mobile-design-reference，独立 HTML；无跨端影响，不接后端、不落盘聊天、不修改业务代码。

- [x] 创建 Pink Punk Editorial 四页与交互；验收 390×844 / 360 宽。
- [x] 创建 Digital Glitch Dreamscape 四页与交互；验收图像裁切、减少动态与素材降级。
- [x] 双方案入口与素材来源说明，保留旧入口。
- [x] 浏览器验证切页、聊天、收藏、详情、窄屏；真机 GPU / Safari / 键盘 / 电量 not-run。
- [x] CRLF、差异检查并独立提交。

A 实现证据：pink-editorial.html 四个 section、导航、模拟发送、筛选、dialog。浏览器验收待下一项。

B 实现证据：glitch-dreamscape.html 阶梯裁切、双图像位移、一次性 glitch、prefers-reduced-motion、图片错误 fallback。

入口与素材证据：index.html、previous-directions.html、editorial-glitch-README.md。

浏览器证据：editorial-glitch-validation.json，两套四页截图；Edge headless 390×844 / 360×780，各 15 项检查通过，无 pageerror。真机项目仍 not-run。

交付检查：所有本次文本保持 CRLF，git diff --check 通过，仅暂存本单文件。提交号见 git log 对应本工单提交。
