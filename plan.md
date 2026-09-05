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

分层：`data/service` = 外部世界（NM / BlueZ / Pipewire / Hyprland / 进程 / 文件）；
`data/state` = 主题、尺寸、会话状态；`Components` = 无业务的通用件；
`ui/*` = 面板与卡片。

**依赖方向自下而上：`service` → `state` → `Components` → `ui`**（第 9 轮定案）。
服务只认识外部世界，不认识本壳有几个面板、主题是深是浅，所以它最独立、放最
底下；状态层是「这个壳此刻的样子」，天然要读服务（岛要知道有没有播放器在放、
要跳窗就得会跟 Hyprland 说话）。反过来 `service` import `state` 就是方向错了。
`ui/*` 之间不得横向 import，只有 `ui/frame/` 作为框窗聚合器例外。

这四条方向 + 下面第 2、7 条，加上「UI 写的每个 `Svc.member` 服务层必须真有」，
由 `qsl/scripts/qsl-archcheck` 机械把关。最后一条是重点：QML 读不存在的属性
不报错，就是 `undefined` 一路静默流进绑定，`qmllint` 查不出来。

闸门现有六项：**分层方向 / 私有成员 / 令牌入口 / 接口存在性 / 生命周期 /
排版阶**。加新规则时务必自测它会亮（故意注入一处违规看能否报出）——第 9 轮
吃过亏：PATH 上的 `qmllint` 是 Qt5 空壳，静默放过一切，此前所有「0 警告」
都不作数。哑规则比没有规则更坏，因为它让人以为查过了。

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
9. **每个外部系统恰好一个服务单例**（第 9 轮定案）。判据很直白：需要 import
   `Quickshell.<某系统>`、或者要起进程/读文件/发 HTTP 才能拿到的东西，就该有
   一个服务收着，且只有它一家 import 那个模块。
   反例（已修）：Hyprland 之前是唯一没有服务层的外部世界，于是被 5 个文件跨
   3 层直接消费——切换器、工作区指示器、活动窗口药丸各自遍历一遍活对象，而
   派发焦点的 `hyprEval` 一族寄居在 `data/state/Island.qml` 里。最能说明问题
   的是启动器：它要拉起一个应用得去调 `Island.hyprEval()`，而启动器和岛没有
   半点关系——它够到那儿只是因为没有别的地方能拿到这个能力。现已收进
   `data/service/HyprService.qml`（不叫 `Hyprland`：那是 `Quickshell.Hyprland`
   导出的单例名，同时 import 两边会撞；后缀沿用 `TrayService`）。
   这条规则现在由闸门守着：`ui/` 下不许 import `Quickshell.Services.*` 或
   `Quickshell.Io`，两处例外写在 `qsl-archcheck` 的 `EXTERNAL_IN_UI_EXEMPT`
   里并各附了理由（PAM 与锁屏生命周期绑死、`IpcHandler` 的 target 全局唯一）。
   第 9 轮收完之后 `ui/` 下已无未登记的外部直连。

   **同一份知识散成多份就会漂移**，这是第 9 轮收托盘时最直接的证据：
   「这是不是那四个有自带 SVG 的社交应用」在三处各写了一份，其中两处连函数名
   都叫 `detectBundledAppId`——托盘那份认「腾讯」不认「tim」，启动器那份反过来，
   而且用的是裸 `indexOf("tim")`，于是 Timeshift、OpenJDK Java Run(tim)e 在启动器
   里全贴了 QQ 的企鹅。三份合并成 `data/service/Icons.qml` 之后，三处拿到的是
   同一个并集，`tim` 也改成了要求两侧非字母数字。

### `Loader` 生命周期约定（第 9 轮定案）

**每个 `Loader` 都要显式写 `active`**，由闸门守着。默认值 `true` 的意思是
「建出来就再也不卸」，而 Loader 存在的理由多半正是想控制这个——不写就等于
把生命周期交给默认值，且看代码的人分不清这是深思熟虑还是忘了。真要常驻就
写 `active: true`，一个字面量而已，但它把「我知道它不卸」和「我没想过」
分开了。

盘点时全树 14 处（8 个文件）自发形成了四种模式，就按这四种来：

