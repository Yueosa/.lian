# qsl 设计语言重构 plan

学习 caelestia-shell，统一 qsl + hypr 的动画与布局语言。

## 设计语言

术语（2026-09-02 统一）：island=灵动岛（顶部中央）；leftbar/rightcar=
顶左/顶右段栏；leftrail/rightrail/bottomrail=三边 rail 条；
面板：C=左附栏、V=右附栏、A=应用启动器、Z=剪贴板、X=磁贴、N=通知、
powerbar=电源（预告）。

- 四个锚点：顶左栏、顶右栏、灵动岛（顶部居中）、底栏 rail
- 所有面板从锚点"滑出/展开"，不再有屏幕中间的独立卡牌
- 面板贴住锚点栏，接缝 0 边距 + 凹耳朵衔接，无亮边框、无卡牌阴影
- 动画全局统一 M3 expressive 曲线（长尾沉降 + 位移过冲），qsl 与 hypr 同族

## 锚点映射

| 锚点 | 滑出内容 |
|---|---|
| 顶左栏（工作区+窗口名） | C |
| 顶右栏（托盘/硬件/多媒体） | V |
| 灵动岛 | Hub 五页（overview/media/wallpaper/weather/switcher） |
| 底栏·居中 | A（应用）、Z（剪贴板）、X（磁贴，新建） |
| 底栏·右角 | N（通知） |

## 已拍板的决策

1. N 从底栏右角滑出
2. A/Z 取消壁纸展示，纯容器，Win11 效果；宽度到时参考 caelestia 实际效果再定
3. 底栏 rail 纯装饰，保持 8px 窄条，不放内容
4. hypr `gaps_out`: 12 → 6
5. 窗口动画先用 400/500ms，不习惯再调
6. hypr 单独一轮改完，验证手感后再动 qsl
7. 岛 hub 尺寸策略：同宽不同高（统一宽度，高度随 tab 变，单轴变形）；
   各页压高度，weather 这类压不动的允许接近 4:3
8. 岛 morph（tab 间 resize）用 decel 不弹；打开/关闭保留 spatial 弹性
9. tab 内容过渡：顺序淡入淡出打底（旧页 150ms 淡出销毁→新页 200ms 淡入），
   零额外内存；小组件入场动画作为后续可选增强
10. 内存调查排最后一轮（第 12 轮，qs 700MiB→1GiB 的膨胀来源）
11. 结构与内容分轮：第 4 轮只管面板贴栏（结构/外壳），
    内容/排版原计划单列一轮；岛内容重构（第 8 轮）先行趟规范
    —— 2026-09-04 修订：内容 M3 化不再单列成轮，已拆散（见第 6 轮开头的撤销说明）
12. 面板互斥按屏幕区域分组，不做全局互斥（2026-09-04）：互斥的理由是物理
    重叠 + 抢独占键盘焦点，不重叠的面板没有理由互斥。组见架构约定第 6 条
13. 合并框窗（原 rail 脉冲/水波路线 A）提前到面板迁移之前做（2026-09-04）：
    A/Z/X 若先按独立窗迁移，合并时要重做一遍
14. 「可能为空」的卡片出场/收起有统一标准，见架构约定的容器占位规则
15. 轮次编号 = 执行顺序，但**第 1–4 轮的编号永久冻结**（2026-09-04 重排定规）：
    git commit message 里已经写了「plan 第 2 轮」「plan 第 4 轮首站」这类引用
    （`55647e7` / `d6ea988` / `2a0521f` / `22e2d7a`），改编号会让历史说谎。
    第 5 轮及以后没被 git 引用过，可以自由重排。所以第 4 轮那条要等合并框窗的
    尾巴（A/Z/X/powerbar）是**摘出去**成第 7 轮，而不是把第 4 轮改号
16. island 并入合并框窗（2026-09-04）：岛从 bar 派生展开，而 bar 正在合并；
    跨窗协调本来就是第 6 轮存在的理由（rail 水波/脉冲就死在跨窗上），把岛留在外面
    等于问题只解决一半。连带后果：第 8 轮岛 hub 的 morph 曲线要按窗内 item
    重调，所以第 8 轮必须排在第 6 轮之后

## 架构约定（2026-09-04 成文）

分层：`data/service` = 外部世界（NM / BlueZ / Pipewire / 进程 / 文件）；
`data/state` = 主题、尺寸、会话状态；`Components` = 无业务的通用件；
`ui/*` = 面板与卡片。

