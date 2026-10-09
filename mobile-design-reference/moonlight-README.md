# 冷白月光 · Liquid Glass

运行：直接双击本目录 g-moonlight.html，用 Chrome、Edge 或 Safari 打开。无需安装、构建、服务或联网。桌面显示 390×844 居中手机框，手机全屏。

右侧（手机右上）可切换纯背景、暂停流动。气泡按压缩放，卡片可切换状态，输入聚焦时玻璃边缘增亮。输入和发送仅提供视觉反馈，不联网、不存储、不生成消息。

背景使用 WebGL SDF 曲面、光线步进、法线、Fresnel、折射环境采样和局部珍珠反射。前景卡片单独使用 backdrop-filter，文字深灰紫，不对整屏做模糊。24 秒相位循环；最多 24 帧/秒，分辨率上限 420 像素宽。页面隐藏、系统减少动态或手动暂停时停止渲染。无外部图片、字体或付费素材。WebGL 不可用时显示静态 SVG 降级。

光学限制：程序环境透射近似，不是物理路径追踪，没有真实多次折射、完整背面光线追踪或物理焦散。前景是背景模糊与边缘高光，没有 Apple 原生透镜重映射。参考原则：https://developer.apple.com/videos/play/wwdc2025/219/

验收：2026-10-10 Chrome headless / SwiftShader，file 协议实际渲染并目视检查截图。validation.json：零页面错误、零外部请求；320/360/390/430 无横向溢出；减少动态时截图不变，恢复后变化；纯背景下聊天层 inert。截图包含 preview、background、desktop、mobile、focus。

真机 GPU 性能、软键盘和 Safari 验收 not-run。没有修改 Flutter、Android、后端或其他样机。无跨端影响。