| 模式 | 条件长什么样 | 用在哪 |
|---|---|---|
| 随宿主可见性 | `active: 展开了 \|\| 还在收` | `QslRow` 的展开区、`RailContainer` 的页、`Tray` 的槽、`ClipCard` 的两种行、框窗的键盘属主 |
| 随视口远近 | `active: 近视口 \|\| 是焦点` | 切换器的窗口缩略图（`ScreencopyView` 一个就是一路屏幕捕获） |
| 延迟卸 | 置假后由定时器收尾 | 岛的 hub：关岛时还要留 360ms 播淡出，立刻卸会看到内容凭空消失 |
| 常驻只换内容 | `active: true` + `sourceComponent` 分支 | hub 的页容器：换页是换 `sourceComponent`，Loader 本身不该跟着拆建 |

注意「还在收」那一截：条件只写 `expanded` 会在收起动画第一帧就把内容卸掉，
于是收的是个空壳。要带上「或者高度还没归零」。

`asynchronous` 默认不开，**只有实测出单次长阻塞才开**。现在只有两处：hub 的
页容器（同步建 `OverviewPage` 要一次铺 3 个月 ×42 格 ×4 item，就是切 Tab 掉帧
的来源）和 hub 本身。异步是分帧建，代价是加载期间那块是空的，所以它换来的
必须是真实测出来的卡顿，不是「感觉这样更好」。

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

## 进度一览（2026-09-06 核过一遍）

| 轮 | 内容 | 状态 |
|---|---|---|
| 1 | hypr 动画 + 边距 | 结档 |
| 2 | qsl 动画令牌 + Anim 封装 | 结档 |
| 3 | bar 分段 + 三边 rail | 结档 |
| 4 | 面板贴栏化 | 结档 |
| 5 | 令牌层：配置体系 + 颜色词表 | 结档，留一条 |
| 6 | 合并框窗 + rail 水波 | 结档，留两个桩 |
| 7 | 窗内新面板 A / Z / X / powerbar | 结档 |
| 8 | 岛 hub 重构 | 结档 |
| 9 | 架构审计 + 设计系统三阶 | 结档 |
| 10 | 代码质量审计 | 下一轮 |
| 11~12 | 回归轮、内存 | 未开工 |

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

> **2026-09-05 更正**：上面那条「`qmllint` 全树全绿」不作数。当时用的
> `/usr/bin/qmllint` 是 `qt5-declarative` 装的 Qt5 版本，而 Quickshell 是 Qt6——
> 它不是查得浅，是完全失灵：`Item { NoSuchType {} }` 和 `Item { width: }` 都零
> 输出零退出码。改用 `qsl/scripts/qsl-qmllint`（锁 Qt6 二进制 + 造 `qs/` 模块
> 映射），真实结果是 import/语法 0 条，另有约 1200 条 missing-property /
> unqualified，多为 qmllint 对 Quickshell 类型注册的盲区。

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

- [x] 不定统一宽度（2026-09-05 否决：只把比例往宽银幕收）。
      **但 2026-09-05 二次修正**：往宽银幕收要有下限。第一版卷轴做到
      1000×336（4.2:1）、switcher 3.3:1，两条都是信箱。定的规矩是——
      想让页面扁就减内容（卷轴 7 张 → 5 张），不是压高度；想让页面高就
      放大件（switcher 卡 92 → 140），不是多塞几行。宽度 overview /
      wallpaper / switcher 统一 880，media 820、weather 760 各自留着
- [x] tab 条移到岛顶，高度 80 → 64（唯一五页都交的税，省下的每页都拿得到）
- [x] 各页高度改成"倒着算"：先量内容最小可用高再往上留。第一版凭手感填的
      overview 400 / media 360 比内容还矮，屏上是待办卡被顶出岛外、日历格
      压到 27px（数字压农历）、媒体控件贴着岛底边。算式落在各页文件头
- [x] 岛尺寸只留一层动画：删掉 `HubContent` 自己的
      `Behavior on implicitWidth/implicitHeight`。原来是 body(SpatialFast 400ms)
      追一个自己也在动(Spatial 500ms)的目标，落定 700ms+ 且两条都过冲，
      观感是橡皮筋；更贵的是尺寸每帧变 → 页内容每帧全量重排（天气页那条
      Canvas 每帧重画），这就是"天气切出去太卡"的真身。现在隐式尺寸一步到位，
      只有 body.clip 在动，页只重排一次
- [x] `hubLoader` 从 centerIn 改顶部对齐：岛吊在屏顶、只有下边在动，居中会让
      tab 条随高度差上下漂（天气→切换器漂 130px）
