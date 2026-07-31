// WallpaperPage — Hub 壁纸页
// prev/next/mode + 网格单击设壁纸；齿轮开 lianwall-gui 并关岛
// 缩略图：LianWall 缓存优先；静态图无缓存时小 sourceSize 原图；视频无缓存占位
// 开销：仅 detail 时拉列表；GridView cacheBuffer≈1 行；Image 异步且 cache:false

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.data.state
import qs.data.service

FocusScope {
    id: root

    property int focusIndex: 0
    readonly property int gridColumns: Math.max(2, Math.floor(grid.width / 178))

    Component.onCompleted: {
        Lianwall.setDetailActive(true)
        forceActiveFocus()
    }
    Component.onDestruction: Lianwall.setDetailActive(false)

    function clampFocus() {
        if (grid.count <= 0) {
            focusIndex = 0
            return
        }
        focusIndex = Math.max(0, Math.min(grid.count - 1, focusIndex))
        grid.currentIndex = focusIndex
        grid.positionViewAtIndex(focusIndex, GridView.Contain)
    }

    function moveFocus(delta) {
        if (grid.count <= 0)
            return
        focusIndex = Math.max(0, Math.min(grid.count - 1, focusIndex + delta))
        clampFocus()
    }

    function activateFocused() {
        const it = Lianwall.items[focusIndex]
        if (it && it.path)
            Lianwall.setWallpaper(it.path)
    }

    Connections {
        target: Lianwall
        function onItemsChanged() { Qt.callLater(root.clampFocus) }
    }

    Keys.onLeftPressed: (e) => { moveFocus(-1); e.accepted = true }
    Keys.onRightPressed: (e) => { moveFocus(1); e.accepted = true }
    Keys.onUpPressed: (e) => { moveFocus(-gridColumns); e.accepted = true }
    Keys.onDownPressed: (e) => { moveFocus(gridColumns); e.accepted = true }
    Keys.onReturnPressed: (e) => { activateFocused(); e.accepted = true }
    Keys.onEnterPressed: (e) => { activateFocused(); e.accepted = true }

    component RailButton: Rectangle {
        id: button
        property string icon: ""
        property bool active: false
        property color accentColor: Color.primary
        signal clicked()

        Layout.preferredWidth: 48
        Layout.preferredHeight: 48
        radius: Size.rounding.xl
        color: active
            ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
            : Color.surfaceHighest
        border.width: active ? 1 : 0
        border.color: active
            ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.42)
            : "transparent"
        scale: area.pressed ? 0.92 : (area.containsMouse ? 1.04 : 1.0)

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on scale {
            NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
        }

        Text {
            anchors.centerIn: parent
            text: button.icon
            font.family: Size.fontMono
            font.pixelSize: Size.fontSize.xl
            color: button.active ? button.accentColor : Color.textOnBackground
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        radius: Size.rounding.xl
        color: Color.surface

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: Size.spacing.lg

            ColumnLayout {
                Layout.preferredWidth: 48
                Layout.fillHeight: true
                spacing: Size.spacing.md

                RailButton {
                    icon: "\uf048"
                    onClicked: Lianwall.previous()
                }
                RailButton {
                    icon: "\uf051"
                    onClicked: Lianwall.next()
                }
                RailButton {
                    icon: Lianwall.modeIcon
                    active: true
                    accentColor: Lianwall.isVideoMode ? Color.tertiary : Color.primary
                    onClicked: Lianwall.switchMode()
                }

                Item { Layout.fillHeight: true }

                RailButton {
                    icon: "\uf013"
                    accentColor: Color.secondary
                    onClicked: {
                        Lianwall.openGui()
                        Island.closeHub()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Size.spacing.md

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    spacing: Size.spacing.md

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: Size.rounding.lg
                        color: Qt.rgba(Color.primary.r, Color.primary.g, Color.primary.b, 0.16)

                        Text {
                            anchors.centerIn: parent
                            text: Lianwall.modeIcon
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.lg
                            color: Color.primary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: Lianwall.modeLabel + "模式 · " + (Lianwall.engine || "--")
                            color: Color.textOnBackground
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.lg
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "可用 " + Lianwall.availableCount
                                + " · 总计 " + Lianwall.totalCount
                                + " · 锁定 " + Lianwall.lockedCount
                            color: Color.textMuted
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.xsm
                            elide: Text.ElideRight
                        }
                    }
                }

                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: Lianwall.items
                    currentIndex: root.focusIndex
                    cellWidth: Math.floor(width / Math.max(1, root.gridColumns))
                    cellHeight: 148
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: cellHeight * 1

                    ScrollBar.vertical: ScrollBar {
                        policy: grid.contentHeight > grid.height
                            ? ScrollBar.AsNeeded
                            : ScrollBar.AlwaysOff
                        width: 6
                    }

                    delegate: Item {
                        id: card
                        required property var modelData
                        required property int index

                        width: grid.cellWidth
                        height: grid.cellHeight

                        readonly property string wallpaperPath: String(modelData.path || "")
                        readonly property string wallpaperFilename: String(modelData.filename || "")
                        readonly property string thumbPath: String(modelData.thumb || "")
                        readonly property bool thumbOrig: !!modelData.thumb_orig
                        readonly property bool wallpaperLocked: !!modelData.locked
                        readonly property bool wallpaperIsCurrent: !!modelData.is_current
                        readonly property bool wallpaperIsVideo: !!modelData.is_video
                        readonly property bool hasThumbnail: thumbPath.length > 0
                        readonly property string thumbnailSource: hasThumbnail
                            ? ("file://" + thumbPath)
                            : ""
                        readonly property bool focused: root.focusIndex === index

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: Size.rounding.md
                            color: card.focused
                                ? Qt.rgba(Color.primary.r, Color.primary.g, Color.primary.b, 0.16)
                                : Color.surfaceHigh
                            border.width: card.focused || card.wallpaperIsCurrent ? 2 : 1
                            border.color: card.wallpaperIsCurrent
                                ? Color.primary
                                : (card.focused
                                    ? Qt.rgba(Color.primary.r, Color.primary.g, Color.primary.b, 0.72)
                                    : Color.outlineVariant)

                            Rectangle {
                                id: thumbBox
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 6
                                height: 102
                                radius: Size.rounding.sm
                                color: Color.surfaceHighest
                                clip: true

                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    // 离开页 visible=false 时清空 source，避免离屏解码
                                    source: (root.visible && card.hasThumbnail)
                                        ? card.thumbnailSource
                                        : ""
                                    // 原图回退更严；缓存缩略图可稍大
                                    sourceSize.width: card.thumbOrig ? 200 : 256
                                    sourceSize.height: card.thumbOrig ? 126 : 160
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    visible: card.hasThumbnail && status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: card.wallpaperIsVideo ? "\uf03d" : "\uf03e"
                                    font.family: Size.fontMono
                                    font.pixelSize: 28
                                    color: Color.textMuted
                                    visible: !thumbImg.visible
                                }

                                Row {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: 6
                                    spacing: 4

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: Size.rounding.full
                                        color: Qt.rgba(Color.primary.r, Color.primary.g, Color.primary.b, 0.9)
                                        visible: card.wallpaperIsCurrent
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf04b"
                                            font.family: Size.fontMono
                                            font.pixelSize: Size.fontSize.xsm
                                            color: Color.textOnPrimary
                                        }
                                    }
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: Size.rounding.full
                                        color: Qt.rgba(0, 0, 0, 0.55)
                                        visible: card.wallpaperLocked
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf023"
                                            font.family: Size.fontMono
                                            font.pixelSize: Size.fontSize.xsm
                                            color: Color.textOnBackground
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 6
                                    width: 22
                                    height: 22
                                    radius: Size.rounding.full
                                    color: Qt.rgba(0, 0, 0, 0.5)
                                    Text {
                                        anchors.centerIn: parent
                                        text: card.wallpaperIsVideo ? "\uf03d" : "\uf03e"
                                        font.family: Size.fontMono
                                        font.pixelSize: Size.fontSize.xsm
                                        color: Color.textOnBackground
                                    }
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                height: 24
                                text: card.wallpaperFilename
                                color: card.wallpaperIsCurrent
                                    ? Color.primary
                                    : Color.textOnBackground
                                font.family: Size.fontSans
                                font.pixelSize: Size.fontSize.xsm
                                font.bold: card.wallpaperIsCurrent
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.focusIndex = card.index
                                    root.clampFocus()
                                    Lianwall.setWallpaper(card.wallpaperPath)
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Lianwall.error.length > 0 ? Lianwall.error : "暂无壁纸"
                        visible: grid.count === 0 && !Lianwall.loading
                        color: Color.textMuted
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.lg
                    }
                }
            }
        }
    }
}
