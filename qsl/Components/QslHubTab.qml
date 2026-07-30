// QslHubTab — 对齐 Island Hub 的 Tab 项
// 图标 + 标题 + 底部短指示条；高度由内容决定，禁止 fillHeight（会吃掉整栏）
// 性能：纯 Text/Rectangle；侧栏 4 个实例可忽略

import QtQuick
import QtQuick.Layouts
import qs.data.state

Item {
    id: root

    property string text: ""
    property string icon: ""
    property bool selected: false
    property bool enabled: true
    signal clicked()

    // 只吃横向；高度跟内容走，交给父 RowLayout.preferredHeight
    Layout.fillWidth: true
    Layout.fillHeight: false
    implicitHeight: col.implicitHeight + Size.island.hubTabIndicatorHeight + 4
    implicitWidth: Math.max(col.implicitWidth, Size.island.hubTabIndicatorWidth)
    opacity: enabled ? 1 : 0.4

    Column {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 2
        spacing: Size.spacing.xs

        Text {
            text: root.icon
            font.family: Size.fontMono
            font.pixelSize: Size.fontSize.title
            color: root.selected ? Color.textOnBackground : Color.textMuted
            anchors.horizontalCenter: parent.horizontalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        Text {
            text: root.text
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.md
            font.bold: root.selected
            color: root.selected ? Color.textOnBackground : Color.textMuted
            anchors.horizontalCenter: parent.horizontalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.selected ? Size.island.hubTabIndicatorWidth : 0
        height: Size.island.hubTabIndicatorHeight
        radius: Size.island.hubTabIndicatorHeight / 2
        color: Color.textOnBackground
        opacity: root.selected ? 1 : 0
        Behavior on width {
            NumberAnimation { duration: 300; easing.type: Easing.OutBack }
        }
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
