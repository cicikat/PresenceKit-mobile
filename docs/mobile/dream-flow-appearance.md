# 梦境流体外观（工单 33）

新增 `DreamLayout.theatre`（金色剧场 / 经典卷曲）和 `orbit`（靛蓝轨道 / 伪随机流体）。原经典、月夜及未知值回退仍保留。Flutter 原生 `dream_flow.frag` 直接生成背景并在真实气泡/输入栏区域重采样产生曲面 RGB 折射；不使用 WebView、截图背景或复制桌面 JSX。域扭曲和卷曲轮廓源于 Flow 视觉稿，噪声明暗为移动端原生近似，非物理流体仿真。

日间默认浅蓝紫、浅蓝与白色，夜间默认偏蓝紫。日夜颜色各三个槽；速度、尺寸、扭曲、玻璃厚度与边缘反射可调；伪随机模式另有种子。参数改变即在同一原生渲染器预览。动画由组件 Ticker 管理；后台、不可见路由、系统减少动态效果与速度零均停止。Shader 不可用时显示同配色静态渐变和可读面板。

入口：设置 → 外观与显示 → 夜间外观主题之后的「梦境外观主题」。可切换两个预览主题和日夜，保存、另存为新预设及选用；修改已选自定义预设后保存即更新该主题。默认预设不可覆盖，修改后保存生成自定义副本。编辑未保存时不影响实际背景；选用会先保存草稿再应用。关闭子窗口回父设置。原梦境设置中的梦境 UI 内容全部迁入此处，原字号/颜色/描述透明度和图片槽不重置；图片仍供经典/月夜使用，流体主题按选中的预设渲染。

状态所有权：`DreamAppearanceController` 只持有本机预设、每种流体主题的选用 ID；`ThemeController` 持有日夜模式与梦境布局，并通过原有主题 JSON 存储其 snapshot。`ProfileAppearanceController` 继续持有原字号/文本颜色/图片 prefs。预设不包含角色记忆、Dream 会话状态或业务配置。

持久结构：原 `presencekit-mobile-color-presets` v1 增加可选 `dreamAppearance` v1，含 `presets` 和 `selected`；每个预设含 id/name/layout、日夜颜色、参数。旧 JSON 自动使用两种内置默认；未知版本或坏条目回退，数值有界。读写仍走 `getCustomThemePalette` / `setCustomThemePalette` 的不透明字符串；Android 保留 `yexuan_memery`/`customThemePalette`，确认落盘成功才应答，新预设保存失败不假装生效；既有日常主题运行时降级语义保留。手机网页沿原有 theme localStorage 保存相同 JSON。

三面闭环：后端管理面不需要开关/default/effective/audit，因为这些是本机呈现偏好，不是能力权限。桌面不需要同步，Android 无新增权限/前台服务/通知行为；本机编辑器读选用预设并预览全部保存参数，既有 `getCustomThemePalette` 提供只读观测，无新队列/trace/业务台账。输入 → DreamController → `/dream/enter|chat|exit` → 原 segments/reveal → UI 的请求、鉴权、关联键和迟到响应守卫不变；poll/ack/去重/TTL/fallback 未改，主题切换不重置草稿或会话，不改后台通知链。

验收证据见工单 33 与相关测试。真实手机 GPU、输入法、相册/OEM、重启恢复及功耗仍 observe/not-run；浏览器、夹具与 Dev 构建不能代替真机体验。
