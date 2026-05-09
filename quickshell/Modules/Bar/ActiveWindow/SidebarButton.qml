import QtQuick
import QtQuick.Effects
import qs.config

Item {
    id: root

    implicitHeight: 36
    implicitWidth: 36

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: mouseArea.containsMouse ? Colorscheme.secondary_container : Colorscheme.surface_container
        radius: height / 2
        visible: false
        Behavior on color { ColorAnimation { duration: 150 } }
    }



    MultiEffect {
        source: bgRect
        anchors.fill: bgRect
        shadowEnabled: true
        shadowColor: Qt.alpha(Colorscheme.shadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
    }

    Text {
        anchors.centerIn: parent
        text: "segment"
        font.family: "Material Symbols Outlined"
        font.pixelSize: Sizes.font.xxl
        color: mouseArea.containsMouse ? Colorscheme.on_secondary_container : Colorscheme.on_surface_variant
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: WidgetState.leftSidebarOpen = !WidgetState.leftSidebarOpen
    }
}
