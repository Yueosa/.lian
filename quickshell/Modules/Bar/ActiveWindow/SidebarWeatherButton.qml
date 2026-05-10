import QtQuick
import QtQuick.Layouts
import Clavis.Weather 1.0
import qs.config

Item {
    id: root

    readonly property bool isHovered: mouseArea.containsMouse
    readonly property string temperatureText: WeatherPlugin.hasValidData ? Math.round(WeatherPlugin.currentTemperatureC) + "°" : "--°"

    implicitHeight: isHovered ? 34 : 28
    implicitWidth: isHovered ? contentRow.implicitWidth + 16 : 28
    clip: true

    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    function toggleView() {
        if (WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === "weather") {
            WidgetState.leftSidebarOpen = false;
            return;
        }

        WidgetState.leftSidebarView = "weather";
        WidgetState.leftSidebarOpen = true;
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: Sizes.spacing.s

        Text {
            text: WeatherPlugin.currentIconName || "cloud"
            font.family: Sizes.fontIconRounded
            font.variableAxes: { "FILL": 1 }
            font.pixelSize: Sizes.font.title
            color: Colorscheme.on_surface
            Layout.alignment: Qt.AlignVCenter

            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Text {
            visible: root.isHovered
            opacity: root.isHovered ? 1 : 0
            text: root.temperatureText
            font.family: Sizes.fontFamilyMono
            font.pixelSize: Sizes.font.sm
            font.bold: true
            color: Colorscheme.on_surface
            Layout.alignment: Qt.AlignVCenter

            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleView()
    }
}