1. **UI 不解引用服务对象。** 服务层可以把 Quickshell 的活对象当不透明句柄交给
   UI（信号强度、音量要能实时更新，拍成快照就死了），但 UI 只许把它原样传回
   服务层的取值函数：`Network.displayName(n)`、`Volume.appVolume(node)`。
   一旦卡片里出现 `node.audio.volume`，Quickshell 的 API 一变就散落到几十处。
   反例（已修）：`AudioAppsCard` 曾直接读 `modelData.source.audio.muted`。
2. **服务私有成员以 `_` 开头，UI 不得引用。** 要什么就在服务层加公开面。
   反例（已修）：卡片里 `void Network._netRev`、`Network._activeWifiNetwork`。
3. **迟到数据统一叫 `revision`。** Quickshell 的对象有大量属性不发通知，服务
   内部靠 `_xxxRev` 自增触发重算，对外只暴露 `revision`（与 `Todo.revision` /
   `TrayService.revision` 同名）。UI 里写 `void Svc.revision`。
4. **列表要能播动画就必须是增量模型。** JS 数组整体重算 → ListView 只能整体
   重建 → add/remove/displaced 过渡压根不触发，这就是"新条目硬冒出来"的根因。
   服务层用 `ListModel` + `data/service/rowsync.js` 增量增删移。
   反过来，增量**只配小改动**：一次同步动的行超过一屏时，行级过渡播的是逐格
   中间态（幸存行被一格一格顶过整个视野），那一拍要关掉行级动画、让容器高度
   独自承担过渡（`Apps.bulkChange` 是范例）。也别用 `clear()` + 重填代替
   ——`count` 途经 0 会踩容器占位协议。
5. **容器占位协议**：卡片自报 `hasContent`，见下。
6. **面板互斥按区域分组**（`data/state/Panels.qml`）：
   `right` = V、N（将来 X 若落右侧）｜`left` = C、Z｜`center` = island、A。
   组名显式写死，不从几何推——锚点分工是设计决定，不是算出来的。
7. **`Size` 是 UI 的唯一令牌读取面，`Config` 只做值的来源**（第 5 轮定案）。
   UI 一律写 `Size.*` / `Color.*`，永不直接写 `Config.*`；可配的令牌由 `Size`
   转发 `Config`（`fontSans: Config.font.sans`），不可配的保持字面常量。
   这样加配置项不需要动调用点，也不会出现两个令牌来源共存。
8. **颜色以 M3 角色名 camelCase 命名，`on_*` 家族用 `Text` 后缀**（第 5 轮
   二次定案）：`surface_container_high` → `surfaceContainerHigh`、
   `on_primary_container` → `primaryContainerText`。别名只有两条：
   `text` = `surfaceText`、`textMuted` = `surfaceVariantText`，新增别名要在
   本文件登记。
   为什么不用 M3 原名 `onPrimaryContainer`：**QML 把 `onXxx:` 当信号处理器**，
   带初始值的声明编译失败，`Behavior on onXxx` 直接让 Quickshell 崩（实测见
   第 5 轮）。后缀式保住了 M3 最要紧的那层信息——配对关系：底用 `X`，`X` 上
   的字用 `XText`。想要"带色调的底"就用 container 家族（底 `primaryContainer`
   \+ 字 `primaryContainerText`），对比度由 M3 标准保证；`withAlpha` 手搓叠色
   是下策，只在 M3 没给对应角色时用。

### 容器占位规则（"可能为空"的卡片什么时候该出来）

卡片自报 `hasContent: false` 时，`RailContainer` 播收回并让出槽位。标准：

- **收起**：为什么空已经由同页另一张卡讲清楚了（首卡的开关行），或这一节
  本身是可选附加节。例：Wi‑Fi 关掉时两张网络列表卡、无已完成时的待办已完成卡。
- **留空态**：它是该页唯一容器（收了只剩 tab 条，像坏了）、它带着主要操作
  入口（待办的输入框）、或者空只是暂时的（正在扫描）。

占位切换是**上升沿防抖、下降沿立刻**，两个方向故意不对称：变空要当场压住，
否则开页那一拍空卡会闪一下再退；变非空要等它稳住，否则一帧数据抖动
（wifi 刷新列表时同 SSID 的新 AP 对象先以"未连接"出现）就换来一次
600ms 的进场+退场。

## 参考数值（M3 expressive，来自 caelestia tokens.hpp）

曲线（cubic-bezier 控制点）：

