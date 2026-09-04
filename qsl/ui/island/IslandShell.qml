// IslandShell — 灵动岛视觉壳（耳朵 + morph），窗内 item
// 状态真源：qs.data.state.Island（多屏共享）
//
// plan 第 6 轮起不再自带窗口：原先它是一个全屏 PanelWindow，自己管层级、
// 独占焦点和 mask。现在画在 FrameWindow 里，那三件窗口级职责上交给框窗聚合
// （框窗只有一个 layer / 一个 keyboardFocus / 一个 mask，得把所有租户的诉求
// 并起来），本文件通过 wantsOverlay / wantsKeyboard / hitBox 三个只读属性
// 把诉求报上去。
//
// morph 动画不受影响：它一直是 body 的 width/height/radius 上的 Behavior，
// 从来就是 item 级的，不是靠改窗口 buffer 尺寸做的。
//
// 性能：
//   - 无 gooey、无 DropShadow（阴影源/离屏已去掉）
//   - Hub / 一级时钟均用 Loader，关态销毁
//   - 关态 hitBox 只圈岛体，不挡桌面
//   - 一级无左/右键；无 L2 媒体卡
//
// 关岛：FocusScope 吃 Esc；Hub 时全屏 hitBox + 点空白关闭。
// 仅主屏申请键盘，避免多屏抢键导致 Esc 落到黑洞。

import QtQuick
import qs.Components
import qs.data.state

