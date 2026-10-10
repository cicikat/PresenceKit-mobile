# 003 — 恢复上一版卷曲背景

仅独立视觉 Demo，无跨端影响。

- [x] 从 00bf35f 恢复旧版动态背景为第三种模式，保留当前默认模式和玻璃。
- [x] 实际浏览器切换、截图及 Shader 错误检查。
- [x] 更新说明并独立提交。

证据：flow.js legacyCurl、index.html mode=2；浏览器实际选择第三项，legacy-curl.jpg，控制台错误为空；node --check 通过。无跨端影响。
