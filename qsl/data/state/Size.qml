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
// ============================================================

import QtQuick
import Quickshell

Singleton {
    id: root

    // ============================================================
    // 字体家族
    //     sans: 正文 / mono: 代码与数字 / icon: Material Symbols
    // ============================================================

    readonly property string fontSans: "Noto Sans CJK SC"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property string fontIcon: "Material Symbols Outlined"
    readonly property string fontIconRounded: "Material Symbols Rounded"

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
        readonly property int durFast:   400    // spatial 快速（悬停展开/容器 morph）
        readonly property int durNormal: 500    // spatial 默认（hypr 窗口同档）
        readonly property int durSlow:   650    // spatial 慢速
        readonly property int durFxFast: 150    // effects 快速（悬停/按压反馈）
        readonly property int durFx:     200    // effects 默认
        readonly property int durFxSlow: 300    // effects 慢速
        readonly property int durTheme:  600    // 主题换色：放慢，留出感受过程的时间
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
