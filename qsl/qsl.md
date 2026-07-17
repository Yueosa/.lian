# qsl 重构计划

> `qsl` 是 `quickshell/` 的第二代实现。目标不是平移旧代码，而是以 UI 为单位重写：
> 数据层换成更轻的 Rust/backend 或 Quickshell 原生绑定，UI 只保留真正需要的部分。

---

## 当前状态

- 日用 shell 仍然是 `quickshell/`。
- `qsl/backend/` 保留，作为新数据层的基础。
- 旧的 `qsl` QML 脚手架已经删除，UI 从空目录重新开始。
- `data/service` 暂不提前补齐；迁移某个 UI 时，只写它实际需要的服务封装。

---

## 核心目标

1. 降低 Quickshell 进程里的长期内存占用。
2. 把 `/proc`、HTTP、60fps 文本解析、外部命令轮询这类脏活移出 QML。
3. UI 按窗口/模块迁移，顺手砍掉旧版里不再需要的功能。
4. 数据契约稳定后再接 UI，不为了兼容旧 shell 堆 shim。
5. 保持个人桌面优先：只服务当前机器和当前工作流。

---

## 目标架构

```text
system / dbus / http / pipewire
        |
        v
backend/                 Quickshell native bindings
Rust daemon / CLI         Network / Bluetooth / UPower / Mpris / PipeWire ...
        |                                |
        v                                v
data/service/  ------------------>  ui/
薄封装、缓存、单位换算              PanelWindow / Item tree
```

### 规则

- `ui/` 可以 import `data/`、`component/`、`asset/`。
- `data/` 不 import `ui/`。
- `backend/` 不依赖 QML 引擎。
- `shell.qml` 只组装窗口，不写业务逻辑。
- 同级 UI 模块之间不直接依赖；共享状态进 `data/`。

---

## backend 数据层

`qsl/backend/` 是当前已经成型的部分。

| 模块 | 形式 | 输出/接口 | 状态 |
|---|---|---|---|
| `sysmon` | `sysmond` daemon | `$XDG_RUNTIME_DIR/qsl/sysmon.json` + cmd 文件 | 已实现，继续打磨 |
| `cava` | `cava-relay` daemon | `$XDG_RUNTIME_DIR/qsl/cava.bin` | 已实现，仍依赖系统 `cava` |
| `weather` | `weatherd` daemon | `~/.cache/qsl/forecast.json` + cmd 文件 | 已实现，继续打磨 |
| `lyrics` | `lyrics-fetch` CLI | stdout JSON | 已实现，待 UI 需要时接 |

### 质量要求

- 输出文件使用原子写入。
- daemon 不做无意义高频写入。
- 网络/磁盘/进程等字段必须名字和单位一致。
- 外部 API 响应异常时不能 panic。
- 命令文件读取尽量避免清空时吞掉新命令。
- 日志写 stderr，保持 stdout 可作为机器输出。

---

## data 层策略

不再一次性提前写完整 `data/service`。

迁移某个 UI 时：

1. 列出它实际需要的数据。
2. 先看 Quickshell 是否已有原生绑定。
3. 原生绑定足够时，写薄 QML singleton。
4. 原生绑定不够时，接 `backend/` 的 Rust 输出。
5. 服务接口稳定后再写 UI。

`data/service` 文件头需要写清：

- 对外属性和方法。
- 数据来源。
- 刷新频率。
- 单位。
- 可能触发的外部进程或文件监听。

---

## UI 分层

桌面 UI 按交互面分成七层：

| # | 层 | 内容 | 触发 / 位置 |
|---|---|---|---|
| 1 | **FreeWindow** | SUPER+A / Z / X 唤出的三个独立页面 | 快捷键弹出 |
| 2 | **Left Sidebar** | LianClaw、System（sysmon）、Weather | 左侧滑出 |
| 3 | **Right Sidebar** | 网络、蓝牙、音频、Update | 右侧滑出 |
| 4 | **Notification Center** | 通知中心 | 右下角 |
| 5 | **Left Bar** | 工作区 + 当前窗口名 | 左上角 |
| 6 | **Right Bar** | Tray + 状态栏 | 右上角 |
| 7 | **Dynamic Island** | 展开后含系统信息、壁纸、天气、窗口、媒体等页 | 屏幕中央 |

