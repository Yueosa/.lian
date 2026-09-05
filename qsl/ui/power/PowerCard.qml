// PowerCard — 电源卡内容。背景/圆角/耳朵由宿主 RailContainer 提供
//
// 竖列：logout、lock、头像、shutdown、reboot。只有图标。

import Qt5Compat.GraphicalEffects
import QtQuick
import qs.Components
import qs.data.service
import qs.data.state

Item {
    id: root

    anchors.fill: parent

    property QtObject sharedState
    readonly property QtObject s: root.sharedState

    readonly property int pad: 14
    readonly property int btn: 44
    readonly property int avatar: 56
    readonly property int gap: 8

    implicitHeight: root.pad * 2 + root.btn * 4 + root.avatar
        + root.gap * 4 + 8

    MouseArea {
        anchors.fill: parent
        onClicked: keyCatcher.forceActiveFocus()
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Connections {
            target: root.s
            function onFocusTickChanged() {
                Qt.callLater(() => keyCatcher.forceActiveFocus())
            }
        }

        Component.onCompleted: Qt.callLater(() => keyCatcher.forceActiveFocus())

        Keys.onUpPressed: (event) => { event.accepted = true; root.s.move(-1) }
        Keys.onDownPressed: (event) => { event.accepted = true; root.s.move(1) }
        Keys.onReturnPressed: (event) => { event.accepted = true; root.s.activate() }
        Keys.onEnterPressed: (event) => { event.accepted = true; root.s.activate() }
    }

    Column {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.pad
        spacing: root.gap

        Repeater {
            model: [
                { id: "logout",   icon: "logout",             idx: 0 },
                { id: "lock",     icon: "lock",               idx: 1 },
                { id: "avatar",   icon: "",                   idx: 2 },
                { id: "shutdown", icon: "power_settings_new", idx: 3 },
                { id: "reboot",   icon: "restart_alt",        idx: 4 }
            ]

            delegate: Item {
                id: cell

                required property var modelData
                readonly property int idx: modelData.idx
                readonly property bool isAvatar: modelData.id === "avatar"
                readonly property bool selected: root.s && root.s.current === idx
                readonly property bool isArmed: root.s && !isAvatar
                    && root.s.armed === modelData.id

                width: isAvatar ? root.avatar : root.btn
                height: width
                anchors.horizontalCenter: parent.horizontalCenter

                scale: (selected || ma.containsMouse) ? (isAvatar ? 1.06 : 1.08) : 1
                Behavior on scale { Anim { type: Anim.EffectsFast } }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    visible: !cell.isAvatar
                    color: cell.isArmed ? Color.error : "transparent"
                    border.width: cell.selected ? 2 : 0
                    border.color: Color.primary
                    Behavior on color { CAnim {} }

                    // 待确认态已是实心红，不再叠。键盘选中和鼠标悬停都要出反馈：
                    // 这一排既能用方向键走，也能直接点
                    QslStateLayer {
                        source: ma
                        active: !cell.isArmed
                        tint: Color.primary
                        accent: true
                        selected: cell.selected
                    }
                }

                Text {
                    visible: !cell.isAvatar
                    anchors.centerIn: parent
                    text: cell.modelData.icon
                    font.family: Size.fontIcon
                    font.pixelSize: 22
                    color: cell.isArmed ? Color.errorText : Color.text
                    Behavior on color { CAnim {} }
                }

                Rectangle {
                    visible: cell.isAvatar
                    anchors.fill: parent
                    radius: width / 2
                    color: Color.surfaceContainerHighest
                    border.width: cell.selected ? 2 : 0
                    border.color: Color.primary

                    Text {
                        anchors.centerIn: parent
                        visible: avatarImg.status !== Image.Ready
                        text: root.s ? root.s.avatarLetter : "?"
                        color: Color.primary
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.titleLarge
                        font.bold: true
                    }
                }

                Image {
                    id: avatarImg
                    visible: false
                    anchors.fill: parent
                    source: cell.isAvatar ? Avatar.source : ""
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }

                Rectangle {
                    id: avatarMask
                    visible: false
                    anchors.fill: parent
                    radius: width / 2
                }

                OpacityMask {
                    visible: cell.isAvatar && avatarImg.status === Image.Ready
                    anchors.fill: parent
                    source: avatarImg
                    maskSource: avatarMask
                }

                Rectangle {
                    visible: cell.isAvatar && cell.selected
                        && avatarImg.status === Image.Ready
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Color.primary
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.s)
                            return
                        root.s.current = cell.idx
                        root.s.activate()
                    }
                }
            }
        }
    }
}
