# qsl 第二轮：功能加强 + 视觉美化

> 参考仓库：`qsl/quickshell-main.zip`（clavis-shell，308 QML / 67k 行）
> 原则：功能对齐有价值的部分，数据层自己优化，不照抄；视觉向 M3 靠拢但不引入重量级依赖。

---

## 功能计划

### P0（本轮核心）

#### 1. 锁屏（替掉 hyprlock） — WIP / BUG
- [x] 使用 Quickshell `SessionLock` API（`WlSessionLock`）
- [x] 手动触发：IPC `qs ipc call lock lock` + Hyprland `Super+L`
- [ ] PAM 密码验证（卡在「验证中」，待修）
- [ ] 锁屏面板卡片：时钟 / 日历 / 天气 / 音乐 / 状态 / Todo / 通知
- [ ] 模糊背景（截图 → blur；当前仅纯色，有意轻量）

#### 2. 待办清单（Todo） — 基本完成
- [x] 两级分类：标签(重要★/生活/开发) + 优先级(T0/T1/T2)
- [x] 「重要」虚拟标签（`starred`）
- [x] 持久化：`~/.local/share/qsl/todo.json`
- [x] 左栏 Tab（time / sys / keys / todo）+ IPC 别名
- [x] 增删改、标记完成 / 收藏
- [ ] 拖拽排序（未做）

#### 3. 美化基础设施 — 基本完成
- [x] `Components/QslCard.qml`
- [x] `Components/QslShadow.qml`（纯 Rectangle 多层阴影；禁入 ListView）
- [x] `data/state/Style.qml`
- [x] 左栏/右栏壳 + App/Clipboard 轻量对齐 Style / 自绘控件（详见 #9；岛页仍逐步）

### P1（紧随其后）

#### 4. 计时器 + 秒表 — 完成
- [x] 正计时（秒表）+ 倒计时（预设时长）
- [x] 倒计时结束 → `notify-send` → 通知链路 / 灵动岛
- [x] UI：时间页底部折叠面板（圆盘保持居中）
- [x] 持久化：`~/.local/share/qsl/timer.json`
- [x] 性能：1s tick，仅运行时开启

#### 5. Web 搜索（Super+X） — 完成
- [x] 独立窄长条窗口
- [x] Google/Bing/Baidu 引擎切换
- [x] 搜索建议 debounce 300ms + up/down 选择
- [x] Enter → `xdg-open`
- [x] IPC: `websearch toggle/open/close`

#### 6. 天气页改造 — 完成（地图可选未做）
- [x] 去掉天穹图（及 Astro / 60s Timer）
- [x] 加 MetricTile 小组件（体感/湿度/风速/气压）
- [ ] 可选：静态地图（OSM tile，不做拖拽）— 暂缓
- [x] 上排当前天气卡 + MetricTile 网格，下排预报保留

#### 7. 歌词优化 — 基本完成
- [x] 活跃行缩放 SpringAnimation + 颜色过渡
- [x] 一级岛封面正圆（OpacityMask）；Hub 封面保持圆角方块
- [x] 波浪进度条（振幅/频率对齐参考仓库）
- [ ] ListView 滚动完全改 SpringAnimation（当前仍用 highlightMoveDuration）

### P2（后续迭代）

#### 8. GIF 录制 + 岛上红点
- 底层：wf-recorder + gifski
- 区域选择：复用 slurp 或 QML 原生版
- 岛内：录屏时右上角 pop 出小红圆 + 计时，点击停止
- 「细胞分裂」动画：ScaleAnimation + 位移

#### 9. 左栏/右栏 UI 重构 — 基本完成（视觉收口：对齐 Hub）
- [x] 原子控件：`QslSwitch`（**禁命名 scale**，用 `sizeScale`）/ `QslSlider` / `QslIconButton` / `QslChip` / `QslHubTab`
- [x] 面板底：`Color.background` **实色**（左/右栏、App 右栏、NotifCenter），去掉 sidebarAlpha/panelAlpha
- [x] Tab：`QslHubTab`（图标+标题+底指示条，同 Island Hub；FA + fontMono）
- [x] 内层卡：`Color.surface` / `surfaceHigh` 实色；ListView 仍禁阴影
- [x] Clipboard：**仍半透明**（例外）
- [x] 顶栏：Tray 折叠（常驻 qq/微信/fcitx/splayer）+ SysMonitor（RAM→hover CPU/GPU）+ SettingsPill
- [ ] 右栏功能向 zip 深对齐 / QuickSettings 簇（可选下一轮）
- Island Hub 本身不改（它是对齐目标）

