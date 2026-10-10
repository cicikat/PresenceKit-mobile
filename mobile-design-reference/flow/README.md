# Flow 梦境聊天 · 独立视觉 Demo

最终范围按用户更正：原版紫红/洋红/蜜桃粉金流体作为背景，聊天框作为厚玻璃；适配手机纵向矩形，采用伪随机流体或可选立体 ∞ 流带，不做官方球体。无跨端影响。不接入 PresenceKit，不改变任何既有页面。

## 运行

直接在支持 WebGL2 的 Edge/Chrome 打开本目录 index.html 即可；无依赖安装，无 CDN。默认持续流动。

也可以从仓库根在 PowerShell 运行：

```powershell
node .\mobile-design-reference\flow\serve.cjs
```

浏览器访问 http://127.0.0.1:8766/index.html 。本地服务只监听 127.0.0.1，Ctrl+C 停止。start.bat 提供相同入口。已经运行时不要重复启动相同端口。

comparison.html 是官方图与当前聊天稿的并排材质对照。只有对照页读取官方图，主效果完全由 Shader 产生。

## 使用

- 右上角「···」打开设置，可切换伪随机流体、立体 ∞ 流带、经典卷曲（上一版）：流体形态、换种子、玻璃厚度、反射、流动速度、三种背景颜色、暂停/播放、恢复默认。
- 左上角返回按钮恢复示例对话与流体起始相位。
- 输入/发送仅在当前页面添加演示消息；无请求、无落盘、无虚假 AI 回复。
- `?static=1` 固定起始帧，方便截图。默认动画速度 0.24。
- `?debug=1` 显示玻璃法线，`?debug=2` 显示折射位移。
- 操作系统设置「减少动态效果」时默认静止，可手动播放；切到后台停止渲染，返回继续。

## 实现

flow.js 的 DEFAULTS 是参数入口。第一 pass 生成伪随机流体或立体 ∞ 流带并写入纹理；第二 pass 用 DOM 边界构造 SDF 曲面，厚度梯度 → 法线 → Snell RGB 折射 → 实际背景采样，叠加烟黑透射、Fresnel、细高光与内暗缝。聊天文字属于 DOM，玻璃本体属于 Shader。CSS 不使用 blur、backdrop-filter 或 box-shadow 代替玻璃。

默认背景采用带种子的三维噪声、多层 domain warp 和高度场法线明暗，随时间伸展、融合及分离。它属于程序化视觉流体，不是 Navier–Stokes 仿真。可选立体 ∞ 模式投影空间曲线，并用前后层遮挡、变化带宽及半扭转明暗制造莫比乌斯环的感觉；不是数学上的真实莫比乌斯曲面。mode、seed、warp 与全部材质参数集中在 DEFAULTS。

## 证据与限制

- 新版：fluid-v2.jpg / mobius-v2.jpg，实际浏览器两种模式截图；fluid-v2.gif 为 24 帧、约 13.6 秒的浏览器连续录制。validation-v2.json 记录模式切换、换种子、暂停检查。下面旧版截图仅保留历史证据。

- static-mobile.jpg：初始静态材质检查。
- comparison.jpg：官方参考与聊天稿并排截图。
- flowing-a.jpg / flowing-b.jpg：实际浏览器不同时间点，能看到流体卷曲及玻璃内部同步改变。
- reference-runtime.jpg：实际运行 gradient-backdrops 的 flow/swirl（源代码仅在外部研究目录，未引入项目）。
- animation.gif：实际浏览器连续截图录制，循环处会回到起始帧；实时 Demo 连续流动。
- 浏览器布局/本地输入/参数检查记录在 validation.json 与 cc-tasks/001-flow-dream.md。
- 不宣称与官方表盘逐像素一致：本次目标已更正为聊天视觉。二维折射是屏幕空间光学近似。
- YouTube 实机动画首帧可见，但播放器读取与播放核验超时，连续动画核验仍为 partial。
- 仅桌面浏览器响应式检查，未做真机 GPU、软键盘与功耗验收。

经典卷曲恢复自提交 00bf35f 的完整动态背景 Shader，与上传截图对应。保持旧版流动方式与配色；该模式不使用随机种子。legacy-curl.jpg 为实际浏览器截图。

## 梦境 UI 八方向

新增 [八套总览](directions/index.html)：经典卷曲与伪随机流体各四套，不同布局、配色与排版。运行现有服务后访问 http://127.0.0.1:8766/directions/index.html 。实际浏览器截图、交互验收与限制见 [说明](directions/README.md)。无跨端影响。
