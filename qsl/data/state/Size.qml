pragma Singleton

// ============================================================
// 设计令牌 — Size
// ============================================================
// 全局尺寸真源。所有 UI 模块从这里引用，不再各自定义。
// 命名原则：语义化（非数值化），让 UI 代码可读、统一。
// ============================================================
// 对外接口一览：
//
// 字体家族：
//   fontSans      string   无衬线（正文）
//   fontMono      string   等宽（代码/数字）
//   fontIcon      string   图标字体
//
// 字体尺寸（M3 角色名，非尺寸名）：
//   fontSize.labelSmall ~ displayHero    5 阶 16 级
//
// 图标尺寸（跟排版分开，别混用）：
//   iconSize.xs ~ xxl     6 级
//
// 圆角：
//   rounding.xs ~ xxl / full    7 级
//
// 间距：
//   spacing.xs ~ xl       6 级
//
// 动画：
//   anim.curveSpatial 等 7 条    bezier 控制点（M3 expressive，与 hypr 同族）
//   anim.durFast ~ durSlow       spatial 时长档（位移/尺寸）
//   anim.durFxFast ~ durFxSlow   effects 时长档（透明度/颜色）
//   anim.durTheme                主题换色专用慢档
//   anim.durRipple               rail 行波绕框一趟
//   anim.durWaveDrift            rail 常驻起伏走一个波长
// ============================================================

import QtQuick
import Quickshell
// 自引用本模块，为的是拿 Config：可配的令牌在这里转发，UI 只认 Size（约定 7）
import qs.data.state

