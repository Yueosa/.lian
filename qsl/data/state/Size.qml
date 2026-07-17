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
//   anim.fastIn           bezier 曲线（全局统一）
//   anim.fast / normal / slow  预设 duration
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
    // 动画
    //     fastIn: 全局统一贝塞尔曲线
    //     duration: 预设时长，对应 hypr/appearance.lua 的速度
    // ============================================================

    readonly property QtObject anim: QtObject {
        // 统一曲线 — cubic-bezier(0.16, 1, 0.3, 1)，快入慢停
        readonly property var fastIn: ({ type: Easing.Bezier, points: [0.16, 1, 0.3, 1] })

        // 预设时长
        readonly property int fast:   130   // 拖拽/移动
        readonly property int normal: 170   // 面板收起/窗口关闭
        readonly property int smooth: 200   // 面板弹出/窗口打开
        readonly property int slow:   250   // 工作区切换
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
        readonly property int notifH: Math.round(70 * root.islandScale)

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