- `spatial`        (0.38, 1.21, 0.22, 1.00)  位移/尺寸默认，带过冲
- `spatialFast`    (0.42, 1.67, 0.21, 0.90)  位移/尺寸快速，大过冲
- `spatialSlow`    (0.39, 1.29, 0.35, 0.98)  位移/尺寸慢速
- `effects`        (0.34, 0.80, 0.34, 1.00)  透明度/颜色，无过冲
- `accel`          (0.30, 0.00, 0.80, 0.15)  离场加速
- `decel`          (0.05, 0.70, 0.10, 1.00)  入场减速

时长档：spatial 350/500/650ms，effects 150/200/300ms

hypr speed 换算：duration ≈ speed × 100ms（speed 越大越慢）

---

## 进度一览（2026-09-05 核过一遍）

| 轮 | 内容 | 状态 |
|---|---|---|
| 1 | hypr 动画 + 边距 | 结档 |
| 2 | qsl 动画令牌 + Anim 封装 | 结档 |
| 3 | bar 分段 + 三边 rail | 结档 |
| 4 | 面板贴栏化 | 结档 |
| 5 | 令牌层：配置体系 + 颜色词表 | 结档，留一条 |
| 6 | 合并框窗 + rail 水波 | 结档，留两个桩 |
| 7 | 窗内新面板 A / Z / X / powerbar | 下一轮 |
| 8~12 | 岛 hub、架构审计、代码质量、回归、内存 | 未开工 |

三处留白是**有意留的**，不是漏的：

1. **第 5 轮：指针主题**。`cursor.theme` / `cursor.size` 两个轴已就位并做了范围
   校验，但没接消费方——它要改的是 `hypr/lua/env.lua` 和两份 gtk `settings.ini`，
   跨配置改写跟"令牌层"不是一件事。搭第 7 轮的车或自己一轮。
2. **第 6 轮：底边的两个桩**。`RailPage.qml` 的 bottom 布局（Row 横排 + 水平
   居中）和 `RailContainer.qml` 的 bottom 耳朵都还没写，因为底边现在没有面板住。
   水波那侧已经先备好了：`Panels.railSources` 收 `bottom`，`RailRipple` 有第三个
   发射器，A 一进来就能双向发波。
3. **`Island.restoreFocus()` 还活着**。调用它的只剩没迁进框窗的 WebSearch 和
   FreeWindow，rail 这条路已经不碰它。第 7 轮迁 A/Z/X 时一起死。

同时结档的健康检查：活体 IPC 目标 8 个全是正经的（第 6 轮调试的 `dbg` 探针已
不在树里）、`qmllint` 全树全绿、壳的冷启动基线 438MB。

## 第 1 轮：hypr 动画 + 边距（先做，独立验证）

文件：`hypr/lua/appearance.lua`

- [x] `hl.curve` 新增 `spatial` (0.38, 1.21, 0.22, 1)
- [x] `hl.curve` 新增 `spatialSlow` (0.39, 1.29, 0.35, 0.98)
- [x] `hl.curve` 新增 `accel` (0.3, 0, 0.8, 0.15)
- [x] `windowsIn`: bezier=spatial, speed=5（≈500ms）, style=slide
- [x] `windowsMove`: bezier=spatial, speed=4（≈400ms）
- [x] `windowsOut`: bezier=accel, speed=2（≈200ms，手感已确认）, style=slide
- [x] `workspaces`: bezier=spatial, speed=5（≈500ms；650ms+大过冲导致内容迟迟不稳定、眼睛难聚焦，已回调）, style=slidefade
- [x] `gaps_out`: 12 → 6
- [x] 投影减小：range 15→8、alpha 20%→13%（不要辉光要层次感）
- [x] 未引用曲线清理（fastIn、spatialSlow 已删）
- [x] 验证：reload 后开关窗口、移窗口、切工作区，看手感；不习惯调 speed

注意：speed 换算为 duration ≈ speed × 100ms（越大越慢），与最初注释相反，已修正

## 第 2 轮：qsl 动画令牌 + Anim 封装

现状盘点（2026-09-01）：30 个文件共 108 处硬编码 duration，31 种不同取值
（40~1200ms）；SpringAnimation 手写参数 3 处（ClockContent/MediaPage/LockContent），
`Style.spring` 预设零引用；ColorAnimation 散落 20 个文件；`Size.anim.fastIn`
旧曲线几乎无人引用。

- [x] `data/state/Size.qml` anim 块重写：7 条曲线（spatial 三档带
      过冲 / effects 两档无过冲 / accel 离场 / decel 入场）+ 时长档
      （spatial 350/500/650，effects 150/200/300），与 hypr 侧同族；
      主题换色单独给 `durTheme: 600`（已拍板放慢，留出感受过程的时间）；
      旧令牌 20 处引用已机械改名到新时长档
