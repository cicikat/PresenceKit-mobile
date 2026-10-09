# 001 — Flow 梦境聊天视觉 Demo

范围：仅 mobile-design-reference/flow 新增独立演示；不改已有页面或 Flutter/Android/后端。用户已更正为流体背景 + 厚玻璃聊天框，原图作为材质/配色参照，不再要求聊天页逐像素复刻数字表盘。无跨端影响。

- [x] 阅读官方图及两个技术参考；观察深黑底、洋红/蜜桃粉金光团、深色透射、细亮边。研究 SDF、厚度梯度、Snell 折射、RGB 色散、Fresnel。证据：RESEARCH.md。
- [x] 静态实现：WebGL2 双 pass 背景纹理 + SDF 玻璃；参数集中；离线可打开。验收：真实浏览器截图与 shader 无错误。证据：flow.js 双 pass、浏览器 407×713 显示 renderer=webgl2、无 console error/warn、无横向溢出。
- [x] 视觉检查：官方参考和聊天材质并排截图；检查颜色、深色中心、厚边、折射压缩，必要时迭代。证据：static-mobile.jpg、comparison.jpg，已实际打开查看；调整下部光环的叠加，避免高光发白。按更正后的聊天设计验收，不宣称逐像素表盘复刻。
- [x] 动画：静态检查后加入缓慢流动；暂停/恢复、减少动态效果、后台暂停。验收：浏览器检查两个时间点。证据：flowing-a.jpg/flowing-b.jpg，time 0.052 → 3.327，卷曲与玻璃透射同步改变；播放/暂停按钮及厚度 24→25 已实际操作。后续用户认可现有纵向卷曲，保留，不改成球。
- [x] 交互和移动尺寸：输入/发送仅本地、清空恢复、参数调节；实际 407×713 检查无横向溢出；发送 3→4 条，重置回 3 条。证据：local-message.jpg、final-mobile.jpg、validation.json。390×844 覆盖未生效，不冒充该尺寸验收。
- [x] 交付：独立 HTML、截图、运行说明、限制和提交；只提交本任务文件。证据：README.md、animation.gif（实际 24 帧，12.7 秒）、validation.json；node --check 通过。YouTube 连续动画仍 partial，真机/软键盘/功耗 not-run。
- [x] 追加参考实际运行：外部仓库 gradient-backdrops，commit ddad93da04280f83f3cf25898a1f1cbdf001385e；flow/swirl 无 console error/warn，reference-runtime.jpg。已读 references/techniques.md。
- [ ] partial：YouTube 实机动画。页面与首帧可见，播放与状态读取连续超时，尚未核验连续动画。