### UI 原则

- 以 UI 为单位迁移，不以旧文件为单位搬运。
- 旧 UI 的视觉可以参考，但结构不照抄。
- 每个顶层 UI 默认是一个 `PanelWindow` 或明确的窗口边界。
- 复杂模块用 `Loader` 控制生命周期，默认不常驻。
- 高频变化避免长 Binding 链，必要时集中计算后暴露简单属性。
- `ListView` delegate 数量要可控，避免大模型全量实例化。
- 图片资源默认考虑缓存和异步解码成本。

---

## 实现顺序

按 `1 → 5 → 6 → 7 → 2 → 3 → 4`：

1. **FreeWindow** — SUPER+A / Z / X 三个页面
2. **Left Bar** — 工作区 + 当前窗口名
3. **Right Bar** — Tray + 状态栏
4. **Dynamic Island** — 系统信息 / 壁纸 / 天气 / 窗口 / 媒体等展开页
5. **Left Sidebar** — LianClaw / System / Weather
6. **Right Sidebar** — 网络 / 蓝牙 / 音频 / Update
7. **Notification Center** — 右下角通知中心

当前起点是第 1 层 FreeWindow，且先只做 **App（Super+A）**。

---

## 第 1 层计划：FreeWindow / App（Super+A）

### 目标产品

三页面彻底拆开。本阶段只做 App 启动器：

- 视觉：沿用旧 `quickshell` UnifiedLauncher 的 App 页（左 60% 壁纸预览 + 右 40% 搜索/列表）。
- 删除：顶部三 Tab 图标、`Tab 切页 · Esc 关闭` 按键提醒。
- 保留/增强动画：
  - 窗口入场 OutBack / 退场 InBack（已删 FreeWindow 壳）
  - 列表 Up/Down 选中高亮移动动画
  - 选中 / Enter 时图标与文字的放大动画
- 不迁 Clipboard / Emoji；它们之后各自独立 FreeWindow。

### 参考来源

| 来源 | 取什么 | 不取什么 |
|---|---|---|
| `quickshell/Modules/Launcher/UnifiedLauncherWindow.qml` | 16:9 几何、60/40 布局、壁纸预览、左边标题文案、圆角边框 | Tab bar、Tab 快捷键、三页 Loader、Overlay remapper（先按需） |
| `quickshell/Modules/Launcher/AppPage.qml` | 搜索框、列表 delegate、启动逻辑、图标兜底 | 底部 `Up/Down · Enter` 提示可删；50ms 轮询等旧脏逻辑 |
| `quickshell/JS/AppManager.js` | fuzzy 搜索、usage 排序、图标 normalize、IM 资源映射、结果上限 50 | 直接依赖 `qs.config` |
| 已删 `qsl/ui/freewindow/*` | FreeWindow 壳动画、事件驱动 DesktopEntries、ListView transition、Usage 落盘思路 | 简化过头的搜索/排序、底部按键提示、与旧 UI 不一致的细节 |

### 目录草案

```text
qsl/
├── shell.qml
├── data/
│   ├── state/
│   │   ├── Color.qml          # 从已删版本恢复并作为颜色真源
│   │   └── Size.qml           # 从已删版本恢复并作为尺寸真源
│   └── freewindow/
│       └── app/
│           ├── Apps.qml       # DesktopEntries + usage + 搜索/排序对外接口
│           └── AppSearch.js   # 从 AppManager.js 迁过来的纯函数
├── ui/
│   └── freewindow/
│       ├── FreeWindow.qml     # 共用弹出壳：几何/动画/Esc/焦点
│       └── app/
│           ├── AppWindow.qml  # Super+A 窗口：壁纸 + AppPage
│           └── AppPage.qml    # 搜索 + 列表 + 选中动画
└── asset/                     # 已有 app-logo 可复用
```

### 样式层

`Color` / `Size` 是 App 的前置依赖，先恢复，再写 UI。

- `Color`：继续 matugen / light / dark；App 只用语义色
  - 卡片：`surfaceHigh`
  - 搜索框：`surfaceHighest` / `surfaceVariant` 半透明
  - 高亮：`primary` + `onPrimary`
  - 正文/次要：`onSurface` / `onSurfaceVariant`
  - 边框/阴影：`outlineVariant` / `shadow`
