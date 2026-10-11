# 双方案独立样机

直接打开 index.html，或单独打开 pink-editorial.html / glitch-dreamscape.html。两套页面均内联 CSS / JavaScript，无构建依赖；不调用业务接口、不持久化输入。无跨端影响。

## 素材

- 摄影：Unsplash images.unsplash.com，图片 ID：photo-1534528741775-53994a69daeb（人物）、photo-1449824913935-59a10b8d2000（日间城市街道）、photo-1490750967868-88aa4486c946（花卉）。采用远程引用，不复制至仓库。失败时显示有文字说明的条纹占位。
- Zpix：https://github.com/SolidZORO/zpix-pixel-font；远程字体 https://zpix.vercel.app/zpix.woff2，失败回退 monospace。Zpix 并非不受限制的商业开源字体：作者说明个人与教育项目免费，商业项目需另行授权。本次仅个人设计探索。
- 英文衬线使用 Georgia，中文正文使用系统字体；图标为手写 SVG。

## 操作

底部导航切换四页；首页入口进入聊天与日记；聊天发送文本、分享示例照片或心情；人物页收藏；日记筛选和详情 dialog（支持 Escape / 关闭按钮）。减少动态设置禁用动效；B 仅切页瞬间短暂位移，不持续闪烁。旧 index 已完整保留为 previous-directions.html。

## 验收边界

浏览器验证结果见 editorial-glitch-validation.json。Android/iOS 真机、Safari、软键盘与 GPU / 电量表现 not-run。
