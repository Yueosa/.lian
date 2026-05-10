import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    property string icon: "info"
    property string label: ""
    property string value: "--"
    property string detail: ""
    property color accent: Colorscheme.secondary

    radius: Sizes.rounding.xlarge
    color: Colorscheme.surface_container_low

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: Sizes.spacing.m

        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            radius: Sizes.rounding.xxlPlus
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.accent
                font.family: "Material Symbols Outlined"
                font.pixelSize: Sizes.font.h1
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Sizes.spacing.hairline

            Text {
                text: root.label
                color: Colorscheme.on_surface_variant
                font.family: "Noto Sans CJK SC"
                font.pixelSize: Sizes.font.xsm
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.value
                color: Colorscheme.on_surface
                font.family: "JetBrainsMono Nerd Font"
                font.bold: true
                font.pixelSize: Sizes.font.lg
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.detail
                visible: root.detail.length > 0
                color: Colorscheme.outline
                font.family: "Noto Sans CJK SC"
                font.pixelSize: Sizes.font.xs
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}
