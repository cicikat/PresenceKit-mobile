# 手机端颜色预设与 Mod

手机端颜色 mod 是纯 JSON 数据，只描述颜色，不包含 CSS、脚本、组件代码或布局覆盖。桌面端主题只能作为设计参考，桌面 `theme.css` 不会在 Flutter 中执行。

## 浏览器预览工作流

1. 双击仓库根目录的 `电脑浏览器预览.bat`。
2. 打开“设置 → 外观主题 → 颜色预设”，新建或编辑预设。
3. 自由选色支持饱和度/明度面板、色相、透明度、RGB 数值和 `#AARRGGBB`。
4. 点击“导出 mod”，浏览器会下载 `*.mobile-theme.json`。
5. 手动把文件放进仓库根目录 `mods/`。
6. 重新构建 APK；`mods/` 中合法 JSON 会作为只读预设随应用打包。

浏览器不能在无授权的情况下直接写入仓库，所以“下载后手动放进 `mods/`”是有意保留的安全边界。浏览器编辑草稿保存在当前浏览器的 localStorage；Android 用户预设仍保存在应用私有设置中。

## 文件契约

```json
{
  "schema": "presencekit-mobile-color-mod",
  "version": 1,
  "id": "my-theme",
  "name": "我的配色",
  "base": "light",
  "colors": {
    "surface": "#FFECE3D0",
    "surfaceSoft": "#FFF1E8D6",
    "surfaceDeep": "#FFE3D7BF",
    "surfaceEdge": "#FFD0BF96",
    "ink1": "#FF2A1F18",
    "ink2": "#FF5A4A3A",
    "ink3": "#FF8A7A66",
    "ink4": "#FFB5A88E",
    "character": "#FF1F3A2E",
    "characterDeep": "#FF14271F",
    "characterSoft": "#FFDCE3D6",
    "characterOn": "#FFF1E9D6",
    "danger": "#FF8B3A2B",
    "warn": "#FFB8893A",
    "ok": "#FF4A6B40",
    "send": "#FFB6553F",
    "userBubble": "#FF1F1812",
    "userBubbleText": "#FFECE3D0",
    "scrim": "#990F0B07"
  }
}
```

- `schema` 和 `version` 必须与示例一致。
- `id` 只能使用英文字母、数字、点、下划线和连字符，且必须唯一。
- `base` 只能是 `light` 或 `dark`。
- 19 个颜色键全部必填；格式为 `#AARRGGBB`，也接受不含透明度的 `#RRGGBB`。
- 无效文件会被忽略，不阻止应用启动。

## 预设行为

- 本机预设可以保存多个，并可切换、重命名、重置颜色和删除。
- `mods/` 打包进来的预设是只读的；选择“复制并编辑”会创建本机副本。
- 旧版单一 `customThemePalette` 会在首次读取时自动迁移为“旧版自定义”预设。
- “重置颜色”按该预设的 `base` 恢复到内置信纸或夜间色盘，不删除预设名称。