- [x] 新增 `Components/Anim.qml`：NumberAnimation 封装，语义化 type
      （Spatial / SpatialFast / SpatialSlow / Effects / EffectsFast /
      EffectsSlow / Enter / Exit），type 自动映射曲线+时长
- [x] 新增 `Components/CAnim.qml`：ColorAnimation，Effects 300ms /
      Theme 600ms（`durTheme`）
- [x] 收编硬编码（共 91 处，四批完成，2026-09-01）：
      - [x] `Components/*`（27 处；Color.qml 16 个主题换色全部 CAnim.Theme）
      - [x] `ui/bar/*`（25 处；甜甜圈 Canvas 手绘系统未碰）
      - [x] `ui/island/*`（29 处；3 处弹簧已转 Spatial）
      - [x] `ui/lock/*`、`data/state/Color.qml`（10 处）
      - FreeWindow / leftbar / rightbar / notif 已于 2026-09-01 补收编（49 处），
        第 4 轮仍做布局重写
- [x] 3 处 SpringAnimation 改用曲线实现（`Style.spring` 预设已删，
      `Style.transition` 死块已删）
- [x] 装饰性长动画白名单已加注释（清单见本文件末尾）

## 第 3 轮：bar 分段 + 三边 rail

- [x] `ui/bar/Bar.qml` 重构为单窗口全宽两段：段高对齐 `Size.island.collapsedH`、
      段宽直绑内容（不加 Behavior——双重动画会让段/耳慢内容一拍），
      右段顺序 SysMonitor→StatusChips→Tray（伸缩靠左，托盘钉右边）
- [x] 左/右/底三条 8px rail（`Rails.qml`），`margins.top=0` 靠 bar 的
      exclusiveZone 对齐段底；四颗 14×14 衔接耳独立小窗放 Bottom 层，
      透过窗口圆角显形
- [x] `EarCanvas` 泛化为 corner 枚举（四种凹角），从 island 挪到 `Components/`
- [x] 顶部 exclusiveZone 跟随岛高：窗口不再被岛压
- [x] ActiveWindow 变长也走动画（配合段宽直绑）
- 教训（已写进代码注释）：Hyprland 对角锚定 layer 面忽略 exclusiveZone；
  同层 Normal 面会被 exclusiveZone 推走（margin 会叠加）；ExclusionMode.Ignore
  不注册自己的预留；Repeater 未能实例化 PanelWindow（改显式声明）
- [x] 验证：四角衔接、段伸缩同步、岛不压窗

## 第 4 轮：面板贴栏化（结构/外壳，2026-09-02 定基调）

锚点分工：leftrail→C；rightrail 上→V、中→powerbar、下→N；
bottomrail 左槽→Z/X（互斥）、中槽→A；顶部中央→island。

基调（2026-09-02 拍板）：

- 打破卡片/Tab 制，改"进入模式"：页面 = 从 rail 派生的一组容器，
  容器同时是布局/动画/生命周期单元；子 tab 切换 = 旧容器滑回 rail、
  新容器滑出（tab 条不动）
- 容器是页内 item（Loader 粒度卸载），页面（锚点）一个窗口
- 所有窗口从 rail 派生（与 island 展开同族）；~~rail 脉冲做简化版~~
  → 2026-09-05 改回**水波**并挪到第 6 轮：当初"水波难实现"的难点其实是跨窗，
  合并后整个框共用一个坐标系，水波反而比脉冲自然（详见第 6 轮）
- Z 位置定死左边（不做焦点自适应，可预测性优先）
- [x] 基件 1：`RailContainer`（贴 rail、派生动画、耳朵、Loader 生命周期）
      —— 2026-09-04 加固：`present`（内容存活）与 `shown`（占位）分离、
      占位上升沿防抖、内容高度变化走 `Behavior on implicitHeight`
- [x] 基件 2：页面框架（多容器编排、页面循环切换、子 tab 容器交换动画）
- [ ] ~~基件 3：rail 脉冲~~ → 推迟到第 6 轮，且效果改回水波（见第 6 轮）
- [x] 迁移 C（leftrail：时间 2 容器 / 系统 4 容器 / 键位 / 待办，含子 tab）
- [x] 迁移 N（rightrail 下方，368×屏高40%，垃圾桶两 bug 已修）
- [x] 迁移 V（rightrail 上方，network/bt/audio/updates 拆容器）
      —— 2026-09-04 照 `~/Documents/qsl-v-designs.html` 行式重做完毕：
      四页共 9 张卡，新建 `QslRow` / `QslSectionHeader` / `QslActionChip`，
      宽度 400→368 对齐 N