- [x] 子页 Loader 改 `asynchronous`：同步建 OverviewPage 要一次铺 3 个月面板
      ×42 格 ×4 item，就是切 tab 那下的掉帧
- [x] 高度随 tab 变：开/关岛 SpatialFast（弹）；切 Tab 在改目标前把
      `body.morphType` 换成 Enter（decel、不过冲）。两套曲线共用一条
      Behavior，只换 type
- [x] tab 内容过渡：`shownIndex` 落后于 `currentIndex`。旧页 Exit 淡出
      （200ms accel）再换 Loader，新页 EffectsSlow 淡入 + `playEnter()`
      错峰。单 Loader，不叠两页（天气 Canvas 叠一份会回到卡的老路）
- [x] Overview 880×452：身份+时钟并排 → 天气横条 → 待办只读可滚，右日历通高。
      uptime/电量落到身份行；三个平台标签从药丸压成一行小字（永不变化的静态
      信息不值得占 204px）；地名不显示（放不下且天气页有），空出来的位置给
      体感 / 湿度 / 紫外线
- [x] Media 820×448：封面 232 见方、左边距 24；cava 从封面右下角挪到歌词
      底下通宽一条（30 根柱，宽度跟歌词对齐）；播放器选择器提到整页右上角
      （低频操作不占正文位，展开才往下掉一列），歌词整块下压 34 给它让路
- [x] 进度条波形接 cava：整体均值 → 振幅 / 频率 / 副波混乱度，低频 5 根 →
      播放头那一鼓。相位改 `FrameAnimation` 手动按帧积分（速度要跟能量变，
      而改正在跑的 `NumberAnimation` 的 duration 会让波形当帧裂一道口）；
      两路都过 `SmoothedAnimation` 平滑，30fps 原始值直接喂进去是毛刺不是节奏
- [x] Wallpaper 880×324：卷轴一屏 5 张、焦点卡压邻居（叠压后同宽度能放
      300 的卡，平铺只能 251）；圆角走 OpacityMask（`clip` 只裁矩形包围盒，
      图会把圆角盖回方的）；焦点绕圈走，不夹在 [0, n-1]（夹住的话当前壁纸
      恰好排在末尾时右半屏全空）；本页自管顺序；去 lianwall-gui。
      焦点卡不加强调色环——大一圈 + 压在邻居上面已经说清楚了
- [x] Weather 不改布局，高度 580 → 540（曲线区仍有余量，顺手收一点让
      "天气 ↔ 其他页"的高度差从 330 降到 216）
- [x] Switcher 880×380，项高 124 → 140（92 时缩略图区 3.1:1，窗口截图认不出来；
      140 → 1.74:1 接近 16:9），一屏仍是约 2.4 张
- [x] lianwall「正在切换」事件驱动的切换动画（2026-09-05 撤销）：查过没有这个
      事件。装的 5.5.1 事件枚举只有 WallpaperChanged / StatusChanged /
      SpaceUpdated / ConfigChanged / VramChanged / TimePointReached /
      ScanProgress / Error，`status --json` 里也没有 transitioning 字段；
      订阅着跑 `lianwall next` 只收到一条 WallpaperChanged（Trigger: ManualNext）
- [x] 错峰入场：`QslStagger` 36ms 一拍，卡片 `shown(n)` 后走
      Anim.Enter（位移）+ EffectsSlow（透明度）。五页都接了 `playEnter()`
- [x] 歌词焦点不再改 `pixelSize`：折行按 26px 排死，焦点只动 scale /
      颜色 / 透明度，避免动画中途重新换行闪一下
- [x] Wallpaper ←→ 用 `slideShift` 插值整排（槽位身份不变，不能靠
      Behavior on x）；Enter 焦点卡 punchScale 1→1.08→1（spatial）
- [x] 卷轴闪烁（订正两次归因）：先怪过异步加载、又怪过 OpacityMask 每帧重算，
      都不是。真身是两条——`sourceSize` 绑在动画中的卡宽上（每帧一个新尺寸
      = 每帧重解一张 4K 图），以及 Repeater 的 model 取的是"焦点周围七格"
      的切片（焦点一动整批 delegate 换 `source`，等于每步重建七张图）。改成
      model 给整条 reel（delegate 与壁纸一一对应、`source` 终身不变）+
      `sourceSize` 定死 `thumbSource`，图只解一次，之后纯变换
- [x] 快按 ←→ 不跟手：动画排队攒着播。`settleSlide` 改成来新输入就地结算——
      停掉在飞的那段、`focusIndex` 落到当前视觉位、再从残余位移起新的一段

