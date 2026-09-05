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
// 字体尺寸：
//   fontSize.xsm ~ hero   8 级
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
    // 字体尺寸（8 级，覆盖 90% 使用场景）
    // ============================================================

    readonly property QtObject fontSize: QtObject {
        readonly property int xsm:   11    // 标签/辅助文字
        readonly property int sm:    12    // 正文
        readonly property int md:    14    // 小标题
        readonly property int lg:    16    // 标题
        readonly property int xl:    20    // 大标题
        readonly property int title: 24    // 页面标题
        readonly property int hero:  32    // 超大标题
        readonly property int jumbo: 132   // 特殊装饰
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

        readonly property int hubTabBarHeight: 80
        readonly property int hubContentGap: 10
        readonly property int hubTabSpacing: 15
        readonly property int hubTabIndicatorWidth: 40
        readonly property int hubTabIndicatorHeight: 3

        readonly property int overviewWidth: 860
        readonly property int overviewHeight: 520

        readonly property int mediaWidth: 760
        readonly property int mediaHeight: 480
        readonly property int wallpaperWidth: 860
        readonly property int wallpaperHeight: 540
        readonly property int weatherWidth: 760
        // 旧 540 塞不下 info(220)+分段+预报卡；Hub Loader 还有 margins
        readonly property int weatherHeight: 580
        readonly property int switcherWidth: 900
        readonly property int switcherHeight: 540

        // Overview 用户头像（QQ）
        readonly property string avatarUrl: "https://q1.qlogo.cn/g?b=qq&nk=1303028790&s=640"
    }
}