- [x] C/V/N 显示问题收尾（做完就给第 4 轮的 C/V/N 部分结档）。
      已知一条：N 的垃圾桶在应用页是 `dismissMany` 一刀切，没有根页面那套
      错峰右滑 + "先收面板后真删"，行是瞬间消失的；图标也不体现作用域
      （清一个应用和清全部长得一样）。其余待收集
  - [x] C 键位页：重写 `asset/hotkeys.json`（2026-09-04）。量过排版才动手：
        卡片文字区 332px，`keys` 列吃 150–189px，`desc` 只剩 143–182px
        = 10~13 个汉字，原来有 24 条超标（Neovim 15 条里 10 条）。
        三条改法，规矩连约束数字一起写进 JSON 的 `_note` 防回归：
        ①desc 砍到 ≤10 汉字，只说做什么，不解释、不写例外；
        ②模式/前提上提到 `section.title`（原来"←→↑↓（调大小时）"把模式名
        重复 N 遍还撑爆 keys 列，现在是"调大小模式（可长按）"一个分节）；
        ③方向键和同义键合行（`Ctrl+Alt+←→↑↓ | 调整大小` 顶掉四行）——
        Kitty 因此 13 条→8 条，总量 109→98 条。键名统一箭头，不写 Left/Right
  - [x] V 网络页：上下行速率分色（`primary` 下 / `tertiary` 上）
  - [x] V updates 页：AUR/官方分色 + 新旧版本号分级（2026-09-04）。
        `PkgSection` 加 `accent`，分节色同时喂标题和该节各行的**新**版本号，
        所以"这包打哪来"在行级也看得出，不用给每个包名都上色（长列表会吵）。
        版本号拆三段：旧 `textMuted` → 箭头 `outline`（它只是标点，再暗一档）
        → 新 = 分节色，一行里最亮的就是"要升到几"。
        配色只用主题角色（AUR=`tertiary` 淡紫 / 官方=`primary` 青），
        不写死绿橙，换壁纸不崩。顺带给 `QslSectionHeader` 开了 `titleColor`
A/Z/X/powerbar 已摘出为第 7 轮（2026-09-04 重排）：它们要等合并框窗落地后
才动，留在本轮会让"第 4 轮"这个编号横跨整个中段。本轮到 C/V/N 收尾即结档。

## 第 5 轮：令牌层——配置体系 + 颜色词表（2026-09-04 新增，原第 5 轮岛 hub 挪到第 8 轮）

放在合并框窗之前：rail / A 的形态想挂在开关上 A/B 对比，没有配置就只能改一版
QML 看一眼再改回去。**不并进第 6 轮**，因为合并框窗是大结构重写，令牌层改动
搭车进去，出回归就分不清是谁搞的（卡顿排查已经吃过混在一起的苦）。

配置和颜色合成一轮而不是拆两轮：同一层同一批文件（都在 `data/state/`），
字体的值要改由 `Config` 提供，matugen 参数也要由 `Config` 驱动而那正是颜色管线。
拆两轮得把 843 处 `Color.*` 调用点过两遍。

轮内顺序：先 `Config`（小，且立刻解锁 A/B），后颜色词表（843 处的机械大扫）。

### 分层：Config 只做值的来源，Size 仍是 UI 唯一读取面（2026-09-04 定案）

```qml
// Size.qml
readonly property string fontSans: Config.font.sans   // 可配的：转发 Config
readonly property int    md:       12                 // 不可配的：字面常量
```

UI 继续只写 `Size.*`，一处不改就拿到热重载（改 JSON → Config 变 → Size 转发
→ 绑定刷新）。否则 UI 里会同时出现 `Size.spacing.md` 和 `Config.font.sans`
两个来源，那正是第 9 轮架构审计要揪的分层混乱。

各 token 族的调用点数（2026-09-04 实测，决定谁该可配）：

| 族 | 调用点 | 可配 |
|---|---|---|
| `Size.anim` | 28 | 是——第 2 轮把动画全收进 `Anim`/`CAnim`，读取点少得惊人 |
| `Size.fontSans/Mono/Icon` | 208 | 是（靠转发，调用点不动） |
| `Size.rounding` | 97 | 否 |
| `Size.spacing` | 211 | 否 |
| `Size.fontSize` | 272 | 否 |

> 壁纸配色链路的四段调查（谁生成配色、hook 的顺序、`__qs_wallpaper_path` 从哪来、失败怎么回落）归档到
> `plan-notes.md` →「第 5 轮」。

