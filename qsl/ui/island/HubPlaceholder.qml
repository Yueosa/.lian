// HubPlaceholder — Hub 页占位（逐页替换）
// 性能：无 Timer / 无网络；纯 Text

import QtQuick
import qs.data.state

Item {
    id: root
    property string title: ""
    property string hint: ""

    Column {
        anchors.centerIn: parent
        spacing: Size.spacing.sm

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: Color.textOnBackground
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.title
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.hint
            color: Color.textMuted
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.md
        }
    }
}
