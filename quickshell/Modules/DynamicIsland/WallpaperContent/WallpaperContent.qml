import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Clavis.Lianwall 1.0
import qs.config

FocusScope {
    id: root
    signal closeRequested()

    implicitWidth: 860
    implicitHeight: 540
    focus: visible

    property int focusIndex: 0
    readonly property int gridColumns: Math.max(2, Math.floor(grid.width / 178))

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
        const path = LianwallPlugin.wallpapers.pathAt(focusIndex)
        if (path && path.length > 0)
            LianwallPlugin.setWallpaper(path)
    }

    onEnabledChanged: if (enabled) {
        LianwallPlugin.refresh()
        focusGrabber.forceActiveFocus()
        Qt.callLater(clampFocus)
    }

    Connections {
        target: LianwallPlugin
        function onDataChanged() { Qt.callLater(root.clampFocus) }
    }

    component RailButton : Rectangle {
        id: button
        property string icon: ""
        property string tooltip: ""
        property bool active: false
        property color accentColor: Colorscheme.primary

        signal clicked()

        Layout.preferredWidth: 48
        Layout.preferredHeight: 48
        radius: Sizes.rounding.xlarge
        color: active
            ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
            : Colorscheme.surface_container_highest
        border.width: active ? 1 : 0
        border.color: active ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.42) : "transparent"
        scale: area.pressed ? 0.92 : (area.containsMouse ? 1.04 : 1.0)

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: button.icon
            font.family: Sizes.fontAwesome
            font.pixelSize: Sizes.font.xxl
            color: button.active ? button.accentColor : Colorscheme.on_surface
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }

        ToolTip.visible: area.containsMouse
        ToolTip.delay: 450
        ToolTip.text: button.tooltip
    }

    Item {
        id: focusGrabber
        anchors.fill: parent
        focus: root.enabled
        Keys.onLeftPressed: (event) => { root.moveFocus(-1); event.accepted = true }
        Keys.onRightPressed: (event) => { root.moveFocus(1); event.accepted = true }
        Keys.onUpPressed: (event) => { root.moveFocus(-root.gridColumns); event.accepted = true }
        Keys.onDownPressed: (event) => { root.moveFocus(root.gridColumns); event.accepted = true }
        Keys.onReturnPressed: (event) => { root.activateFocused(); event.accepted = true }
        Keys.onEnterPressed: (event) => { root.activateFocused(); event.accepted = true }
        Keys.onEscapePressed: (event) => { root.closeRequested(); event.accepted = true }
    }

    Shortcut { sequence: "Left"; enabled: root.enabled && !focusGrabber.activeFocus; onActivated: root.moveFocus(-1) }
    Shortcut { sequence: "Right"; enabled: root.enabled && !focusGrabber.activeFocus; onActivated: root.moveFocus(1) }
    Shortcut { sequence: "Up"; enabled: root.enabled && !focusGrabber.activeFocus; onActivated: root.moveFocus(-root.gridColumns) }
    Shortcut { sequence: "Down"; enabled: root.enabled && !focusGrabber.activeFocus; onActivated: root.moveFocus(root.gridColumns) }
    Shortcut { sequences: ["Return", "Enter"]; enabled: root.enabled && !focusGrabber.activeFocus; onActivated: root.activateFocused() }
    Shortcut { sequence: "Escape"; enabled: root.enabled && !focusGrabber.activeFocus; onActivated: root.closeRequested() }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        radius: Sizes.rounding.xlarge
        color: Colorscheme.surface_container_low

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: Sizes.spacing.lg

            ColumnLayout {
                Layout.preferredWidth: 48
                Layout.fillHeight: true
                spacing: Sizes.spacing.md

                RailButton {
                    icon: ""
                    tooltip: "上一张"
                    onClicked: LianwallPlugin.previous()
                }

                RailButton {
                    icon: ""
                    tooltip: "下一张"
                    onClicked: LianwallPlugin.next()
                }

                RailButton {
                    icon: LianwallPlugin.modeIcon
                    tooltip: "切换模式：" + LianwallPlugin.modeLabel
                    active: true
                    accentColor: LianwallPlugin.mode === "Video" ? Colorscheme.tertiary : Colorscheme.primary
                    onClicked: LianwallPlugin.switchMode()
                }

                RailButton {
                    icon: ""
                    tooltip: "打开 lianwall-gui"
                    accentColor: Colorscheme.secondary
                    onClicked: {
                        LianwallPlugin.openGui()
                        root.closeRequested()
                    }
                }

                Item { Layout.fillHeight: true }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Sizes.spacing.md

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    spacing: Sizes.spacing.md

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: Sizes.rounding.xl
                        color: Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.16)

                        Text {
                            anchors.centerIn: parent
                            text: LianwallPlugin.modeIcon
                            font.family: Sizes.fontAwesome
                            font.pixelSize: Sizes.font.xl
                            color: Colorscheme.primary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: LianwallPlugin.modeLabel + "模式 · " + (LianwallPlugin.engine || "--")
                            color: Colorscheme.on_surface
                            font.pixelSize: Sizes.font.lg
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "可用 " + LianwallPlugin.availableCount + " · 总计 " + LianwallPlugin.totalWallpapers + " · 锁定 " + LianwallPlugin.lockedCount
                            color: Colorscheme.on_surface_variant
                            font.pixelSize: Sizes.font.xs
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: Sizes.rounding.xl
                        color: refreshArea.containsMouse ? Colorscheme.surface_container_highest : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: Sizes.fontAwesome
                            font.pixelSize: Sizes.font.lg
                            color: LianwallPlugin.loading ? Colorscheme.primary : Colorscheme.on_surface_variant
                            RotationAnimation on rotation {
                                running: LianwallPlugin.loading
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                            }
                        }

                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LianwallPlugin.refresh()
                        }

                    }
                }

                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: LianwallPlugin.wallpapers
                    currentIndex: root.focusIndex
                    cellWidth: Math.floor(width / root.gridColumns)
                    cellHeight: 148
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: cellHeight * 3

                    ScrollBar.vertical: ScrollBar {
                        policy: grid.contentHeight > grid.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                        width: 6
                    }

                    delegate: Item {
                        id: card
                        required property int index
                        required property string wallpaperFilename
                        required property string wallpaperPath
                        required property bool wallpaperLocked
                        required property bool wallpaperInCooldown
                        required property bool wallpaperIsCurrent
                        required property bool wallpaperIsVideo
                        required property string thumbnailSource
                        required property bool hasThumbnail

                        width: grid.cellWidth
                        height: grid.cellHeight
                        readonly property bool focused: root.focusIndex === index

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: Sizes.rounding.normal
                            color: card.focused
                                ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.16)
                                : Colorscheme.surface_container
                            border.width: card.focused || card.wallpaperIsCurrent ? 2 : 1
                            border.color: card.wallpaperIsCurrent
                                ? Colorscheme.primary
                                : (card.focused ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.72) : Colorscheme.outline_variant)

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Rectangle {
                                id: thumbBox
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 6
                                height: 102
                                radius: Sizes.rounding.small
                                color: Colorscheme.surface_container_highest
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: card.thumbnailSource
                                    sourceSize.width: 360
                                    sourceSize.height: 240
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    visible: card.hasThumbnail
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: card.wallpaperIsVideo ? "" : ""
                                    font.family: Sizes.fontAwesome
                                    font.pixelSize: Sizes.font.h3
                                    color: Colorscheme.on_surface_variant
                                    visible: !card.hasThumbnail
                                }

                                Row {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: 6
                                    spacing: 4

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: Sizes.rounding.full
                                        color: Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.90)
                                        visible: card.wallpaperIsCurrent
                                        Text { anchors.centerIn: parent; text: ""; font.family: Sizes.fontAwesome; font.pixelSize: Sizes.font.xs; color: Colorscheme.on_primary }
                                    }

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: Sizes.rounding.full
                                        color: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, 0.62)
                                        visible: card.wallpaperLocked
                                        Text { anchors.centerIn: parent; text: ""; font.family: Sizes.fontAwesome; font.pixelSize: Sizes.font.xs; color: Colorscheme.on_surface }
                                    }

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: Sizes.rounding.full
                                        color: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, 0.62)
                                        visible: card.wallpaperInCooldown
                                        Text { anchors.centerIn: parent; text: ""; font.family: Sizes.fontAwesome; font.pixelSize: Sizes.font.xs; color: Colorscheme.on_surface }
                                    }
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 6
                                    width: 22
                                    height: 22
                                    radius: Sizes.rounding.full
                                    color: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, 0.58)

                                    Text {
                                        anchors.centerIn: parent
                                        text: card.wallpaperIsVideo ? "" : ""
                                        font.family: Sizes.fontAwesome
                                        font.pixelSize: Sizes.font.xs
                                        color: Colorscheme.on_surface
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
                                color: card.wallpaperIsCurrent ? Colorscheme.primary : Colorscheme.on_surface
                                font.pixelSize: Sizes.font.xs
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
                                    focusGrabber.forceActiveFocus()
                                }
                                onDoubleClicked: LianwallPlugin.setWallpaper(card.wallpaperPath)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: LianwallPlugin.error && LianwallPlugin.error.length > 0 ? LianwallPlugin.error : "暂无壁纸"
                        visible: grid.count === 0
                        color: Colorscheme.on_surface_variant
                        font.pixelSize: Sizes.font.lg
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: Sizes.rounding.chip
                    color: Colorscheme.surface_container_high

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(parent.height, parent.width * LianwallPlugin.progress)
                        radius: parent.radius
                        color: Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.22)

                        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: Sizes.spacing.sm

                        Text {
                            text: ""
                            font.family: Sizes.fontAwesome
                            font.pixelSize: Sizes.font.sm
                            color: Colorscheme.primary
                        }

                        Text {
                            Layout.fillWidth: true
                            text: LianwallPlugin.currentFilename || "--"
                            color: Colorscheme.on_surface
                            font.pixelSize: Sizes.font.xs
                            elide: Text.ElideRight
                        }

                        Text {
                            text: LianwallPlugin.formatDuration(LianwallPlugin.displaySecs)
                            color: LianwallPlugin.displaySecs >= 0 && LianwallPlugin.displaySecs <= 60 ? Colorscheme.error : Colorscheme.on_surface
                            font.pixelSize: Sizes.font.sm
                            font.bold: true
                            font.family: Sizes.fontFamilyMono
                        }
                    }
                }
            }
        }
    }
}