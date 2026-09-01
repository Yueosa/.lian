// QslChip — 选中/悬停 pill（侧栏 Tab、筛选标签）
// 性能：无阴影；ListView 外的少量实例 OK
// 在 RowLayout 里由调用方设 Layout.fillWidth / preferredHeight

import QtQuick
import qs.data.state

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool selected: false
    property bool enabled: true
    property int chipHeight: 36
    signal clicked()
    signal rightClicked()

    implicitHeight: chipHeight
    implicitWidth: row.implicitWidth + Size.spacing.md * 2
    height: chipHeight
    radius: Size.rounding.full
    opacity: enabled ? 1 : 0.4
    color: selected
        ? Color.withAlpha(Color.primary, 0.18)
        : (ma.containsMouse ? Color.withAlpha(Color.text, 0.06) : "transparent")
    Behavior on color { CAnim {} }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Size.fontIcon
            font.pixelSize: Size.fontSize.sm
            color: root.selected ? Color.primary : Color.textMuted
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.text
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.sm
            font.bold: root.selected
            color: root.selected ? Color.primary : Color.textMuted
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked()
            else
                root.clicked()
        }
    }
}
