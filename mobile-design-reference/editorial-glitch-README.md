# 双方案独立样机

直接打开 index.html，或单独打开 pink-editorial.html / glitch-dreamscape.html。两套页面均内联 CSS / JavaScript，无构建依赖；不调用业务接口、不持久化输入。无跨端影响。

## 素材

- 摄影：Unsplash images.unsplash.com，图片 ID：photo-1534528741775-53994a69daeb（人物）、photo-1449824913935-59a10b8d2000（日间城市街道）、photo-1490750967868-88aa4486c946（花卉）。采用远程引用，不复制至仓库。失败时显示有文字说明的条纹占位。
- Zpix：https://github.com/SolidZORO/zpix-pixel-font；远程字体 https://zpix.vercel.app/zpix.woff2，失败回退 monospace。Zpix 并非不受限制的商业开源字体：作者说明个人与教育项目免费，商业项目需另行授权。本次仅个人设计探索。
- 英文衬线使用 Georgia，中文正文使用系统字体；图标为手写 SVG。

## 第二版：仅聊天场景

本版两套均仅聊天页。A 为杂志工作台：固定页边人物栏、来信与剪贴纸片、共享摄影与瞬间标记；B 为城市散步：可切换场景、对白时间轴与横向记忆照片。两套支持发送模拟文本、快捷回复、附件工具、内容展开与放进对话，以及收起/展开场景。减少动态设置禁用动效；B 仅换场景瞬间短暂位移，不持续闪烁。旧 index 已完整保留为 previous-directions.html。

## 验收边界

浏览器验证结果见 editorial-glitch-validation.json。Android/iOS 真机、Safari、软键盘与 GPU / 电量表现 not-run。

第二版截图：pink-editorial-chat.png / glitch-dreamscape-chat.png；聚焦模式：pink-editorial-focus.png / glitch-dreamscape-focus.png。此前的 home/profile/diary 截图为第一版历史记录，当前 HTML 已不包含这些页面。
