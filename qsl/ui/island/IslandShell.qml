// IslandShell — 灵动岛视觉壳（耳朵 + morph + DropShadow）
// 状态真源：qs.data.state.Island（多屏共享）
//
// 性能：
//   - 无 gooey；DropShadow cached:false + EarCanvas×4
//   - Hub / 一级时钟均用 Loader，关态销毁
//   - 一级无左/右键；无 L2 媒体卡

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
        WlrLayershell.keyboardFocus: Island.showHub
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        Item {
            id: hitBoxRegion
            anchors.top: maskContainer.top
            anchors.bottom: maskContainer.bottom
            anchors.left: maskContainer.left
            anchors.right: maskContainer.right
        }
        mask: Region { item: hitBoxRegion }

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
            // 形变时不能 cached，否则阴影形状泄漏
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
                    : Island.isLyricsMode ? Size.island.lyricsW
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

                // 一级时钟：仅收起态实例化（Hub/歌词/通知时销毁）
                Loader {
                    anchors.fill: parent
                    anchors.margins: 6
                    active: Island.isCollapsedMode
                    sourceComponent: ClockContent {}
                }

                // 通知 / 歌词占位（轻量常驻，真正内容后补）
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

                Text {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: Island.isLyricsMode
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: "歌词（待接入）"
                    color: Color.textOnBackground
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.md
                    elide: Text.ElideRight
                }

                Loader {
                    id: hubLoader
                    anchors.centerIn: parent
                    active: Island.showHub
                    visible: Island.showHub
                    sourceComponent: HubContent {}

                    onLoaded: {
                        if (item)
                            Qt.callLater(() => item.forceActiveFocus())
                    }
                }

                Connections {
                    target: Island
                    function onShowHubChanged() {
                        if (!Island.showHub)
                            Island.lyricsHoverRestore = false
                    }
                }
            }
        }
    }
}
