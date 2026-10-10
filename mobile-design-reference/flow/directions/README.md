# 梦境八方向

入口：现有 Flow 服务 http://127.0.0.1:8766/directions/index.html 。仓库根运行 `node .\mobile-design-reference\flow\serve.cjs`；已运行则复用。也可直接打开 index.html。

经典卷曲：C1 金色剧场（舞台对白）、C2 冰蓝留白（侧轴对话）、C3 朱红书信（信件排版）、C4 薄荷终端（分区终端）。

伪随机流体：F1 奶油梦卡（堆叠梦卡）、F2 靛蓝轨道（环形导航与居中对话）、F3 珊瑚杂志（编辑网格）、F4 黑白切片（上下分屏）。

design.html?id=c1 至 c4 / f1 至 f4 可独立打开。加 `&static=1` 固定 Shader 帧。总览使用实际浏览器截图；详情保留真实 WebGL2 动态背景。renderer.js 派生自上级 flow.js，只增加 FLOW_CONFIG 初始化与恢复参数，保留 mode=2/0 的完整 Shader 与厚玻璃算法；配色有意按八个方向分别配置。

对话发送仅追加本地文本；✧ 插入提示；··· 内暂停/播放与重置；梦境片段卡可打开短篇并填入输入框。导航与关闭片段均为本地操作，无请求、存储或模拟 AI 回复。系统减少动态效果默认静止，页面隐藏暂停渲染。WebGL2 不可用时保留静态背景和 UI。

范围仅视觉参考，无跨端影响；未修改 Flutter、Android、后端或正式版本。实际浏览器证据见 validation.json 和 evidence/；真实手机 GPU、Safari、软键盘及功耗 not-run。