Singleton {
    id: root

    // ============================================================
    // 字体家族
    //     sans: 正文 / mono: 代码与数字 / icon: Material Symbols
    //
    //     值由 Config 提供，读取面留在这里：208 个调用点一处不改就拿到了
    //     热重载。默认值不在这一行，在 Config.qml（约定 7）
    // ============================================================

    readonly property string fontSans: Config.font.sans
    readonly property string fontMono: Config.font.mono
    readonly property string fontIcon: Config.font.icon
    readonly property string fontIconRounded: Config.font.iconRounded

    // ============================================================
    // 排版阶（M3 type scale，第 9 轮定案）
    //
    // 原来是 xsm/sm/md/lg/xl/title/hero/jumbo 八级尺寸名。尺寸名只说「多大」，
    // 不说「这是什么」——所以 12px 那一档 83 个调用点里，一半是正文一半是标签，
    // 从名字上完全看不出来，改版时也就没法「把所有标签调小一点」。
    //
    // 换成 M3 的角色名：tier + 三档。同一 px 会对应多个角色（14px 既是
    // bodyMedium 也是 titleSmall 也是 labelLarge），这不是重复，这正是重点——
    // 它们渲染一样，但语义不同，将来要分开调时才有得改。
    //
    // px 值全部沿用换名前的实测值，所以这次改名视觉上零变化。与 M3 规范的
    // 三处偏离，都是「保持现状」而不是「照抄规范」：
    //   · titleLarge 20（规范 22）——xl 这一档全树 8 处，抬到 22 会顶破岛内布局
    //   · displayMedium 44（规范 45）、displayLarge 56（规范 57）——原样保留
    //
    // displayHero 136 是锁屏那个巨型时钟专用，不属于 M3 阶，单列。换名前它叫
    // jumbo 且值是 132，但锁屏写死的是 136——也就是说这个令牌从来没被人用过。
    // ============================================================

    readonly property QtObject fontSize: QtObject {
        // ---- label：芯片、徽标、表头、单位后缀 ----
        readonly property int labelSmall:     11
        readonly property int labelMedium:    12
        readonly property int labelLarge:     14

        // ---- body：正文、说明、列表主文案 ----
        readonly property int bodySmall:      12
        readonly property int bodyMedium:     14
        readonly property int bodyLarge:      16

        // ---- title：卡片标题、分区标题、强调数值 ----
        readonly property int titleSmall:     14
        readonly property int titleMedium:    16
        readonly property int titleLarge:     20

        // ---- headline：页面级标题 ----
        readonly property int headlineSmall:  24
        readonly property int headlineMedium: 28
        readonly property int headlineLarge:  32

        // ---- display：时钟、气温这类一眼扫过去的大数字 ----
        readonly property int displaySmall:   36
        readonly property int displayMedium:  44
        readonly property int displayLarge:   56
        readonly property int displayHero:    136
    }

    // ============================================================
    // 图标尺寸
    //
    // 图标是字形，所以尺寸也走 font.pixelSize——但它不是排版。改名前有 54 处
    // 拿 fontSize 给图标定尺寸，占了 fontSize 全部调用点的两成。混在一起的
    // 后果是：想把正文调大一号，一并把所有图标也放大了。
    //
    // 分出来之后这两条线各走各的。px 沿用原值，本次拆分零视觉变化。
    // ============================================================

    readonly property QtObject iconSize: QtObject {
        readonly property int xs:  11    // 行内角标
        readonly property int sm:  12    // 芯片内图标
        readonly property int md:  14    // 列表行、工具条
        readonly property int lg:  16    // 主操作按钮
        readonly property int xl:  20    // 空态插图、页头
        readonly property int xxl: 24    // 大号状态图标
    }

    // ============================================================
    // 圆角（7 级）— 略偏软，贴近旧 qs 的「圆润」观感
    // ============================================================

    readonly property QtObject rounding: QtObject {
        readonly property int xs:   4     // 小标签
        readonly property int sm:   8     // 按钮/输入框
        readonly property int md:   12    // 卡片内块
        readonly property int lg:   18    // 列表卡片
        readonly property int xl:   26    // 侧栏/通知面板
        readonly property int xxl:  32    // 大弹窗（FreeWindow）
        readonly property int full: 9999  // 胶囊/药丸
    }

    // ============================================================
    // 间距（6 级）
    // ============================================================

    readonly property QtObject spacing: QtObject {
        readonly property int xs:  4      // 紧凑排列
        readonly property int sm:  8      // 默认间距
        readonly property int md:  12     // 区块间距
        readonly property int lg:  16     // 段落间距
        readonly property int xl:  24     // 章节间距
        readonly property int xxl: 32     // 大区块间隔
    }

    // ============================================================
    // 动画 — M3 expressive（与 hypr/lua/appearance.lua 同族）
    //     curve*: cubic-bezier 控制点，喂给 easing.bezierCurve
    //     dur*:   时长档位
    //     spatial 系第二控制点 y>1：到位后过冲回弹（黏滞感来源）
    //     effects 系 y≤1：透明度/颜色专用，过冲会闪
    // ============================================================

    readonly property QtObject anim: QtObject {
        // ---- 曲线 ----
        // bezierCurve 格式：每段 6 个值 = 两个控制点 + 显式终点 (1,1)。
        // 数量不是 6 的倍数 Qt 会静默丢弃整条曲线（退化成线性），不许简写。
        // spatial 只有一条：与 hypr/lua/appearance.lua 的 spatial 同族，
        // 全 shell 位移/尺寸共用，时长由 dur 档控制。
        // 调口味：第二个 y 值 = 弹性强度（1.21 是 hypr 档，1.67 是 M3 上限）
        readonly property var curveSpatial:     [0.38, 1.40, 0.22, 1.00, 1.00, 1.00]  // 位移/尺寸
        readonly property var curveEffects:     [0.34, 0.80, 0.34, 1.00, 1.00, 1.00]  // 透明度/颜色 默认
        readonly property var curveEffectsSlow: [0.34, 0.88, 0.34, 1.00, 1.00, 1.00]  // 透明度/颜色 慢速
        readonly property var curveAccel:       [0.30, 0.00, 0.80, 0.15, 1.00, 1.00]  // 离场加速
        readonly property var curveDecel:       [0.05, 0.70, 0.10, 1.00, 1.00, 1.00]  // 入场减速（不要过冲时用）

        // ---- 时长 ----
        // 七档全部乘 Config.anim.scale：曲线不动，只缩时长。改 config.json
        // 存盘即生效，所有动画当场一起变——调参时开到 2 能看清每一段过渡，
        // 开到 0 就是关掉动画。
        // 这层转发只有 28 个读取点吃到，因为第 2 轮把动画全收进了 Anim/CAnim；
        // spacing/rounding/fontSize 不这么做，它们是字面常量（见架构约定 7）
        readonly property int durFast:   Math.round(400 * Config.anim.scale)  // spatial 快速（悬停展开/容器 morph）
        readonly property int durNormal: Math.round(500 * Config.anim.scale)  // spatial 默认（hypr 窗口同档）
        readonly property int durSlow:   Math.round(650 * Config.anim.scale)  // spatial 慢速
        readonly property int durFxFast: Math.round(150 * Config.anim.scale)  // effects 快速（悬停/按压反馈）
        readonly property int durFx:     Math.round(200 * Config.anim.scale)  // effects 默认
        readonly property int durFxSlow: Math.round(300 * Config.anim.scale)  // effects 慢速
        readonly property int durTheme:  Math.round(600 * Config.anim.scale)  // 主题换色：放慢，留出感受过程的时间
        // rail 水波：波要绕整个框走一趟（1080p 下约 3700px），跟别的档不同量级，
        // 所以单开一个。定时长而不是定速度——出生点不同则路程不同，但一趟总是
        // 这么久，观感才一致。
        // 调了六轮：900 太快（一秒不到就闪完）→ 2600 还跟不住交接 → 7000 嫌慢
        // → 3500（2x）又太快 → 4700（1.5x）→ 波形改矮改长改密之后回到 7000。
        // 最后这一步是跟波形一起定的：单发不再是"一个要盯着看的鼓包"，而是背景
        // 里的一层缓慢涨落，那就该慢。一趟绕框约 5500px，7s 约 780px/s
        readonly property int durRipple: Math.round(7000 * Config.anim.scale)
    }

    // ============================================================
    // 面板几何
    //     值由 Config 提供（读取面仍在这里，见约定 7）。C 的四页原来各自
    //     写着 400，同一个数抄四遍；现在四页共用一个令牌
    // ============================================================

    readonly property QtObject panel: QtObject {
        readonly property int cWidth: Config.panels.cWidth
        readonly property int vWidth: Config.panels.vWidth
        readonly property int nWidth: Config.panels.nWidth
        readonly property int aWidth: Config.panels.aWidth
        readonly property int zWidth: Config.panels.zWidth
        readonly property int zListHeight: Config.panels.zListHeight
        readonly property int xWidth: Config.panels.xWidth
    }

    // ============================================================
    // 灵动岛几何（对齐旧 qs，略收）
    // ============================================================

    readonly property real islandScale: 0.92

    readonly property QtObject island: QtObject {
        readonly property int earRadius: 16

        readonly property int collapsedW: Math.round(220 * root.islandScale)
        readonly property int collapsedH: Math.round(48 * root.islandScale)
        readonly property int lyricsW: Math.round(420 * root.islandScale)
        readonly property int lyricsH: Math.round(42 * root.islandScale)
        readonly property int notifW: Math.round(380 * root.islandScale)
        // 高度见 Island.notifH（count*70+20）

        // 常驻提醒（qsl.md M2）：一级岛提醒形态。比 toast 宽——提醒要常驻到
        // 手动点掉，得容下 alarm 图标 + 标题 + 计划时间 + 「还有 N 条」角标
        readonly property int reminderW: 440
        readonly property int reminderH: 72

        // 图标 24 + 4 + 标签 14 ≈ 55，加指示条一共 64。原来 80 是白留的，
        // 而它是唯一一个五页都要交的税：省下的 16 每页都拿得到
        readonly property int hubTabBarHeight: 64
        readonly property int hubContentGap: 10
        readonly property int hubTabSpacing: 15
        readonly property int hubTabIndicatorWidth: 40
        readonly property int hubTabIndicatorHeight: 3
        // = hubChromeTop(10) + tabBar + gap + hubChromeBottom(12)。
        // HubContent 和 IslandShell.hubFallbackH 两处都得算这笔，所以收成一个数
        readonly property int hubChromeH: 10 + hubTabBarHeight + hubContentGap + 12

        // 第 8 轮：不定统一宽度，但比例要是一家人。
        //
        // 高度不是拍的，是倒着算出来的——先量各页内容的最小可用高，再往上留一点。
        // 上一版凭手感填的数（overview 400 / media 360）比内容还矮，结果待办卡
        // 被顶出岛外、日历格子压到 27px，数字和农历叠在一起。算式记在各页顶部。
        //
        // 加上 hubChromeH 后的整岛宽高比：
        //   overview 880×548 = 1.61   media 820×544 = 1.51
        //   wallpaper 880×420 = 2.10  switcher 880×476 = 1.85
        //   weather 760×636 = 1.20（最高的一页，布局不动）
        // 别再往 3:1 以上走：卷轴第一版做到 1000×336（4.2:1）就是两条信箱。
        // 想让页面扁，办法是减内容（卷轴从 7 张减到 5 张）而不是压高度；
        // 想让页面高，办法是把件放大（switcher 卡 92→140）而不是多塞几行。
        readonly property int overviewWidth: 880
        readonly property int overviewHeight: 452

        // 封面 232 + 左边距 24 + 间距 24 + 右边距 16 → 歌词栏 524
        readonly property int mediaWidth: 820
        readonly property int mediaHeight: 448
        // 卷轴一屏 5 张：margins 20 + 头 42 + 间距 8 = 70，剩 254 装 180 高的焦点卡
        readonly property int wallpaperWidth: 880
        readonly property int wallpaperHeight: 324
        readonly property int weatherWidth: 760
        // 天气页不改布局，允许它做五页里最高的那个（曲线区吃剩下的高）
        readonly property int weatherHeight: 540
        readonly property int switcherWidth: 880
        // 上下留白 8 + 组头 16 + 间距 8 = 32，竖列净高 348；
        // 按 (140+8) 一张算 = 2.4 张——卡变高但一屏还是 2.5 个窗口左右。
        // 400 时两个窗口的工作区底下要空 88px，收到 380 只空 36
        readonly property int switcherHeight: 380
        // 92 时缩略图区是 188×60（3.1:1），窗口截图被压得认不出来；
        // 140 → 188×108（1.74:1），基本就是 16:9
        readonly property int switcherCardHeight: 140
    }
}
