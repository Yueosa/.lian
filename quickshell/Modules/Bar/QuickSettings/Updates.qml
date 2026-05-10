import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.config

Rectangle {
    id: root

    property bool isHovered: mouseArea.containsMouse
    readonly property bool hasUpdates: Updates.totalCount > 0

    implicitHeight: 28
    implicitWidth: isHovered ? (layout.implicitWidth + 14) : 28
    radius: height / 2
    color: hasUpdates ? Colorscheme.secondary_container : Colorscheme.surface_container

    Behavior on implicitWidth { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 200 } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Sizes.spacing.s

        Text {
            text: "system_update_alt"
            font.family: Sizes.fontIcon
            font.pixelSize: Sizes.font.xl
            color: root.hasUpdates ? Colorscheme.on_secondary_container : Colorscheme.on_surface_variant
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.hasUpdates ? Updates.totalCount.toString() : "0"
            font.family: Sizes.fontFamilyMono
            font.pixelSize: Sizes.font.sm
            font.bold: true
            color: root.hasUpdates ? Colorscheme.on_secondary_container : Colorscheme.on_surface_variant
            visible: root.isHovered
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (WidgetState.qsOpen && WidgetState.qsView === "updates") {
                WidgetState.qsOpen = false;
            } else {
                WidgetState.qsView = "updates";
                WidgetState.qsOpen = true;
                Updates.refresh();
            }
        }
    }
}