## 第 6 轮：合并框窗 + rail 水波（原"未来独立轮"路线 A，2026-09-04 定案并提前）

原「面板内容 M3 化」轮撤销并拆散：列表规范 / 间距网格在第 4 轮迁移 V 时
就地做掉了（`QslRow` 一族）；排版阶 / StateLayer / 卡片分级三条跨面板原语挪到
第 9 轮架构审计；C/N 里和 `QslRow` 重复的手写行布局挪到第 10 轮收编；
A/Z/X 出生即 M3，对它们不再是单独一步。

为什么提到面板迁移之前做：现在的"框"是多块拼的，跨窗协调天然难做。
rail 脉冲试过一次（RailPulse 单例信号 → rail 窗口播动画）无任何可见效果即回滚，
根因就是跨窗。而 A/Z/X 若先按独立窗迁移，合并时要重做一遍。

> 这一轮的定位过程 12 节 554 行全部归档到 `plan-notes.md` →「第 6
> 轮」：动手前的窗口拓扑实测、做完要修正的四条预判、焦点模型换 `HyprlandFocusGrab`、焦点一进一出停 160ms
> 的托盘菜单、起跑线换帧闸、退场必须自下而上、岛的抖与顿、水波重做。

## 第 7 轮：窗内新面板——A / Z / X / powerbar（原第 4 轮尾巴，2026-09-04 摘出）

从第 4 轮摘出来单独成轮。它们出生就该是合并窗内的 item，内容也天生走
`QslRow` 一族，所以必须等第 6 轮落地；留在第 4 轮会让那个编号横跨整个中段。

- [x] A（bottomrail 中间：应用列表在上、搜索栏在下，列表高度随候选数弹性收缩
      有上限，去壁纸页）。**旧版 A 页面不保留**，这一轮是重写不是迁移
      （2026-09-05 确认；「卡片 / Windows 式 rail 形态开关」当初只是比喻，取消）
      2026-09-05 落地：`ui/launcher/` + `data/launcher/`（离开 freewindow，
      A 现在和 C/V/N 同级），IPC 名 `launcher`，互斥组 center（跟岛抢中段）。
      第一个**沿行程轴堆叠**的页 —— 底边的排布方向就是生长方向，为它加了
      `RailContainer.slotGrows`（槽位可顶开上面的容器）和
      `RailPage.stripHeight / slotLeadMs / exitStaggerStep`。
      三拍出场、两格同步退场、Loader 焦点作用域、白边不对称、整块居中、
      搜索框被 `Column.move` 甩出屏幕、`StrictlyEnforceRange` 抢
      `currentIndex`、结果集换增量模型 → `plan-notes.md` 第 7 轮
      再一轮：回灌时行级过渡按改动幅度开关（`Apps.bulkChange` +
      `overwriteRows`）、高度换不过冲的 `Anim.EnterFast`（新令牌档）、
      高亮范围两头对称 → 同上
- [x] Z（bottomrail 左段，单卡列表+搜索，跟 C 互斥、跟 A 不互斥）
- [x] X（bottomrail 右段，执行区/服务区磁贴，跟 V/N/power 互斥）
- [x] powerbar（rightrail 正中：一张焊轨卡，头像 + 上下四动作；lock 立刻走、
      其余两次确认；跟 V/N/X 互斥；Super+Space 改 `power toggle`，替 wlogout）
- [x] 锁屏重画（2026-09-05，第 7 轮收尾）：天气拿掉；有媒体以歌词+cava 为主
      舞台（cava 做背景，控件含随机/循环/音量）；待办跟时钟；通知右上 toast；
      密码独占右下。`ui/lock/LockContent.qml`

## 第 8 轮：岛 hub 重构（原第 5 轮，2026-09-04 挪到合并框窗之后）

挪后不挪前的理由：岛已定为并入合并窗（决策 16）。
**注意（2026-09-05 实测修正）**：原以为 morph 要从"窗口 resize 动画"改成
"窗内 item 尺寸动画"所以曲线必须重调——查了才知道**岛的 morph 本来就做在窗内
`body` 的 width/height/radius 上**（`IslandShell.qml:176-209`），窗口是全屏固定
不动的。所以合并对岛的动画没有影响，曲线不用因为合并而重调，这一轮真正要做的
就是下面那些数值和过渡本身。排在第 6 轮之后仍然合理（换爹时顺手），但不是"先做
就白做"那么强的依赖。
纯数值那几条（wallpaper 页高度、switcher 项高、media 压高）与合并无关，
任何时候都能顺手做，不必整轮都等着。