## 第 9 轮：架构审计（2026-09-04 新增，原第 7 轮）

对整个 `qsl/` 逐文件核对「架构约定」那一节。2026-09-04 只顺手修了 V 的四页和
三个服务（6 处私有引用 + 7 处裸解引用，全在当轮新写的卡片里），全目录还没过。

**这一轮已完成（2026-09-06）。** 分两半：前半是依赖路线与职责分层，后半是
「内容 M3 化」轮并进来的三项设计系统活（状态层 / 排版阶 / 层级阶）——它们跟
依赖审计不是一回事，只是排在同一轮里。

后半这三项有个共同的教训值得记：**盘点方式决定结论**。三项里有两项，第一遍
盘出来的数字都是错的，而且错的方向一致——单行 grep 看不见跨行和分组的写法，
于是低估。排版那项还更进一步，盘完发现「要改的东西」跟计划里写的根本不是
一回事（详见下面各条）。

这一轮实际落地的重构，按「同一件事散在几处」归的类：

| 收上来的 | 原先散在 |
|---|---|
| `HyprService` | SwitcherPage / Workspaces / ActiveWindow / Island 的 hyprEval |
| `Media` | MediaPage 与 LockContent 里 60+ 处 `player.*`（两处近乎逐行同构） |
| `Session` | PowerBar 的 systemctl + OverviewPage 的自我重启壳 |
| `TrayService` + `Icons` | Tray / TrayItem / NotifCenter / AppSearch 各问了一遍「这是哪个应用」，答案还不一样 |
| `Hitokoto` | TimeClockCard——全树唯一一处 UI 自己发 HTTP |
| `Apps.parseExec` + `HyprService.execArgv` | Launcher 里的 Exec 字段码解析与 shell 引号 |
| `Sysmon.refreshBasics` | OverviewPage 自己起 Process 读 hostname / uptime |

外加：死代码清链（`QslCard` / `QslShadow` / `QslHubTab` + `Style.shadow` / `bg`）、
断开 state ↔ Components 循环（`Anim` / `CAnim` 挪进 `data/state`，`avatarUrl` 归位
`Avatar`）、`clipboard` / `launcher` / `tiles` 三个 feature 目录并入 `service`。

- [x] 分层核对：UI 不解引用服务对象、不引用 `_` 私有成员，
      `rg -n '(Network|Bluetooth|Volume|Notification|Updates|Sysmon)\._' ui/` 应为 0
      —— 现为 0，且四道闸门（分层方向 / 私有成员 / 令牌入口 / 接口存在性）全绿
- [x] 反向核对固化成脚本：`ui/` 里每个 `Service.member` 都要在服务层真的存在。
      这次它当场抓到 `Bluetooth.connectedCount` 用了但没定义（运行时是
      undefined），值得和 `qmllint` 一起常驻
      —— 落地为 `scripts/qsl-archcheck`。同时发现 PATH 上的 `qmllint` 是 Qt5 空壳
      （静默放过一切，此前所有「0 警告」都不作数），另建 `scripts/qsl-qmllint`
- [x] `data/service` 与 `data/state` 职责边界：有没有放错层的单例
      —— 方向定为 service → state → Components → ui，并写进闸门；
      `ui/` 不得直接 import `Quickshell.Services.*` / `Quickshell.Io`
      （例外两处：`ui/lock/LockContext.qml` 的 PAM、`ui/frame/FramePanels.qml` 的 IPC 汇总）
- [x] 版本号统一 `revision`：Network / Bluetooth 已改，其余服务待查
      —— 逐个核过 7 个带 `revision` 的服务。删掉 `TrayService.revision`（跟
      `pinSignature` 重复，UI 里两个处理器干同一件事）；`Clipboard.revision`
      一度当死代码删了又装回来——`rg '\.revision'` 搜不到它，因为消费方写的是
      `onRevisionChanged`，而 `ClipHistory.clampSelection()` 正靠它夹选择。
      这个盲区补进闸门了：`Connections` 的 `on<X>Changed` 会去 target 上核对
      `X` 是否真存在（QML 只在运行时 WARN 一句，不报错不中断，极易漏过）
