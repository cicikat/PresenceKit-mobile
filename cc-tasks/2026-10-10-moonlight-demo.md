# 冷白月光 · Liquid Glass 独立视觉 Demo

范围：仅新增 mobile-design-reference/g-moonlight.*、moonlight-README.md 和验收截图；不修改已有样机、Flutter、Android、后端。无跨端影响，无业务接口、落盘状态或真实发送。

- [x] 确认目录与已有文件边界。证据：已有 a–f 样机，新增 g 系列，保留现有未提交改动。
- [x] 制作曲面玻璃背景和手机聊天层。实现证据：g-moonlight.js 曲面 SDF、法线、Fresnel 与折射采样；g-moonlight.css 局部 backdrop-filter。视觉验收待下一项截图。验收：390×844 实际截图可见曲率、折射和清晰文字。
- [x] 完成纯背景、点击、输入焦点与减少动态。证据：focus.png、validation.json 的 inert、card、send、reducedFramesEqual=true。验收：浏览器操作、系统 reduce 模拟。
- [x] 检查响应式、离线与浏览器错误。证据：validation.json errors=[]、externalRequests=[]；320/360/390/430 无横向溢出；截图已目视检查。验收：窄屏、桌面、file 打开，无外部请求。
- [x] 提供说明和截图。证据：moonlight-README.md、5 张实际浏览器截图及 g-moonlight-validation.json；独立提交见本文件 git log。真机性能/原生验收 not-run；本任务为视觉参考。