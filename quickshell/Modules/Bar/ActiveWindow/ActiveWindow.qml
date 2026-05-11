import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Hyprland
import qs.config

Item {
    id: root

    implicitHeight: 36
    implicitWidth: layout.width + 24

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property bool focusedWorkspaceEmpty: {
        const ws = focusedWorkspace
        if (!ws)
            return true
        if (!ws.toplevels)
            return false
        return ws.toplevels.count <= 0
    }

    readonly property var activeWindow: Hyprland.activeToplevel
    readonly property string activeTitle: {
        if (focusedWorkspaceEmpty)
            return "Desktop"
        return activeWindow ? (activeWindow.title || "Desktop") : "Desktop"
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: Colorscheme.background
        radius: height / 2
        visible: false
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

    RowLayout {
        id: layout
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        spacing: Sizes.spacing.m

        Text {
            text: ""
            color: Colorscheme.primary
            font.family: Sizes.fontFamilyMono
            font.pixelSize: Sizes.font.body
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: windowTitle
            text: root.activeTitle

            font.family: Sizes.fontFamilyMono
            font.pixelSize: Sizes.font.md
            color: Colorscheme.primary

            Layout.maximumWidth: 250
            elide: Text.ElideRight
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