- [x] 列表全部走增量模型：Network / Bluetooth / Updates / Volume / Apps 已改
      （Apps 是 2026-09-05 补的，见 `plan-notes.md` 第 7 轮 / 换增量模型）；
      `Notification.entries` 仍是整体重算的 JS 数组（N 的行动画靠手写
      `clearing` 波次顶着），待评估
      —— **评估完了：不换**。这条原本的预期是「换成增量模型就能拆掉手写的
      `clearing` 波次」，但那个预期不成立。第 7 轮自己定过一条规矩：一次同步
      动的行超过一屏时，行级过渡是按格播的中间态，那一拍反而该关掉动画。
      而「全部清空」恰好就是超过一屏——`clearing` 波次正是为此存在的，换了
      增量模型也删不掉。真正能改善的只剩单条通知增删那一半，代价却是重写
      `NotifListCard`（535 行、两个常驻 ListView、动画全是手调的）。收益一半、
      风险整个子系统，不划算。
      这一轮在 N 上做的是另一件事：把「按应用分组」从面板挪进服务（见下）。
- [x] StateLayer 原语（原「内容 M3 化」轮）：M3 悬停 8% 叠加层组件，统一替换各处手写
      hover 变色。`QslRow` / `QslActionChip` / `QslSectionHeader` 现在各写了
      一遍，是重灾区
      —— 落地为 `Components/QslStateLayer.qml` + `Color.state` 五个令牌。
      改前全树九种写法：中性档 0.04 / 0.06 / 0.08，强调档 0.12 / 0.15 / 0.18 /
      0.22 / 0.25 / 0.28，按下态 0.14 / 0.16 / 0.24。取值没照抄 M3 规范的
      8%/10%——那是给浅色面调的，8% 的 primary 在 `#1b2023` 上基本看不见；
      取的是现有写法里最常用的那档，所以落地后整体观感不变，变的是偏离的那些。

      两个坑：
      · **`z: 1` 会盖住文字。** 原语第一版写了 `z: 1`，静息时 alpha 为 0 看不
        出来，一悬停那层就压在文字上面。改成不写 z，靠声明顺序压在内容下面。
        别想用 `z: -1` 绕——QML 的渲染顺序是「z<0 的子项 → 本体 → z>=0 的
        子项」，负 z 会跑到宿主自己的填充色底下，直接看不见。
      · **单行 grep 漏了三分之一。** 第一遍按单行找 `color:` 里的
        `containsMouse`，报 12 处；但 color 表达式会跨行写，也会写成
        `color: { ... }` 块——光 MediaPage 一个文件就漏了两处。按括号配平吃完
        整个表达式后，实为 19 处。

      19 处里换 11 处，剩 8 处**不该换**，已写进原语文档：7 处是前景变色
      （图标转 primary、清空键转 error）——状态层管底不管字，套过去等于把语义
      色改成洗色；`LockContent` 那处浮在模糊壁纸上用写死的白，不是主题色，
      这套透明度档是照暗色面调的，搬过去偏亮
- [x] 排版阶（原「内容 M3 化」轮）：M3 display/headline/title/body/label 映射
      `Size.fontSize`，按角色引用，不再随手挑字号
      —— 258 个调用点换成 M3 角色名，五阶各三档。为什么值得改：尺寸名只说
      「多大」不说「这是什么」，12px 那一档 83 处里一半是正文一半是标签，
      从 `Size.fontSize.sm` 上完全看不出来——想「把所有标签调小一号」是做不到
      的，因为压根没有「所有标签」这个集合。

      同一 px 对应多个角色（14px 既是 bodyMedium 也是 titleSmall 也是
      labelLarge）不是重复，正是重点：今天渲染一样，语义不同，将来要分开调
      才有得改。

      **盘完发现要改的东西跟计划里写的不是一回事**：258 处里有 54 处根本不是
      排版，是拿字号给**图标字形**定尺寸，占两成。混在一起的后果是「把正文
      调大一号」会连图标一起放大。拆出了 `Size.iconSize`，两条线各走各的。

      写死的字号 32 处、散出 17 种值。其中 17 处的值跟阶上某档一模一样——纯属
      绕过令牌，改了令牌它们不跟着动，收回去了。剩 15 处是真的一次性尺寸
      （9px 日历角标、38/52px 时钟与气温、48/56px 装饰字形）；给每个装饰字形
      都发一个令牌那就不是阶而是清单，所以留字面量并在闸门里挂账。

      安全性：px 值全程未动，改名视觉零变化，有脚本逐条核过新旧像素相等。
      这也是敢大规模自动化的前提——**判错角色只是名字不准，不会有视觉后果**。
      与 M3 规范的三处偏离都是保持现状：titleLarge 20（规范 22，抬上去顶破
      岛内布局）、displayMedium 44、displayLarge 56。

      顺带清掉两个从没被引用过的令牌 `hero(32)` / `jumbo(132)`。`jumbo` 尤其
      讽刺：锁屏那个巨型时钟写死的是 136，跟令牌差 4px，所以它一天都没对上过。
      现在是 `displayHero: 136`，对齐真实用法