- [ ] hub 统一宽度（五页同宽，值待定，约 880）
- [ ] 高度随 tab 变：morph 曲线从 spatial 改 decel（打开/关闭仍弹）
- [ ] tab 内容过渡：顺序淡入淡出（旧页 150ms 淡出销毁 → 新页 200ms 淡入），
      遮住重排期；Loader 策略保持单页存活
- [ ] wallpaper 页 540 → 约 400（3 行压 2 行，纯改 Size.qml 数值）
- [ ] switcher 页项高 124 → 约 100，总高收到 440-460
- [ ] media/overview 压高度（能压多少看内容）；weather 压不动允许接近 4:3
- [ ] 可选增强：新页淡入时小组件错峰入场（低成本，逐页做）

## 第 9 轮：架构审计（2026-09-04 新增，原第 7 轮）

对整个 `qsl/` 逐文件核对「架构约定」那一节。2026-09-04 只顺手修了 V 的四页和
三个服务（6 处私有引用 + 7 处裸解引用，全在当轮新写的卡片里），全目录还没过。

- [ ] 分层核对：UI 不解引用服务对象、不引用 `_` 私有成员，
      `rg -n '(Network|Bluetooth|Volume|Notification|Updates|Sysmon)\._' ui/` 应为 0
- [ ] 反向核对固化成脚本：`ui/` 里每个 `Service.member` 都要在服务层真的存在。
      这次它当场抓到 `Bluetooth.connectedCount` 用了但没定义（运行时是
      undefined），值得和 `qmllint` 一起常驻
- [ ] 版本号统一 `revision`：Network / Bluetooth 已改，其余服务待查
- [ ] 列表全部走增量模型：Network / Bluetooth / Updates / Volume / Apps 已改
      （Apps 是 2026-09-05 补的，见 `plan-notes.md` 第 7 轮 / 换增量模型）；
      `Notification.entries` 仍是整体重算的 JS 数组（N 的行动画靠手写
      `clearing` 波次顶着），待评估
- [ ] `data/service` 与 `data/state` 职责边界：有没有放错层的单例
- [ ] StateLayer 原语（原「内容 M3 化」轮）：M3 悬停 8% 叠加层组件，统一替换各处手写
      hover 变色。`QslRow` / `QslActionChip` / `QslSectionHeader` 现在各写了
      一遍，是重灾区
- [ ] 排版阶（原「内容 M3 化」轮）：M3 display/headline/title/body/label 映射
      `Size.fontSize`，按角色引用，不再随手挑字号
- [ ] 卡片分级（原「内容 M3 化」轮）：surface 亮一档 = 浮得更高
      —— 依赖第 5 轮：需要 `surface_container_*` / `surface_bright` /
      `surface_dim`，而这些现在正在被扔掉的 34 个角色里
- [ ] Loader / 生命周期策略统一：谁该卸、谁该留（与第 12 轮内存互为输入）

## 第 10 轮：代码质量审计（2026-09-04 新增，原第 8 轮）

- [ ] 死代码：未引用的组件 / 函数 / 属性 / qmldir 条目
- [ ] 重复实现收编：C 和 N 的手写行布局改用 `QslRow` 一族（原「内容 M3 化」
      轮里 C/N 的那部分）；同类 helper 只留一份——教训是同一轮里
      `Volume.deviceIcon` 在服务层、`BtListCard.deviceIcon` 在卡片里并存
- [ ] 注释与实际不符：本文件的动画白名单就过期过（引用了已删的
      `NetworkPage.qml` / `BluetoothPage.qml` / `UpdatesPage.qml`）
- [ ] 文件职责过大：超长 QML 拆分（`TodoListCard` / `NotifListCard` 量级）
- [ ] `qmllint` 全绿、无绑定循环告警
- [ ] 临时调试设施清零：IPC handler、console.log、dbg 属性
- [ ] 错误路径审计：服务层失败会不会静默清空缓存——教训是 `updatesctl`
      把 `paru` 查询失败当成"零个更新"，把 AUR 列表整个抹掉了

## 第 11 轮：回归轮（动画令牌，原第 9 轮）

目的：前面大量重写页面/卡片/交互后，检查是否有动画又脱离令牌被硬编码。
第 9/10 轮管结构与卫生，本轮只管动画曲线族有没有被绕开。

- [ ] 审计：`grep -rn 'duration: [0-9]'` 应只剩装饰性动画白名单；
      `grep -rn 'NumberAnimation\|ColorAnimation'` 应全部来自 Anim/CAnim；
      `grep -rn 'bezierCurve\|Easing\.'` 应只出现在令牌与封装组件里
