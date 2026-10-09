# 29 · 粉色梦核与 Meta 私语视觉参考

范围：仅 mobile-design-reference/ 新增 E 方案与索引入口。用户指定粉色、梦女感、梦核、Meta 与碎像素装饰；独立窗口式布局，不只是已有方案换色。无跨端影响，不接入 Flutter，不调用后端。

- [x] 01 制作独立粉色梦核首页与聊天窗口、像素装饰及梦境场景。证据：e-reverie.html、pink-dream.css、pink-dream.js；独立页签/梦境窗口/回信窗口布局，原创云层门与阶梯 SVG、CSS 像素点缀；node --check 通过，截图见 03。
- [x] 02 完成聊天/梦境/日记/花园演示及索引入口、说明。证据：pink-dream.js 的 render/submit、index.html 第五款入口、README 的 E 说明；纯内存模拟消息与导航。
- [x] 03 浏览器检查布局、交互及窄屏溢出；保存截图。证据：私语/日记/花园/梦境往返与模拟输入通过；E 筛选仅显示 e、五款对比显示 5；358px iframe 的 body.scrollWidth=clientWidth=358；e-reverie-preview.jpg。Flutter/真机 not-run。
- [x] 03b 新增 F 黑粉夜间版本：近黑底、灰白正文、高亮玫红焦点、少量冷青点缀。证据：f-noir.html、noir-dream.css；中性底色 #101116、亮玫红 #ff4f9b、灰白正文、少量冷青 #bde6d7；专属首屏文案与深色 SVG 配色。
- [x] 03c 检查 F 四场景和模拟发送，保存截图并加入六款索引。证据：F 四场景/模拟发送通过，E 共享脚本回查通过；E/F 358px 无横向溢出；F 筛选=f，六款对比=6；f-noir-preview.jpg。
- [x] 04 检查 UTF-8/CRLF、差异范围并独立提交。证据：node --check、CRLF 扫描和 diff --check 通过，普通/忽略 CR stat 一致；本提交仅参考文件与工单，原有 .tmp/ 不纳入。

依赖：01 → 02 → 03 → 04。