- [x] 卡片分级（原「内容 M3 化」轮）：surface 亮一档 = 浮得更高
      —— **盘完发现调用点是对的，错的是调色板**，跟预想的「改一堆调用点」
      相反。`background` 那 18 处全是 chrome（bar 各段、岛壳、toast、MediaPage
      淡出到页底的渐变），`surface` 那 11 处全是嵌套内容（待办行、进程块、
      一言框、天气搜索下拉）——语义分得很干净。问题是这俩在 M3 暗色方案里
      本来就同值 `#0f1416`，所以「嵌在面板里的一行」跟「面板」跟「面板后面的
      桌面」是同一个黑。待办列表读起来平就是这么来的：行与行只靠间距和悬停
      态区分。同时 container 五档里 Lowest / Low / Container 三档一次没用过，
      等于有梯子不爬。

      只动 9 处：面板里的内容行从 `surface` 抬到 `surfaceContainerLow`
      (`#171c1f`)。ClipCard / NetListCard 那两处 `withAlpha(surface, .72/.9)`
      不动——那是压在内容上的遮罩，用页面底色是对的，不是「一层内容」。

      **挑档依据：数「头上压了几层会画底色的祖先」，不是数花括号。** 后者试过，
      完全对不上——每个色阶都摊在深度 1 到 11 上，因为 Layout / Item / Repeater
      不画东西，不构成视觉层级。阶已写进 `Color.qml`。

      这一项是本轮唯一真的会改变外观的改动，其余两项都是零视觉变化
- [x] Loader / 生命周期策略统一：谁该卸、谁该留（与第 12 轮内存互为输入）
      —— 盘点结果比预估好得多：全树 14 个 Loader（8 个文件），**每一个都
      已经写了显式 `active`**，没有一处是默认常驻。（原先记的「18 文件 20 处」
      是拿 grep 数文件名数出来的，把注释里提到 Loader 的也算进去了。）
      所以缺的不是策略而是**把策略写下来**——每处都各自推理了一遍，新写的
      人无从遵循。已成文为上面的「`Loader` 生命周期约定」（四种模式），
      并加了闸门规则：Loader 必须显式声明 `active`，存量 0 违规当基准线。
      `asynchronous` 同理：只有两处，都是实测出单次长阻塞才开的

## 第 10 轮：代码质量审计（2026-09-04 新增，原第 8 轮）

- [x] 死代码：未引用的组件 / 函数 / 属性 / qmldir 条目（清了 6 处：
      `HubPlaceholder.qml`、`Sysmon.openBtop`、`Todo.itemsByTag`、Calendar 的
      `days` / `_rebuild` / `previousMonth` / `nextMonth` / `_allDates`）
- [x] 重复实现收编：**C/N 的行不该改 `QslRow`**（2026-09-06 核过：`KeysListCard`
      是两栏胶囊、`SysProcsCard` 是四列表格且表头要跟表体对齐、`NotifListCard`
      明确用 anchors 而非 Layout 且图标展开时改锚点——套 `QslRow` 要给它加三个
      属性，反过来拖累现用它的 8 张卡）。真正的重复是 `TodoListCard` 和
      `TodoDoneCard` 互相重复 90 行，已抽 `ui/leftbar/TodoRow.qml`。
      同类 helper：`shellQuote` 三份（HyprService / Weather / Avatar 内联一句）
      收进 `data/service/shell.js`
- [x] 注释与实际不符：动画白名单改**按 `id` 锚定**（原来按行号，10 条里 8 条
      指错，`Workspaces.qml:162/177` 指到 109 行文件的界外）；
      `NotifToastContent` 那句"不走令牌"说反了（它用的就是 `Island.notifToastMs`）。
      全库注释扫过一遍，其余提到已删符号的三处都是有意的墓碑注释
