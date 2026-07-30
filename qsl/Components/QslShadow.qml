// QslShadow — 纯 QML 卡片阴影（多层 Rectangle 模拟 blur spread）
// 不使用 DropShadow/ShaderEffect/layer.enabled，零 GPU 离屏开销。
// cached 模式：首次渲染后通过 visible 绑定控制显隐，不持续计算。
//
// 用法：
//   QslShadow { target: myCard }
//   或手动设置 anchors.fill / radius

import QtQuick
import qs.data.state

Item {
    id: root

    property Item target: null
    property color shadowColor: Color.withAlpha(Color.shadow, 0.18)
    property real offsetY: 2
    property real blur: 12
    property int layers: 3

    anchors.fill: target
    z: target ? target.z - 1 : -1
    visible: target ? target.visible : true

    Repeater {
        model: root.layers

        Rectangle {
            required property int index

            readonly property real frac: (index + 1) / root.layers
            readonly property real expand: root.blur * frac
            readonly property real targetRadius: root.target
                ? root.target.radius : Size.rounding.lg

            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.offsetY * frac
            width: parent.width + expand * 2
            height: parent.height + expand * 2
            radius: targetRadius + expand
            color: Color.withAlpha(root.shadowColor, root.shadowColor.a * (1 - frac * 0.6))
        }
    }
}