- [ ] 目检：逐个面板过一遍开关/切换/悬停手感，确认曲线族统一
- [ ] 白名单（装饰性动画）清单写进本文件，后续新增硬编码必须能说清理由

## 第 12 轮：内存调查与优化 + GC 停顿（原第 10 轮，2026-09-05 扩容）

> 两个已结案归档到 `plan-notes.md` →「第 12 轮」：那 150~200ms 不是 GC 而是一棵关着的托盘菜单；那
> 4.4GB 不是泄漏而是两份 FileView 把 700MB 壁纸读进了内存。

- [ ] 摸清 `Private_Dirty` **519MB** / `Rss` 788MB 的构成
      （2026-09-05 更新：拆掉壁纸 FileView 后冷启动基线是 438MB 且 45 秒内不动，
      这两个旧数字采自更早的版本，重测前不要当基准）
- [ ] 找高频分配点：`rowsync.js` 的增量同步、各服务的 `JSON.parse`、
      `Panels` 的 `Object.assign`、字符串拼接、每帧求值的绑定
- [ ] 原则确立：**装饰动画不得每帧跑 JS**（水波起伏为此改用静态 Shape + 位移，
      见第 6 轮）。新增动画若要每帧算，先问能不能烘成静态几何再变换
- [ ] 评估「动画期间禁止重活」的可行性：GC 时机 QML 侧管不了，所以方向只能是
      降低分配速率，不是挑时机
- [x] `focusSettleMs` 改帧闸：230ms 的粗糙隔离带换成等两帧的 `FrameAnimation`
      （2026-09-05 已做，见第 6 轮「起跑线换帧闸」）

### 原有内存条目

- [ ] 用 qsl-memtrack/qsl-membench 摸清 438MB 基线的构成（原写 700MiB→1GiB）：
      常驻页面清单、图像纹理占用（缩略图/封面/图标/锁屏降采样图）、
      增长曲线是否单调（单调涨=泄漏信号）
- [ ] 审查 Loader 卸载策略（哪些页面该卸不卸）
- [ ] 审查图像缓存策略（sourceSize/cache 设置）
- [ ] rail 上线后复测（预期可忽略，验证用）

---

## 动画白名单（第 2 轮确立，回归轮审计依据）

装饰性/刷新动画，不走令牌（源码处已有注释标记）：

- `Components/QslIconButton.qml` — busy 旋转 RotationAnimator 900ms 无限循环
- `ui/bar/Workspaces.qml:162,177` — 甜甜圈 flipAnim/settleAnim（Canvas+Timer 手绘系统）
- `ui/island/LyricsContent.qml` — 歌词跑马灯（无限循环 SequentialAnimation 组）
- `ui/island/MediaPage.qml:205` — 频谱柱 60ms tick；`:476` 波形相位 1200ms 循环
- `ui/island/NotifToastContent.qml` — toast 倒计时进度条
- `ui/island/WeatherPage.qml:377,386` — 刷新 spinner 800ms 循环 + 配套 resetAnim
- `ui/lock/LockContent.qml:905-910` — 输错密码 shakeAnim 抖动（40/50ms 关键帧）
- `Components/QslActionChip.qml`、`Components/QslSectionHeader.qml` — busy 旋转 900ms
- `ui/rightbar/NetToggleCard.qml`、`ui/rightbar/BtToggleCard.qml` — 扫描跑马灯 1100ms
- `ui/rightbar/NetListCard.qml` — 连接中旋转；`ui/rightbar/BtListCard.qml` — busy 旋转
- `ui/rightbar/UpdStatusCard.qml` — 检查中跑马灯
  （以上四行 2026-09-04 更新：原先指向的 NetworkPage / BluetoothPage /
  UpdatesPage 已在第 4 轮迁移 V 时删除，条目一直没跟着改——第 10 轮要防的就是这个）

机制受限未转换（封装组件表达不了，保持原样）：

- `ui/island/MediaPage.qml:468` — 播放进度 SmoothedAnimation（velocity 驱动，过冲会抖）
- `ui/island/OverviewCalendar.qml:192` — 翻页 slideAnim（JS 链式改写 duration）
- `ui/island/WeatherPage.qml:223` — 风向 RotationAnimation（依赖 direction: Shortest 跨 0° 最短路径）
- ~~`ui/leftbar/Leftbar.qml` / `ui/rightbar/Rightbar.qml` 的 panelAnim~~
  已随第 4 轮改 `RailPage` 消失（2026-09-04 核实）

> 调参记录（各动画时长与几何值的取值和理由，122 行）归档到 `plan-notes.md` 末尾。新调的值继续往那边追加。