- [~] 文件职责过大：四个 UI 大件已拆（2026-09-06），闸门全绿

      | 原文件 | 行数 | 拆出 |
      |---|---|---|
      | `ui/island/WeatherPage` | 1233 → 106 | `WeatherNow` / `WeatherNowcast` / `WeatherForecast` / `WeatherSearch` / `WeatherMetricTile` / `WeatherGaugeTile` |
      | `ui/lock/LockContent` | 932 → 316 | `LockCava` / `LockClockMini` / `LockClockHero` / `LockLyrics` / `LockMediaControls` / `LockToasts` / `LockPassword` |
      | `ui/island/MediaPage` | 785 → 275 | `MediaWave` / `MediaLyrics` / `MediaPlayerPicker` / `MediaCtrlBtn` |
      | `ui/notif/NotifListCard` | 536 → 111 | `NotifAppRow` / `NotifEntryRow` |

      **明天继续拆的（按大小）**：

      - `data/service/Network.qml` **866** — 服务层，拆法跟 UI 不同：
        应该按「连接管理 / 扫描 / 门户检测 / nmcli 解析」切，不是按视觉分区
      - `ui/frame/RailRipple.qml` **734** — 单一职责（水波物理本身），
        真要拆只能把「波形求解」和「Shape 渲染」分开，先评估值不值
      - `ui/island/OverviewPage.qml` **647**
      - `ui/island/WallpaperPage.qml` **616**
      - `ui/island/OverviewCalendar.qml` **584**
      - `data/service/Bluetooth.qml` **537**
      - `Components/RailPage.qml` **530**

      拆的手法见已拆四例，两条经验：①「跨区共用的状态留页根，子件回引取用」
      与「显式往下传」二选一，**同一个文件里别混用**——回引省样板但绑定在
      赋值前会报 null（锁屏那三档 ink 被引用二十几次，走回引日志就没法看，
      所以锁屏用显式传）；② 新增 QML 文件热重载看不见，必须整壳重启
- [x] `qsl-qmllint` 的 import/语法两类为 0、无绑定循环告警
      （**别用裸 `qmllint`**——PATH 上那个是 Qt5 的空壳，见第 0 轮结档的更正）。
      顺手把 `unused-imports` 也提成致命项，清了 9 个未用导入
- [x] 临时调试设施清零：IPC handler、console.log、dbg 属性
      （只找到一处真问题：`LockContext` 往 journal 记密码长度，改成只记空/非空）
- [x] 错误路径审计：服务层失败会不会静默清空缓存——教训是 `updatesctl`
      把 `paru` 查询失败当成"零个更新"，把 AUR 列表整个抹掉了。
      查出同类三处：`Clipboard` / `Notification` 的 `applyCacheText`、
      `Lianwall.applySpace`，解析失败都会把已有数据清空，改成保留上一份好数据

## 第 11 轮：回归轮（动画令牌，原第 9 轮）

目的：前面大量重写页面/卡片/交互后，检查是否有动画又脱离令牌被硬编码。
第 9/10 轮管结构与卫生，本轮只管动画曲线族有没有被绕开。

- [x] 审计（2026-09-06）：**没有泄露**。23 处硬编码 `duration` 全部落在白名单内，
      0 处新增；`bezierCurve` 只出现在 `Size.anim.curve*`；裸 `NumberAnimation`
      只剩「需要 id 供 JS start/stop」这一类，时长曲线仍取自令牌
- [ ] 目检：逐个面板过一遍开关/切换/悬停手感，确认曲线族统一
- [x] 白名单（装饰性动画）清单写进本文件（第 10 轮改 `id` 锚定，
      第 11 轮跟进拆分挪走的五条路径）

### 附带做掉：M3 容器色收编（2026-09-06）

审计颜色令牌时发现的更大问题：`Color.qml` 暴露 52 个 M3 角色，**35 个引用次数为 0**，
整套 UI 跑在 primary(161) / textMuted(132) / text(77) / error(50) 四个色上。
而「选中/激活的有色底」在 27 处用 `withAlpha(primary, 0.12~0.25)` 手搓——
`Color.qml` 自己第 25 行就写着「优先用 container 家族」，规矩写了从没执行。

- [x] 27 处 primary + 6 处 error 收编成 `primaryContainer` / `errorContainer`，
      压在上面的字同步换 `*ContainerText`。容器家族用量 0 → 55
- [x] 2 处真泄露（`SwitcherPage` / `NotifToastContent` 用 `Qt.rgba(c.r,c.g,c.b,a)`
      绕开 `Color.withAlpha`）改回令牌
