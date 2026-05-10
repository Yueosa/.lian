import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    property bool isHovered: mouseArea.containsMouse
    property string currentMode: Colorscheme.matugenMode.toLowerCase()
    implicitHeight: 28
    implicitWidth: isHovered ? 162 : 28
    radius: height / 2
    color: Colorscheme.secondary_container

    Behavior on implicitWidth { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    function modeIcon(mode) {
        if (mode === "auto")
            return "󰌵";
        if (mode === "light")
            return "󰖨";
        return "󰖔";
    }

    function applyMode(mode) {
        Colorscheme.matugenMode = mode;
    }

    function nextMode(mode) {
        if (mode === "auto")
            return "light";
        if (mode === "light")
            return "dark";
        return "auto";
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: Sizes.spacing.xs

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.modeIcon(root.currentMode)
            font.family: Sizes.fontFamilyMono
            font.pixelSize: Sizes.font.lg
            color: Colorscheme.on_secondary_container
        }

        Repeater {
            model: ["auto", "light", "dark"]

            delegate: Rectangle {
                required property string modelData
                readonly property bool active: root.currentMode === modelData

                visible: root.isHovered
                opacity: root.isHovered ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Layout.preferredHeight: 18
                Layout.preferredWidth: 38
                radius: Sizes.rounding.md
                color: active ? Qt.alpha(Colorscheme.on_secondary_container, 0.20) : "transparent"
                border.width: active ? 1 : 0
                border.color: active ? Qt.alpha(Colorscheme.on_secondary_container, 0.35) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: modelData.toUpperCase()
                    font.pixelSize: Sizes.font.hairline
                    font.bold: true
                    color: active ? Colorscheme.on_secondary_container : Qt.alpha(Colorscheme.on_secondary_container, 0.70)
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.applyMode(root.nextMode(root.currentMode))
    }
}
