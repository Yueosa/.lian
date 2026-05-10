import QtQuick
import QtQuick.Layouts
import qs.config

// 模式胶囊。柔和样式，不再 1px 边框。
// - 收起：仅显示 current 值 + ▾，背景为 on_surface 6%
// - 展开：显示所有 options，current 用 accentBg 高亮
Rectangle {
    id: chip

    property var options: []
    property string current: ""
    property bool expanded: false
    property color accentBg: Colorscheme.primary_container
    property color accentFg: Colorscheme.on_primary_container

    signal toggleRequested()
    signal picked(string value)

    readonly property int collapsedW: 76
    readonly property int optionW: 54
    width: expanded ? (options.length * optionW + 6) : collapsedW
    radius: height / 2
    color: Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g,
                   Colorscheme.on_surface.b, 0.06)
    border.width: 0
    clip: true
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // 收起：当前值 + ▾
    Row {
        anchors.centerIn: parent
        spacing: 1
        visible: !chip.expanded
        Text {
            text: chip.current ? chip.current : "—"
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.font.sm
            font.bold: true
            color: Colorscheme.on_surface
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: "expand_more"
            font.family: Sizes.fontIcon
            font.pixelSize: 16
            color: Colorscheme.on_surface_variant
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        anchors.fill: parent
        visible: !chip.expanded
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.toggleRequested()
    }

    // 展开：options
    Row {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 1
        visible: chip.expanded

        Repeater {
            model: chip.options
            delegate: Rectangle {
                width: chip.optionW - 2
                height: parent.height
                radius: height / 2
                property bool isCurrent: modelData === chip.current
                color: isCurrent
                    ? chip.accentBg
                    : (optMa.containsMouse
                        ? Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g,
                                  Colorscheme.on_surface.b, 0.08)
                        : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.sm
                    font.bold: parent.isCurrent
                    color: parent.isCurrent ? chip.accentFg : Colorscheme.on_surface_variant
                }
                MouseArea {
                    id: optMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chip.picked(modelData)
                }
            }
        }
    }
}
