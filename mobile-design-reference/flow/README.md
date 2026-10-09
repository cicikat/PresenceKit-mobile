# Flow 梦境聊天 · 独立视觉 Demo

最终范围按用户更正：原版紫红/洋红/蜜桃粉金流体作为背景，聊天框作为厚玻璃；适配手机纵向矩形，保留已认可的卷曲，不做官方球体。无跨端影响。不接入 PresenceKit，不改变任何既有页面。

## 运行

直接在支持 WebGL2 的 Edge/Chrome 打开本目录 index.html 即可；无依赖安装，无 CDN。默认持续流动。

也可以从仓库根在 PowerShell 运行：

```powershell
node .\mobile-design-reference\flow\serve.cjs
```

浏览器访问 http://127.0.0.1:8766/index.html 。本地服务只监听 127.0.0.1，Ctrl+C 停止。start.bat 提供相同入口。已经运行时不要重复启动相同端口。

comparison.html 是官方图与当前聊天稿的并排材质对照。只有对照页读取官方图，主效果完全由 Shader 产生。

## 使用

- 右上角「···」打开设置：玻璃厚度、反射、流动速度、三种背景颜色、暂停/播放、恢复默认。
- 左上角返回按钮恢复示例对话与流体起始相位。
- 输入/发送仅在当前页面添加演示消息；无请求、无落盘、无虚假 AI 回复。
- `?static=1` 固定起始帧，方便截图。默认动画速度 0.24。
- `?debug=1` 显示玻璃法线，`?debug=2` 显示折射位移。
- 操作系统设置「减少动态效果」时默认静止，可手动播放；切到后台停止渲染，返回继续。

## 实现

flow.js 的 DEFAULTS 是参数入口。第一 pass 生成纵向卷曲流体并写入纹理；第二 pass 用 DOM 边界构造 SDF 曲面，厚度梯度 → 法线 → Snell RGB 折射 → 实际背景采样，叠加烟黑透射、Fresnel、细高光与内暗缝。聊天文字属于 DOM，玻璃本体属于 Shader。CSS 不使用 blur、backdrop-filter 或 box-shadow 代替玻璃。

背景采用连续域形变、卷曲与光带融合，属于程序化视觉流体，不是 Navier–Stokes 仿真。用户已认可卷曲形态，因此阅读新参考后保留该构图，没有将 flow/swirl 的满屏渐变直接替换进来。

## 证据与限制

- static-mobile.jpg：初始静态材质检查。
- comparison.jpg：官方参考与聊天稿并排截图。
- flowing-a.jpg / flowing-b.jpg：实际浏览器不同时间点，能看到流体卷曲及玻璃内部同步改变。
- reference-runtime.jpg：实际运行 gradient-backdrops 的 flow/swirl（源代码仅在外部研究目录，未引入项目）。
- animation.gif：实际浏览器连续截图录制，循环处会回到起始帧；实时 Demo 连续流动。
- 浏览器布局/本地输入/参数检查记录在 validation.json 与 cc-tasks/001-flow-dream.md。
- 不宣称与官方表盘逐像素一致：本次目标已更正为聊天视觉。二维折射是屏幕空间光学近似。
- YouTube 实机动画首帧可见，但播放器读取与播放核验超时，连续动画核验仍为 partial。
- 仅桌面浏览器响应式检查，未做真机 GPU、软键盘与功耗验收。
