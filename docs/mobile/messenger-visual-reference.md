# 微信单聊视觉数据

来源固定为 [Wechat-Chat-Interface](https://github.com/doubleZ0108/Wechat-Chat-Interface/tree/ab5e62c084b25f947388f884334f4afe07691f54)，读取 index.html 与 [style.css](https://github.com/doubleZ0108/Wechat-Chat-Interface/blob/ab5e62c084b25f947388f884334f4afe07691f54/static/css/style.css)。不导入原项目文件或 JS。

## 换算

外框宽350px；真正聊天视口为88%，即308px。外框、left6%、top3%属于手机模型图定位，不进入原生页面。Flutter 使用 s=实际聊天视口宽/308，将视口内部 CSS 尺寸乘s；390px时s=1.2662。不是用350px当聊天宽度。

| 项目 | CSS 原值 | 390px 视口 |
|---|---|---|
| 正文/标题 | 1.3rem，根10px，即13px | 16.46px |
| 头像 | 30×30px，圆角5px | 37.99px，圆角6.33px |
| 头像到气泡 | grid-gap12px | 15.19px |
| 外侧留白 | 12px | 15.19px |
| 每条消息上下 margin | 各10px | 各12.66px |
| 消息组最大宽 | 视口80%，包含头像与间距 | 312px |
| 气泡最大宽 | 80%视口减头像30s及间距12s | 258.82px |
| 气泡内边距 | 四边10px | 12.66px |
| 气泡圆角 | 7px | 8.86px |
| 尖角 | border8px，top10px，外移13px | 实际突出5s，半高8s，中心18s |
| 时间上下 margin | 各15px | 各18.99px |

CSS未声明line-height，Flutter按normal近似1.2；这是映射假设，不是原项目数值。

## 有效配色（媒体查询覆盖后的值）

| 区域 | 浅色 | 深色 |
|---|---|---|
| 聊天背景 | #E7E9EA | #0E0E0F |
| 接收气泡/文字 | #FDFFFF / #131415 | #202122 / #B7B9BA |
| 发送气泡/文字 | #84EC57 / #0C1415 | #24A94F / #04100A |
| 顶栏文字 | #121314 | #C3C4C6 |
| 时间文字 | #949596 | #404142 |

原项目顶栏底为rgba(236,237,238,.8)/rgba(14,14,15,.8)和10px模糊。原生顶部固定区域不叠在消息上，浅色表面使用#ECEDEE；不引入额外模糊动画。

## 真实截图补齐

原项目没有返回/更多按钮、底部输入栏、引用条、系统安全区与键盘适配。保留截图校准的56px顶栏操作区、48px输入区域、下置灰色引用栏、圆形关闭、录音/表情/附件位置。头像保持透明无描边。时间字号原值0.05rem=0.5px无法作为可读UI；继续使用截图校准12px。日期＋时间/10分钟显示规则来自用户要求，保持原逻辑。

气泡仍尊重已有透明度偏好，默认0.94，因此实际合成色可能与CSS不透明色不同；不改用户保存值。正文跟随正文字号，13s×配置字号/16；界面字号影响标题/引用/时间。参数位于 conversation_presentation.dart，CSS几何基准集中在 messengerCssPixels/messengerBubbleMaxWidth。

工单36记载验证；Flutter渲染图不替代真实设备逐像素验收。