Item {
    id: root

    // 多屏只让第一块抢键盘，否则 Exclusive 互抢，Esc 无处可去。由框窗传入
    required property bool isKeyOwner

    // 焦点栈里的身份。互斥组 "center"（见 Panels）：将来 A=启动器同区
    readonly property string panelId: "qsl-island"
    readonly property string panelGroup: "center"

    // ---- 报给 FrameWindow 的三项窗口级诉求 ----
    // Hub 卸载前保持 Overlay，避免关岛瞬间 Overlay→Top 闪一帧
    readonly property bool wantsOverlay: Island.showHub || Island.overlayLayer || hubMounted
    readonly property bool wantsKeyboard: (Island.showHub || hubMounted) && isKeyOwner
    // Hub 全屏可点关；收起只命中岛体
    readonly property Item hitBox: hitBoxRegion

    readonly property int earRadius: Size.island.earRadius

    // Hub 视觉保活：showHub=false 后仍挂载至 morph 结束，先淡出再拆
    property bool hubMounted: Island.showHub
    Timer {
        id: hubUnmountTimer
        interval: 360
        repeat: false
        onTriggered: root.hubMounted = false
    }

    // morph 起跑闸：hubMounted 置真那一下 hubLoader 同步建出整个 HubContent，
    // 实测把主线程堵住 34~60ms。而 Qt 的统一动画时钟在阻塞期间照走，于是在
    // 同一帧改 morph 目标的话，动画起点会被记成阻塞开始前那个 tick——下一帧
    // 画出来时它已经自己跑掉三成（实测首帧岛宽从 202 直接跳到 482，就是你看
    // 到的"展开时抖一下"）。所以先建内容，等一个真正的帧边界再放行目标值：
    // 起跑晚一帧，但起跑点是对的。
    property bool hubShaped: false
    // 条件必须挂 showHub 而不是 hubMounted：关岛时 hubMounted 还要留 360ms 做
    // 淡出，只看 hubMounted 的话闸门会在收起动画刚起步时又自己合上，岛就再也
    // 收不回去了
    // 要等两帧：第一帧就是被同步创建堵住的那帧，在它上面起跑等于起点还是脏的
    property int _shapeFrames: 0
    FrameAnimation {
        running: Island.showHub && root.hubMounted && !root.hubShaped
        onTriggered: {
            root._shapeFrames += 1
            if (root._shapeFrames >= 2)
                root.hubShaped = true
        }
    }

    Item {
        id: hitBoxRegion
        x: Island.showHub ? 0 : maskContainer.x
        y: Island.showHub ? 0 : maskContainer.y
        width: Island.showHub ? root.width : maskContainer.width
        height: Island.showHub ? root.height : maskContainer.height
    }

    // 按键作用域
    // 注意：不能 enabled: showHub，否则一级 toast/悬停全部收不到指针
    FocusScope {
        id: keyScope
        anchors.fill: parent
        // 栈顶条件：合并框窗只有一个 activeFocusItem，而 Hub 开着时还能开 C/V
        // （不同区域，不互斥）。谁响应 Esc 由 Panels 的焦点栈裁决
        focus: Island.showHub && root.isKeyOwner
            && Panels.keyboardOwner === root.panelId

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                Island.closeHub()
                event.accepted = true
                return
            }
            // Switcher：Enter 在壳层处理，避免子页 Keys/Shortcut 双触
            if (Island.showHub && Island.hubTabIndex === 4
                && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                Island.activateSwitcherFocus()
                event.accepted = true
                return
            }
            // Tab 切页：转发给 Hub（若已加载）
            if (hubLoader.item) {
                if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ControlModifier)) {
                    hubLoader.item.currentIndex = (hubLoader.item.currentIndex + 1) % 5
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Backtab) {
                    hubLoader.item.currentIndex = (hubLoader.item.currentIndex + 4) % 5
                    event.accepted = true
                }
            }
        }

        // Hub 时点岛外空白关闭
        MouseArea {
            anchors.fill: parent
            enabled: Island.showHub
            onClicked: Island.closeHub()
        }

        // ---------- 可视岛 ----------
        Item {
            id: maskContainer
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: body.width + root.earRadius * 2
            height: body.height
            z: 1

            EarCanvas {
                anchors.right: body.left
                anchors.top: body.top
                width: root.earRadius
                height: root.earRadius
                fillColor: Color.background
            }

            EarCanvas {
                anchors.left: body.right
                anchors.top: body.top
                width: root.earRadius
                height: root.earRadius
                mirror: true
                fillColor: Color.background
            }

            Item {
                id: body
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                clip: true
                z: 100

                readonly property bool hovered: islandMouse.containsMouse
                readonly property int hoverGrowW: Island.isCollapsedMode && hovered ? 16 : 0
                readonly property int hoverGrowH: Island.isCollapsedMode && hovered ? 6 : 0

                readonly property int hubFallbackW: {
                    switch (Island.hubTabIndex) {
                    case 1: return Size.island.mediaWidth
                    case 2: return Size.island.wallpaperWidth
                    case 3: return Size.island.weatherWidth
                    case 4: return Size.island.switcherWidth
                    default: return Size.island.overviewWidth
                    }
                }
                readonly property int hubFallbackH: {
                    // 与 HubContent.implicitHeight 对齐：chromeTop(10)+tab+gap+page+chromeBottom(12)
                    const chrome = 10 + 12
                    const bar = Size.island.hubTabBarHeight + Size.island.hubContentGap
                    switch (Island.hubTabIndex) {
                    case 1: return chrome + bar + Size.island.mediaHeight
                    case 2: return chrome + bar + Size.island.wallpaperHeight
                    case 3: return chrome + bar + Size.island.weatherHeight
                    case 4: return chrome + bar + Size.island.switcherHeight
                    default: return chrome + bar + Size.island.overviewHeight
                    }
                }

                // 这里读 hubShaped 而不是 Island.isHubMode：见 hubShaped 的说明，
                // 内容还没建完就改目标值，动画会从中途开始
                readonly property int targetW: root.hubShaped
                    ? (hubLoader.item ? hubLoader.item.implicitWidth : hubFallbackW)
                    : Island.isLyricsMode
                        ? (lyricsLoader.item
                            ? Math.round(lyricsLoader.item.implicitWidth)
                            : Size.island.lyricsW)
                    : Island.isNotifMode ? Size.island.notifW
                    : (Size.island.collapsedW + hoverGrowW)

                readonly property int targetH: root.hubShaped
                    ? (hubLoader.item ? hubLoader.item.implicitHeight : hubFallbackH)
                    : Island.isLyricsMode ? Size.island.lyricsH
                    : Island.isNotifMode ? Island.notifH
                    : (Size.island.collapsedH + hoverGrowH)

                readonly property int targetR: (root.hubShaped || Island.isLyricsMode || Island.isNotifMode)
                    ? Math.round(24 * Size.islandScale)
                    : (Island.isCollapsedMode && hovered
                        ? Math.round(18 * Size.islandScale)
                        : Math.round(16 * Size.islandScale))

                width: targetW
                height: targetH
                property real radius: targetR

                Behavior on width {
                    Anim { type: Anim.SpatialFast }
                }
                Behavior on height {
                    Anim { type: Anim.SpatialFast }
                }
                Behavior on radius {
                    Anim { type: Anim.SpatialFast }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: body.radius
                    color: Color.background

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.radius
                        color: parent.color
                    }
                }

                // 挡住外层「点空白关闭」，避免点 Hub 内容也关
                MouseArea {
                    anchors.fill: parent
                    enabled: Island.showHub
                    onClicked: {}
                }

                MouseArea {
                    id: islandMouse
                    anchors.fill: parent
                    enabled: !Island.isNotifMode
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onContainsMouseChanged: {
                        if (Island.showLyrics || Island.autoLyrics)
                            Island.lyricsHoverRestore = containsMouse
                    }
                }

                Loader {
                    anchors.fill: parent
                    anchors.margins: 6
                    active: Island.isCollapsedMode
                    visible: Island.isCollapsedMode
                    sourceComponent: ClockContent {}
                }

                // 通知堆叠：≤3 + 进度条（对齐旧 DI）
                // active 不跟 showHub 绑死——Hub 打开时若卸掉 Loader，Timer 停转，
                // 关岛后旧 toast 会「复活」并卡住倒计时。
                Loader {
                    id: notifLoader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    height: Math.max(0, Island.notifH - 20)
                    z: 300
                    active: Island.notifCount > 0
                    visible: Island.isNotifMode
                    sourceComponent: NotifToastContent {}
                }

                // 点通知关：挂在 Loader 之上，不依赖 delegate 内 MouseArea
                MouseArea {
                    anchors.fill: notifLoader
                    enabled: Island.isNotifMode
                    z: 301
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        const spacing = Math.round(10 * Size.islandScale)
                        const pitch = 60 + spacing
                        let idx = Math.floor(mouse.y / pitch)
                        if (idx < 0)
                            idx = 0
                        if (idx >= Island.notifCount)
                            idx = Island.notifCount - 1
                        Island.clearNotifIndex(idx)
                    }
                }

                // 歌词条：按 implicitWidth 定宽（勿 fill，否则 toast 会压扁导致切回后歪/溢出）
                // 悬停/toast 时仍保持加载（只藏 UI），避免 Cava 反复启停
                Loader {
                    id: lyricsLoader
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: item ? Math.round(item.implicitWidth) : Size.island.lyricsW
                    height: Size.island.lyricsH
                    z: 1
                    active: (Island.showLyrics || Island.autoLyrics) && !Island.showHub
                    visible: Island.isLyricsMode
                    // 隐藏时禁用，防止挡 toast 点击
                    enabled: Island.isLyricsMode
                    sourceComponent: LyricsContent {}
                }

                Loader {
                    id: hubLoader
                    anchors.centerIn: parent
                    // 异步孵化：同步建整个 HubContent 实测堵主线程 34~60ms，就是
                    // 展开那一下的硬顿。异步是分片建（每帧切一小块），所以没有
                    // 单次长阻塞。morph 不用等它——targetW/H 会先用 hubFallback
                    // （照 HubContent.implicitHeight 的公式算的，尺寸对得上），
                    // item 建好后自然接管，中途只是一次平滑改目标
                    asynchronous: true
                    active: root.hubMounted
                    visible: root.hubMounted
                    opacity: Island.showHub ? 1 : 0
                    Behavior on opacity {
                        Anim { type: Anim.EffectsFast }
                    }
                    sourceComponent: HubContent {
                        onCloseRequested: Island.closeHub()
                    }
                }
            }
        }
    }

    Connections {
        target: Island
        function onShowHubChanged() {
            if (Island.showHub) {
                hubUnmountTimer.stop()
                root.hubMounted = true
                // 只有主屏那份进焦点栈：多屏时另外几份不该跟着抢 Esc
                if (root.isKeyOwner) {
                    Panels.claim(root.panelId, root.panelGroup)
                    Qt.callLater(() => keyScope.forceActiveFocus())
                }
            } else {
                root.hubShaped = false
                root._shapeFrames = 0
                Island.lyricsHoverRestore = false
                if (root.isKeyOwner)
                    Panels.release(root.panelId)
                // 保持 Hub 节点做淡出，morph 后再拆
                hubUnmountTimer.restart()
            }
        }
    }

    Connections {
        target: Panels

        // 被同区面板（将来的 A）挤掉：自己关 Hub
        function onEvicted(id) {
            if (id === root.panelId)
                Island.closeHub()
        }

        // 栈顶换人时主动夺焦，理由同 RailPage 里那条
        function onKeyboardOwnerChanged() {
            if (Island.showHub && root.isKeyOwner
                && Panels.keyboardOwner === root.panelId)
                Qt.callLater(() => keyScope.forceActiveFocus())
        }
    }
}
