# Flow 视觉与技术研究

仅本地视觉稿，无跨端影响。用户后续更正目标为梦境聊天：流体是背景，聊天框是厚玻璃本体。官方表盘用于颜色、透射关系与边缘结构对照，聊天布局不是原版表盘复刻。

## 官方观察

https://www.apple.com/newsroom/images/2025/09/apple-debuts-apple-watch-series-11-featuring-groundbreaking-health-insights/article/Apple-Watch-Series-11-aluminum-rose-gold-250909_inline.jpg.large.jpg

深黑负空间占主导。紫红光团围绕洋红与蜜桃粉金流体，玻璃区域常保留近黑中心；颜色穿过曲面，边缘有很细的浅色亮线和较宽的彩色透射带。不是均匀磨砂。official-reference.jpg 仅用于对照页，主渲染器不读取图像。

## 读过的实现

1. https://github.com/aaaa-zhen/glsl-playground/blob/main/liquid-glass.html
   SDF 梯度、circleMap 曲面位移、RGB 独立偏移采样、黑镜面、内暗边、细亮线；原实现包含模糊 pass，本稿不使用模糊替代折射。
2. https://github.com/Oliverrr2424/webgl-apple-liquid-glass/blob/main/src/shaders.js
   厚度 h = sqrt(1-(1-t)^2)，dh/dt 推导曲面斜率；meniscus 法线让边缘采样向外压缩；refract() 按 Snell 计算射线；不同 IOR 得到 RGB 色散；Schlick Fresnel 和高光加强厚边。

## 本稿管线

flow.js 自写双 pass，不复制参考库。第一 pass 以变形椭圆环与折叠流体色带产生背景，写入 RGBA8 framebuffer。第二 pass 根据 DOM 的圆角聊天框位置构造 SDF，计算厚度、法线和折射射线，再按实际偏移坐标采样同一背景纹理。深色透射、Fresnel、窄高光和内暗缝一起构成厚玻璃。

色散保持克制；透射中心较暗，避免流体淹没文字。所有主参数集中在 DEFAULTS；背景颜色、厚度、反射和速度也可在界面设置中修改。无 CSS blur/backdrop-filter/box-shadow。CSS 只负责文字与布局。

限制：二维屏幕空间近似，不是物理体积路径追踪；没有手表硬件和原版数字几何；采用更正后的聊天生态位设计。主渲染没有官方图贴图，不依赖字体下载或外部 CDN。

## 追加流体参考与范围确认

实际克隆并运行 https://github.com/nonlineartom/gradient-backdrops ，commit ddad93da04280f83f3cf25898a1f1cbdf001385e。读了 assets/backdrop.js 的 flow/swirl Shader 和 references/techniques.md：flow 是低频两 octave simplex 的三层 domain warp，经 OKLab 色带映射；swirl 是随距离衰减的局部旋转，加噪声扰动。外部研究页同时运行两个模式，截图 reference-runtime.jpg，console 无 error/warn。第三方源代码未复制进交付目录。

用户后续明确「我们的卷曲已经可以了」，要求保持手机长方形里的纵向卷曲，不改为官方球体。于是保留现有卷曲模型，只借鉴动态场的连续形变思路和运行调度；不把参考库的满屏渐变直接套入。

https://www.youtube.com/watch?v=cDquGF6bGM0 已打开并看到播放器首帧，标题 watchOS 26 Every NEW Watch Face - A Deep Dive LOOK；播放及读取状态多次超时。连续实机动画尚未核验，不能报告为已观看。