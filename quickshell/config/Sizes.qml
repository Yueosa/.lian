pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    // ================= 原有配置 (保持不变) =================
    readonly property string fontFamily: "Noto Sans CJK SC"
    readonly property string fontFamilyMono: "JetBrainsMono Nerd Font"
    readonly property string fontFamilyMonoCJK: "Noto Sans Mono CJK SC"
    readonly property string fontIcon: "Material Symbols Outlined"
    readonly property string fontIconRounded: "Material Symbols Rounded"
    readonly property string fontAwesome: "Font Awesome 6 Free Solid"
    readonly property string fontSymbolsNerd: "Symbols Nerd Font Mono"
    readonly property real cornerRadius: 10
    readonly property real barHeight: 36
    readonly property real islandScale: 0.92
    readonly property real sidebarScale: 0.90

    // ================= 新增：锁屏专用配置 =================
    readonly property real lockCardRadius: 24   // 卡片大圆角
    readonly property real lockCardPadding: 20  // 卡片内边距
    readonly property real lockIconSize: 24     // 小图标尺寸

    // ================= 新增：结构化尺寸层 =================
    readonly property QtObject rounding: QtObject {
        readonly property real hairline: 1
        readonly property real xxs: 2
        readonly property real xs: 3
        readonly property real xsm: 5
        readonly property real sm: 6
        readonly property real splus: 7
        readonly property real small: 8
        readonly property real md: 9
        readonly property real medium: 10
        readonly property real normal: 12
        readonly property real normalPlus: 13
        readonly property real chip: 14
        readonly property real chipPlus: 15
        readonly property real large: 16
        readonly property real xl: 18
        readonly property real xxl: 20
        readonly property real xxlPlus: 21
        readonly property real card: 22
        readonly property real xlarge: 24
        readonly property real xxxl: 26
        readonly property real pill: 30
        readonly property real bubble: 36
        readonly property real jumbo: 40
        readonly property real full: 9999
    }

    readonly property QtObject spacing: QtObject {
        readonly property real none: 0
        readonly property real hairline: 1
        readonly property real xxs: 2
        readonly property real xxxs: 3
        readonly property real xs: 4
        readonly property real xsm: 5
        readonly property real s: 6
        readonly property real splus: 7
        readonly property real sm: 8
        readonly property real m: 10
        readonly property real md: 12
        readonly property real l: 14
        readonly property real lplus: 15
        readonly property real lg: 16
        readonly property real xxl: 18
        readonly property real xl: 20
        readonly property real section: 24
        readonly property real sectionPlus: 30
        readonly property real panelGap: 28
        readonly property real block: 32
        readonly property real blockPlus: 36
        readonly property real panelPadding: 20
    }

    readonly property QtObject animation: QtObject {
        readonly property QtObject fast: QtObject {
            readonly property int duration: 180
            readonly property int type: Easing.OutCubic
        }
        readonly property QtObject normal: QtObject {
            readonly property int duration: 260
            readonly property int type: Easing.OutCubic
        }
        readonly property QtObject smooth: QtObject {
            readonly property int duration: 360
            readonly property int type: Easing.OutQuint
        }
    }

    // ================= 灵动岛几何 (单一来源) =================
    // 所有 Hub / Overview 相关的尺寸都从这里推导，避免阴影挖洞与
    // 实际控制中心卡片错位。
    readonly property QtObject island: QtObject {
        // Hub 内部布局
        readonly property int hubTabBarHeight: 80
        readonly property int hubContentGap: 10
        readonly property int hubTabSpacing: 15
        readonly property int hubTabIndicatorWidth: 40
        readonly property int hubTabIndicatorHeight: 3

        // Overview 标签页几何
        readonly property int overviewWidth: 860
        readonly property int overviewHeight: 520
        readonly property int overviewMargin: 32
        readonly property int overviewSpacing: 24
        readonly property int overviewSliderColW: 48
        readonly property int overviewSysColW: 320

        // 控制中心镂空（阴影层）的四向内缩
        // 这些参数只影响 shadow hole 的大小，不影响卡片本身的大小。
        // 缩小左右内缩，避免按钮在水平方向溢出；
        // 给上下留少量余量，避免镂空视觉上“顶出”卡片边界。
        readonly property int ccHoleLeftInset: 12
        readonly property int ccHoleRightInset: 12
        readonly property int ccHoleVerticalInset: 8
        readonly property int ccHoleYOffset: 9

        // 由上面派生：控制中心 SolidGlassCard 在 Hub 根坐标里的位置
        readonly property int ccHoleTop: hubTabBarHeight + hubContentGap + overviewMargin + ccHoleVerticalInset + ccHoleYOffset
        readonly property int ccHoleHeight: overviewHeight - 2 * overviewMargin - 2 * ccHoleVerticalInset
        readonly property int ccHoleLeftFromCenter:
            overviewMargin + overviewSliderColW + overviewSpacing
            + overviewSysColW + overviewSpacing - overviewWidth / 2
            + ccHoleLeftInset
        readonly property int ccHoleWidth:
            overviewWidth - overviewMargin
            - (overviewWidth / 2 + ccHoleLeftFromCenter)
            - ccHoleRightInset
        readonly property real ccHoleRadius: 24

        // 控制中心玻璃卡视觉
        readonly property real glassCardAlpha: 0.55
        readonly property real glassCardBorderAlpha: 0.35
    }

    // ================= 字体级别 =================
    readonly property QtObject font: QtObject {
        readonly property int hairline: 9
        readonly property int xs: 10
        readonly property int xsm: 11
        readonly property int sm: 12
        readonly property int md: 13
        readonly property int lg: 14
        readonly property int body: 15
        readonly property int xl: 16
        readonly property int xxl: 18
        readonly property int hero: 19
        readonly property int title: 20
        readonly property int h1: 22
        readonly property int h2: 24
        readonly property int h2b: 26
        readonly property int h3: 28
        readonly property int h3b: 30
        readonly property int h4: 32
        readonly property int h5: 36
        readonly property int h5b: 40
        readonly property int h5c: 44
        readonly property int h6: 42
        readonly property int h7: 56
        readonly property int jumbo: 132
        readonly property int display: 24
    }

    // ================= 面板/侧栏 =================
    readonly property QtObject panel: QtObject {
        readonly property int sidebarMargin: 12
        readonly property int sidebarSpacing: 16
        readonly property int cardPadding: 16
        readonly property int cardSpacing: 12
        readonly property int sectionGap: 20
        readonly property int rowHeight: 44
        readonly property int iconBoxSize: 36
        readonly property int controlChipHeight: 36
    }

    // ================= Overview 控制中心字体规范 =================
    readonly property QtObject controlCenter: QtObject {
        readonly property int tileIconFont: root.font.xl
        readonly property int tileTitleFont: root.font.md
        readonly property int chargingCurrentIconFont: root.font.lg
        readonly property int chargingLabelFont: root.font.sm
        readonly property int chargingExpandedIconFont: root.font.md
        readonly property int cornerIconFont: root.font.xxl
        readonly property int prefsHeaderFont: root.font.sm
        readonly property int prefsSectionFont: root.font.hairline
        readonly property int prefsChipIconFont: root.font.sm
        readonly property int prefsChipLabelFont: root.font.hairline
        readonly property int prefsSliderLabelFont: root.font.hairline
        readonly property int prefsSliderValueFont: root.font.xs
        readonly property int prefsHintFont: root.font.xs
    }

    // ================= 灵动岛歌词胶囊 =================
    readonly property QtObject lyricsCapsule: QtObject {
        readonly property int defaultTextWidth: 170
        readonly property int horizontalPadding: 15
        readonly property int coverWidth: 26
        readonly property int spectrumWidth: 21
        readonly property int sectionGap: 12
        readonly property int spectrumHeight: 16
        readonly property int lyricRowHeight: 42
        readonly property int reloadDebounceMs: 300
        readonly property int syncPollMs: 100
        readonly property int spectrumTickMs: 16
        readonly property int marqueeDelayMs: 800
    }

    // ================= 通知 =================
    readonly property QtObject notif: QtObject {
        readonly property int rowHeight: 70
        readonly property int popupWidth: 380
        readonly property int popupGap: 8
        readonly property int iconSize: 40
        readonly property int closeBtn: 18
    }
}
