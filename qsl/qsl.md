# qsl 第二轮：功能加强 + 视觉美化

> 参考仓库：`qsl/quickshell-main.zip`（clavis-shell，308 QML / 67k 行）
> 原则：功能对齐有价值的部分，数据层自己优化，不照抄；视觉向 M3 靠拢但不引入重量级依赖。

---

## 功能计划

### P0（本轮核心）

#### 1. 锁屏（替掉 hyprlock）
- 使用 Quickshell `SessionLock` API（ext-session-lock-v1 协议）
- 手动触发：IPC `qs ipc call lock open` + Hyprland 绑定 `Super+L`
- PAM 密码验证
- 锁屏面板卡片：时钟(大字) / 日历 / 天气 / 音乐播放器(上一首/暂停/下一首) / 网络+蓝牙+声音状态 / Todo(只读) / 通知(只读)
- 模糊背景（截图 → GaussianBlur 或降采样模糊）

#### 2. 待办清单（Todo）
- 两级分类：标签(重要★/生活/开发/自定义) + 优先级(T0/T1/T2)
- "重要"为虚拟标签，汇总所有 `starred: true` 的条目
- 持久化：`~/.local/state/qsl/todo.json`
- UI 放左栏新 Tab（views: time / sys / keys / todo）
- 支持增删改、拖拽排序、标记完成

#### 3. 美化基础设施
- `Components/QslCard.qml`：统一卡片壳（title + icon + body slot + RectangularShadow）
- `Components/QslShadow.qml`：封装 RectangularShadow（cached:true，极低开销）
- `data/state/Style.qml`：统一 token（radius/spacing/fontSize/animation duration）
- 左栏/右栏/岛页面逐步迁移到 QslCard

### P1（紧随其后）

#### 4. 计时器 + 秒表
- 正计时（计时器）：从 0 开始，手动停止
- 倒计时（秒表）：设定 N 分钟，时间到 → pushNotifToast → 灵动岛通知
- UI 放左栏时间页下方折叠区域
- 持久化状态到 `~/.local/state/qsl/timer.json`（防 qs 崩了丢进度）

#### 5. Web 搜索（Super+X）
- 独立 FreeWindow，屏幕中上方窄长条
- 输入框 + 下拉引擎选择（Google/Bing/Baidu）
- 搜索建议：debounce 300ms → fetch suggest API → 下拉列表
- Enter → xdg-open 跳浏览器
- IPC: `qs ipc call websearch toggle`

#### 6. 天气页改造
- 去掉天穹图
- 加 MetricTile 小组件（体感温度/湿度/风速）
- 可选：静态地图（OSM tile + 天气叠加层，不做拖拽，4-9 张 256px 图）
- 布局参考 clavis WeatherContent 的三列紧凑风格

#### 7. 歌词优化
- ListView contentY 改用 SpringAnimation（弹簧滚动）
- 封面图加圆角（clip:true + radius 方案，不用 layer.enabled）
- 活跃行放大/高亮动画

### P2（后续迭代）

#### 8. GIF 录制 + 岛上红点
- 底层：wf-recorder + gifski
- 区域选择：复用 slurp 或 QML 原生版
- 岛内：录屏时右上角 pop 出小红圆 + 计时，点击停止
- "细胞分裂"动画：ScaleAnimation + 位移

#### 9. 左栏/右栏 UI 重构
- 用 QslCard 替换现有半透明 Rectangle
- 统一图标用 Material Symbols 字体
- Slider/Switch/Button 用自绘组件替代
- app 页面保持半透明（特殊页面视觉区分）
- 剪贴板保持半透明

#### 10. 设置面板
- 独立窗口（ControlCenter），IPC `qs ipc call settings open`
- 导航 Rail + 页面 Loader
- 功能：编辑 hotkeys.json / 法定节假日 / 清除磁盘缓存 / 快速重启 qs / 修改服务配置
- 动态架构图：Canvas 画模块节点 + 数据流连线，鼠标悬停显示描述

### P3（远期）

#### 11. 架构可视化白箱（动态版）
- 反射 qs 组件树，live 显示窗口/服务/数据流
- 虚拟显示器画布，鼠标交互浏览
- 不需要懂代码细节也能看懂的白箱

---

## 美观方向

### 核心原则
- 视觉向 Material 3 靠拢：统一 radius / spacing / color token / 卡片层次
- **不用** QtQuick.Controls.Material（太重）；自绘轻量组件
- **不用** layer.enabled / OpacityMask（除非单个小图标圆角）
- **用** RectangularShadow（cached:true，纯几何阴影，极低开销）
- **用** Behavior on / SpringAnimation / NumberAnimation（不用 ShaderEffect）

### 具体改进
| 位置 | 当前 | 目标 |
|------|------|------|
| 卡片 | 半透明 Rectangle | QslCard + Shadow + border + 内发光 |
| 岛 morph | 基础尺寸+圆角过渡 | 学习音量 OSD / 歌词弹簧 |
| 天气 | 静态列表 + 天穹图 | MetricTile + 可选地图 + 渐变天空背景 |
| 歌词 | 普通 ListView | SpringAnimation + 活跃行缩放 |
| 封面 | 方形 | 圆角 clip |
| 滑块/开关 | 系统默认 | 自绘 M3 风格 |
| 图标 | 混用 | 统一 Material Symbols Outlined |

---

## 性能红线
- RSS 稳态 ≤ 400MB（当前 ~300MB，留余量给新功能）
- 无常驻轮询（所有 Timer 必须 gated）
- 新页面遵循单 Loader 按需加载
- Image 必须设 sourceSize + asynchronous
- 锁屏面板关闭时完全销毁（不常驻）

---

## 不做
- 空闲策略 / hypridle UI
- 录屏/录音（专业交给 OBS）
- Rclone / NAS（未来独立做）
- i18n
- 亮度控制（硬件兼容性差）