#### 10. 设置面板
- [x] 入口：顶栏最右 SettingsPill + IPC `qs ipc call settings open/toggle/close`
- [x] ControlCenter **占位窗**（FreeWindow）
- [x] 导航 Rail + 单页面 Loader（关窗销毁）
- [x] 首页：动态架构图（静态节点/边 + hover + 深链）
- [x] 维护：重启 qs / 清 `~/.cache/qsl` / 开目录；打开页采一次 RSS·cava
- [x] 本地文件页：键位 / 节假日摘要 + `kitty -e nvim`（IPC 别名 hotkeys/calendar→files）
- [ ] （可选）架构图更多深链 / 维护里一键清 cava 孤儿

### 内存备忘（2026-07）
- **两笔账**：qs 进程 RSS ≠ 系统总涨。cava python reader 孤儿另计（曾堆 20+ 个 ≈350MiB）。
- qs 冷启空闲曾见 ~670MiB；内存轮后约 **~550MiB**（Private_Dirty ~275MiB）。大头仍是 anon + LLVM + NVIDIA + CJK。
- cava 清理：匹配 cmdline 中的 `/ 'qsl' / 'cava.bin'`（用 `/ '[q]sl' / 'cava.bin'` 防自匹配）；启动 / acquire / release→0 都清。**勿**再用字面量 `qsl/cava.bin`。
- Tray：栏上/overflow 仅 `Loader.active` 时建 TrayItem+Image；未 pin 不占解码缓存。
- Island DropShadow：`cached: true`（阴影源跟岛体；非 gooey/blur）。
- **不要**为省内存把 QML service 批量 Rust 化（薄封装；重活已在 cava-relay/sysmond/weatherd）。
- 调试请用默认 `qs`（`~/.config/quickshell` → qsl），勿 `qs -p ~/.lian/qsl`（IPC Path ID 对不上）

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
- **不用** layer.enabled / OpacityMask（除非单个小图标/圆形封面）
- **用** 几何阴影（QslShadow / RectangularShadow），极低开销
- **用** Behavior on / SpringAnimation / NumberAnimation（不用 ShaderEffect）

### 具体改进
| 位置 | 当前 | 目标 |
|------|------|------|
| 卡片 | 半透明 Rectangle | QslCard + Shadow + border |
| 岛 morph | 基础尺寸+圆角过渡 | 学习音量 OSD / 歌词弹簧 |
| 天气 | ✅ MetricTile + 当前卡 + 预报 | 地图可选（暂缓） |
| 歌词 | ✅ 活跃行弹簧缩放 | 可选进一步 Spring contentY |
| 封面 | ✅ 岛正圆 / Hub 方块 | — |
| 滑块/开关 | ✅ QslSlider / QslSwitch | 可选更细交互反馈 |
| 图标 | ✅ 左右栏/App/Clipboard/顶栏 Settings Material | QuickSettings 簇可选 |

---

## 性能红线
- RSS 稳态目标 **≤ 550MB**（本轮实测冷启空闲约此；早期 400MB 红线暂作下一轮，需再砍岛/字体/常驻窗）
- 系统侧：`python … cava.bin` reader 稳态 **0 或 1**（仅 acquire 时）
- 无常驻轮询（所有 Timer 必须 gated）
- 新页面遵循单 Loader 按需加载
- Image 必须设 sourceSize + asynchronous；Tray 隐藏项禁止常驻 Image
- 锁屏面板关闭时完全销毁（不常驻）

---

## 不做
- 空闲策略 / hypridle UI
- 录屏/录音（专业交给 OBS；GIF 另议）
- Rclone / NAS（未来独立做）
- i18n
- 亮度控制（硬件兼容性差）
