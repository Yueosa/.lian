// QslSwitch — M3 风格开关（学 clavis StyledSwitch 比例，无 Qt Controls）
// 默认 52×32 × sizeScale(0.75) ≈ 39×24
// 注意：禁止命名 scale（与 Item.scale 冲突，会崩）
// 性能：纯 Rectangle + Behavior，无 Timer / layer

import QtQuick
import qs.data.state

Item {
    id: root

    property bool checked: false
    property real sizeScale: 0.75
    property bool enabled: true
    signal toggled(bool checked)

    readonly property real s: sizeScale
    readonly property bool pressed: ma.pressed

    implicitWidth: 52 * s
    implicitHeight: 32 * s
    width: implicitWidth
    height: implicitHeight
    opacity: enabled ? 1 : 0.45

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Color.primary : Color.surfaceHighest
        border.width: root.checked ? 0 : Math.max(1, Math.round(2 * root.s))
        border.color: Color.outline
        Behavior on color { CAnim {} }
        Behavior on border.color { CAnim {} }
    }

    Rectangle {
        id: thumb
        readonly property real onW: (root.pressed ? 28 : 24) * root.s
        readonly property real offW: (root.pressed ? 28 : 16) * root.s
        width: root.checked ? onW : offW
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked
            ? parent.width - width - (root.pressed ? 2 : 4) * root.s
            : (root.pressed ? 2 : 8) * root.s
        color: root.checked ? Color.textOnPrimary : Color.outline
        Behavior on x { Anim { type: Anim.Spatial } }
        Behavior on width { Anim { type: Anim.Spatial } }
        Behavior on color { CAnim {} }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        // 不自改 checked：保持外部绑定（如 Network.wifiEnabled）有效
        onClicked: root.toggled(!root.checked)
    }
}