- `Size`：圆角、间距、字号、字体家族全部从 token 取，禁止硬编码散落。
- 壁纸预览：短期直接读 `~/.cache/wallpaper_rofi/current(_preview)`；等后面做 Island/壁纸模块时再抽到 `data/state` 或 service。

性能注意：

- 壁纸 `Image` 设 `sourceSize`，避免原图解码进 qs。
- 关闭窗口后可用短缓存（旧版 15s）避免反复 Loader 重建，但不要长期常驻整棵树。

### 数据层

不要把搜索/排序塞进 UI。建议拆成：

1. **`data/freewindow/app/Apps.qml`**
   - 源：`DesktopEntries.applications`
   - usage：`~/.cache/qsl/app_usage.json`
   - 字段建议保留旧版 `count`，并吸收 FreeWindow 的 `last`（可选展示“多久前”）
   - 对外：`ready`、`allApps`、`usageMap`、`recordLaunch(name)`、`search(query) -> list`
   - 事件驱动重建；禁止旧 AppPage 的 50ms 轮询 Timer

2. **`data/freewindow/app/AppSearch.js`**
   - 从 `AppManager.js` 迁：
     - `fuzzySearch`
     - usage 优先 + 名称 A-Z
     - `normalizeIconMeta`
     - bundled app-logo 检测（telegram/wechat/discord/qq）
     - 结果截断 50
   - UI 只消费已经整理好的 `{ name, icon, fallbackIcon, forceGlyph, materialGlyph, assetAppId, appObj }`

3. **启动**
   - 优先 `appObj.execute()`
   - fallback `execString` / `gtk-launch desktopId`
   - 成功后 `recordLaunch`，再关窗

### UI 层拆分

1. **`FreeWindow.qml`**
   - 全屏透明 PanelWindow
   - 16:9 card、slide 动画、Esc、exclusive keyboard focus
   - `default property` 承载内容
   - 只做壳，不感知 App/Clipboard/Emoji

2. **`AppWindow.qml`**
   - 左壁纸 + 标题文案（固定“启动器”，不再随 Tab 变）
   - 右 `AppPage`
   - open 时聚焦搜索框；launch/Esc 关窗
   - 点击遮罩关窗

3. **`AppPage.qml`**
   - 视觉跟旧 AppPage
   - 删掉顶部 Tab 区（本来就不在 AppPage，而在外壳）
   - 删掉底部按键提示
   - 动画：
     - `highlightMoveDuration` > 0
     - 列表 add/remove/displaced transition
     - 当前项图标/文字 `scale` Behavior；Enter 时可短促 scale pulse
   - 键盘：Up/Down 选择，Enter 启动，Esc 关窗；左右翻页可选保留

### 实现步骤

1. 恢复 `data/state/Color.qml` + `Size.qml`，补 qmldir。
2. 迁 `AppSearch.js` + 写 `Apps.qml`，先不接 UI 也能验证搜索/排序。
3. 写 `FreeWindow.qml` 壳，用空内容验证开合动画与 Esc。
4. 写 `AppWindow` + `AppPage`：旧布局 − Tab/提示 + 新动画。
5. `shell.qml` 只装 AppWindow；Hyprland bind Super+A → `qs ipc` / 等价入口。
6. 跑通后再开 Clipboard / Emoji 两个独立 FreeWindow。

### 本阶段明确不做

- 不复刻 UnifiedLauncher 三合一
- 不提前写 Clipboard/Emoji 页
- 不接 sysmon/weather/cava
- 不把 Color/Size 做成“兼容旧 Colorscheme 全字段”的巨型 shim；只保留 qsl 语义 token

---

## 明确可砍方向

- 只为“看起来完整”存在的页面可以删。
- 旧 UI 中重复展示同一数据的入口可以合并。
- 需要常驻大量 delegate 或图片缓存的模块必须重新设计。
- 依赖 Python/Bash 采集数据的路径优先删除或收进 backend。
- 没有日常使用场景的实验性窗口不迁。

---

## 下一步

1. 确认本计划后，从 FreeWindow App 开工。
2. 先补 `Color` / `Size` / `Apps`，再写窗口壳与 AppPage。
3. `shell.qml` 只实例化 AppWindow。
4. App 稳定后再做 Super+Z / Super+X。