- [ ] **未做**：表面色阶 8 档仍只用 3 档（`surfaceContainerLowest` /
      `surfaceContainer` / `surfaceDim` / `surfaceBright` / `surfaceVariant` 全 0），
      卡片套卡片分不出深浅。留给后续

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

**条目按元素 `id` 锚定，不写行号。** 2026-09-06 第 10 轮核对时，带行号的 10 条
里 8 条已经指错地方，`Workspaces.qml:162/177` 甚至指到了 109 行文件的界外——
行号每改一次文件就烂一次，`id` 不会跟着漂。没有 id 的写结构位置。

装饰性/刷新动画，不走令牌（源码处已有注释标记）：

- `Components/QslIconButton.qml` `id=glyph` — busy 旋转 RotationAnimator 900ms 无限循环
- `Components/QslActionChip.qml`、`Components/QslSectionHeader.qml` — 同上，busy 旋转 900ms
- `ui/island/LyricsContent.qml` `id=scrollAnim` — 歌词跑马灯（无限循环 SequentialAnimation 组）
- `ui/island/MediaLyrics.qml` `id=cavaStrip` — 频谱柱 60ms tick
- `ui/island/WeatherNow.qml` `id=spinAnim` — 刷新 spinner 800ms 循环；
  `id=resetAnim` — 配套复位 300ms
- `ui/lock/LockPassword.qml` `id=shakeAnim` — 输错密码抖动（40/50ms 关键帧）
- `ui/rightbar/NetToggleCard.qml`、`ui/rightbar/BtToggleCard.qml` — 扫描跑马灯 1100ms
- `ui/rightbar/NetListCard.qml` — 连接中旋转；`ui/rightbar/BtListCard.qml` — busy 旋转
- `ui/rightbar/UpdStatusCard.qml` — 检查中跑马灯

机制受限未转换（封装组件表达不了，保持原样）：

- `ui/island/MediaWave.qml` `id=waveRoot` 三条 `SmoothedAnimation`：能量
  （velocity 2.6）/ 低频（5.0）把 30fps 的 cava 原始值抹平，播放进度
  （velocity 500）过冲会抖。都是 velocity 驱动，令牌是时长制，表达不了
- `ui/island/MediaWave.qml` `id=waveRoot` 的 `FrameAnimation` — 波形相位按帧积分。
  第 8 轮从 1200ms 无限循环换过来的：速度要跟着能量变，而改正在跑的
  `NumberAnimation` 的 duration 会让波形当帧裂一道口。**逐帧跑 JS，但已用
  `Media.playing && root.visible` 双闸夹住**，不播/不可见就不转
- `ui/island/OverviewCalendar.qml` `id=slideAnim` — 翻页，JS 链式改写 duration
- `ui/frame/RailRipple.qml` `id=birthAnim` — 水波出闸，同样 JS 改写 duration
  （源码里那个 `duration: 200` 是占位，`launch()` 会按半个波长重算）
- `ui/island/WeatherMetricTile.qml` 内的 `RotationAnimation` — 风向，
  依赖 `direction: Shortest` 跨 0° 走最短路径
- `ui/island/WallpaperPage.qml` `id=slideAnim` / `id=punchAnim`、
  `ui/island/HubContent.qml` `id=pageFade` — **时长与曲线全部取自
  `Size.anim.*`，不是泄露**。写成裸 `NumberAnimation` 只因为要有 `id` 供 JS
  `start()/stop()`，`Anim` 那种 `Behavior` 写法给不了。列在这里免得下轮
  审计把它们当成漏网的
- `ui/island/NotifToastContent.qml` — toast 倒计时进度条。**其实没绕开令牌**
  （`duration: Island.notifToastMs`，就是要跟 Timer 同步），源码那句"不走令牌"
  是旧话，留在这里只为说明它为什么长得像白名单项
- ~~`ui/bar/Workspaces.qml` 甜甜圈 flipAnim/settleAnim~~ 第 10 轮删除：
  那圈自转一个人吃 10.6 个百分点 CPU（空闲 11.80% → 0.28%），换成静态药丸了
- ~~`ui/leftbar/Leftbar.qml` / `ui/rightbar/Rightbar.qml` 的 panelAnim~~
  已随第 4 轮改 `RailPage` 消失（2026-09-04 核实）

> 调参记录（各动画时长与几何值的取值和理由，122 行）归档到 `plan-notes.md` 末尾。新调的值继续往那边追加。

