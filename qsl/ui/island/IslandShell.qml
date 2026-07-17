// IslandShell — 灵动岛视觉壳（耳朵 + morph + DropShadow）
// 状态真源：qs.data.state.Island（多屏共享）
//
// 性能：
//   - 无 gooey；DropShadow cached:false + EarCanvas×4
//   - Hub / 一级时钟均用 Loader，关态销毁
//   - 一级无左/右键；无 L2 媒体卡
//
// 关岛：窗口级 FocusScope 吃 Esc（对齐 Leftbar）；Hub 时全屏 mask
// + 点空白关闭。仅主屏 Exclusive，避免多屏抢键导致 Esc 落到黑洞。

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs.data.state

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: islandWindow
        required property var modelData
        screen: modelData

        // 多屏只让第一块抢键盘，否则 Exclusive 互抢，Esc 无处可去
        readonly property bool isKeyOwner: {
            const screens = Quickshell.screens
            return screens.length > 0 && modelData === screens[0]
        }

        readonly property int earRadius: Size.island.earRadius
        readonly property real shadowStrong: 0.72
        readonly property real shadowSoft: 0.5
        readonly property color shadowFill: Qt.rgba(
            Color.shadow.r, Color.shadow.g, Color.shadow.b, shadowStrong)

        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Screen.height
        margins.top: 0
        color: "transparent"
        exclusiveZone: -1

        WlrLayershell.namespace: "qsl-island"
        WlrLayershell.layer: Island.showHub ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.keyboardFocus: (Island.showHub && isKeyOwner)
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        // Hub 全屏可点关；收起只命中岛体
        Item {
            id: hitBoxRegion
            x: Island.showHub ? 0 : maskContainer.x
            y: Island.showHub ? 0 : maskContainer.y
            width: Island.showHub ? islandWindow.width : maskContainer.width
            height: Island.showHub ? islandWindow.height : maskContainer.height
        }
        mask: Region { item: hitBoxRegion }

        // 窗口级按键（必须在根上，不能埋在 Loader 里）
        FocusScope {
            id: keyScope
            anchors.fill: parent
            focus: Island.showHub && islandWindow.isKeyOwner
            enabled: Island.showHub && islandWindow.isKeyOwner

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    Island.closeHub()
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

            // ---------- 阴影源（不可见）----------
            Item {
                id: shadowSource
                anchors.top: maskContainer.top
                anchors.horizontalCenter: maskContainer.horizontalCenter
                width: maskContainer.width
                height: maskContainer.height
                visible: false

                EarCanvas {
                    anchors.right: shadowBody.left
                    anchors.top: shadowBody.top
                    width: islandWindow.earRadius
                    height: islandWindow.earRadius
                    fillColor: islandWindow.shadowFill
                }

                Item {
                    id: shadowBody
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: body.width
                    height: body.height

                    Rectangle {
                        anchors.fill: parent
                        radius: body.radius
                        color: islandWindow.shadowFill

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.radius
                            color: parent.color
                        }
                    }
                }

                EarCanvas {
                    anchors.left: shadowBody.right
                    anchors.top: shadowBody.top
                    width: islandWindow.earRadius
                    height: islandWindow.earRadius
                    mirror: true
                    fillColor: islandWindow.shadowFill
                }
            }

            DropShadow {
                anchors.fill: shadowSource
                source: shadowSource
                horizontalOffset: 0
                verticalOffset: 6
                radius: Size.rounding.xxl
                samples: 25
                color: Qt.rgba(Color.shadow.r, Color.shadow.g, Color.shadow.b, islandWindow.shadowSoft)
                cached: false
            }

            // ---------- 可视岛 ----------
            Item {
                id: maskContainer
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: body.width + islandWindow.earRadius * 2
                height: body.height

                EarCanvas {
                    anchors.right: body.left
                    anchors.top: body.top
                    width: islandWindow.earRadius
                    height: islandWindow.earRadius
                    fillColor: Color.background
                }

                EarCanvas {
                    anchors.left: body.right
                    anchors.top: body.top
                    width: islandWindow.earRadius
                    height: islandWindow.earRadius
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
                        const bar = Size.island.hubTabBarHeight + Size.island.hubContentGap
                        switch (Island.hubTabIndex) {
                        case 1: return bar + Size.island.mediaHeight
                        case 2: return bar + Size.island.wallpaperHeight
                        case 3: return bar + Size.island.weatherHeight
                        case 4: return bar + Size.island.switcherHeight
                        default: return bar + Size.island.overviewHeight
                        }
                    }

                    readonly property int targetW: Island.isHubMode
                        ? (hubLoader.item ? hubLoader.item.implicitWidth : hubFallbackW)
                        : Island.isLyricsMode
                            ? (lyricsLoader.item
                                ? Math.round(lyricsLoader.item.implicitWidth)
                                : Size.island.lyricsW)
                        : Island.isNotifMode ? Size.island.notifW
                        : (Size.island.collapsedW + hoverGrowW)

                    readonly property int targetH: Island.isHubMode
                        ? (hubLoader.item ? hubLoader.item.implicitHeight : hubFallbackH)
                        : Island.isLyricsMode ? Size.island.lyricsH
                        : Island.isNotifMode ? Size.island.notifH
                        : (Size.island.collapsedH + hoverGrowH)

                    readonly property int targetR: (Island.isHubMode || Island.isLyricsMode || Island.isNotifMode)
                        ? Math.round(24 * Size.islandScale)
                        : (Island.isCollapsedMode && hovered
                            ? Math.round(18 * Size.islandScale)
                            : Math.round(16 * Size.islandScale))

                    width: targetW
                    height: targetH
                    property real radius: targetR

                    Behavior on width {
                        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                    }
                    Behavior on radius {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
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

                    Item {
                        anchors.fill: parent
                        anchors.margins: 10
                        visible: Island.isNotifMode

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 2

                            Text {
                                width: parent.width
                                text: Island.notifTitle || "通知"
                                color: Color.textOnBackground
                                font.family: Size.fontSans
                                font.pixelSize: Size.fontSize.md
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: Island.notifBody
                                color: Color.textMuted
                                font.family: Size.fontSans
                                font.pixelSize: Size.fontSize.sm
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // 歌词条：悬停时仍保持加载（只藏 UI），避免 Cava 反复启停
                    Loader {
                        id: lyricsLoader
                        anchors.fill: parent
                        anchors.margins: 4
                        active: (Island.showLyrics || Island.autoLyrics) && !Island.showHub
                        visible: Island.isLyricsMode
                        sourceComponent: LyricsContent {}
                    }

                    Loader {
                        id: hubLoader
                        anchors.centerIn: parent
                        active: Island.showHub
                        visible: Island.showHub
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
                    if (islandWindow.isKeyOwner)
                        Qt.callLater(() => keyScope.forceActiveFocus())
                } else {
                    Island.lyricsHoverRestore = false
                }
            }
        }
    }
}
