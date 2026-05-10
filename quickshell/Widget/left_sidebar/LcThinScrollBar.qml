import QtQuick
import QtQuick.Controls
import qs.config

// 极细 overlay 滚动条，hover 加深；用于 ListView/Flickable 的 ScrollBar.vertical。
ScrollBar {
    id: bar
    policy: ScrollBar.AsNeeded
    width: 4
    minimumSize: 0.08

    contentItem: Rectangle {
        implicitWidth: 4
        radius: 2
        color: Qt.rgba(Colorscheme.on_surface.r,
                       Colorscheme.on_surface.g,
                       Colorscheme.on_surface.b,
                       bar.pressed ? 0.55 : (bar.hovered ? 0.40 : 0.25))
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    background: Item {}
}
