// QslSlider — 轻量滑条（学 clavis 主色填充，保留 VolBar 交互，无 Qt Controls.Slider）
// value 0..1；muted 时填充归零但仍可拖
// 性能：无 Timer；拖动只发 moved，由调用方写回服务

import QtQuick
import qs.data.state

Item {
    id: root

    property real value: 0
    property bool muted: false
    property bool enabled: true
    // 可选：轨内右侧 Material 图标名（空则不画）
    property string icon: ""
    signal moved(real v)

    height: 28
    implicitHeight: 28
    opacity: enabled ? 1 : 0.45

    readonly property real shown: muted ? 0 : Math.max(0, Math.min(1, value))

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: height / 2
        color: Color.withAlpha(Color.text, 0.12)

        Rectangle {
            height: parent.height
            width: parent.width * root.shown
            radius: parent.radius
            color: Color.primary
        }
    }

    // 拇指（细条，对齐现 VolBar；以后可换成圆头）
    Rectangle {
        width: 4
        height: 22
        radius: 2
        color: Color.text
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(parent.width - width, parent.width * root.shown - width / 2))
    }

    Text {
        visible: root.icon !== ""
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        font.family: Size.fontIcon
        font.pixelSize: 18
        color: root.shown > 0.85 ? Color.textOnPrimary : Color.textMuted
        z: 1
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true

        function setFromX(mx) {
            const v = Math.max(0, Math.min(1, mx / Math.max(1, root.width)))
            root.moved(v)
        }

        onPressed: (mouse) => setFromX(mouse.x)
        onPositionChanged: (mouse) => {
            if (pressed)
                setFromX(mouse.x)
        }
    }
}
