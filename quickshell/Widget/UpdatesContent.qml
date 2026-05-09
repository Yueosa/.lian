import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.config
import qs.Widget.common

WidgetPanel {
    id: root
    title: "系统更新"
    icon: "system_update_alt"
    closeAction: () => WidgetState.qsOpen = false

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "updates"

    onIsActiveChanged: {
        if (isActive)
            Updates.refresh();
    }

    headerTools: Text {
        text: "refresh"
        font.family: "Material Symbols Outlined"
        font.pixelSize: Sizes.font.title
        color: Colorscheme.on_surface_variant
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Updates.refresh()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Sizes.spacing.m

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: Sizes.rounding.chip
            color: Qt.alpha(Colorscheme.primary_container, 0.7)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: Sizes.spacing.l

                Text {
                    text: "inventory_2"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: Sizes.font.h3
                    color: Colorscheme.primary
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Sizes.spacing.xxs

                    Text {
                        text: Updates.totalCount > 0 ? (Updates.totalCount + " 个可更新") : "系统已是最新"
                        font.pixelSize: Sizes.font.body
                        font.bold: true
                        color: Colorscheme.on_primary_container
                    }

                    Text {
                        text: Updates.ok ? ("更新于 " + Updates.updatedAgo) : ("最近采集失败 " + Updates.errorAgo)
                        font.pixelSize: Sizes.font.xsm
                        color: Colorscheme.on_surface_variant
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Updates.totalCount === 0
            text: "暂无可用更新"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Sizes.font.body
            color: Colorscheme.on_surface_variant
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Updates.totalCount > 0
            clip: true
            contentWidth: width
            contentHeight: pkgColumn.implicitHeight

            ColumnLayout {
                id: pkgColumn
                width: parent.width
                spacing: Sizes.spacing.m

                Rectangle {
                    Layout.fillWidth: true
                    visible: Updates.officialCount > 0
                    implicitHeight: offCol.implicitHeight + 28
                    radius: Sizes.rounding.normal
                    color: Qt.alpha(Colorscheme.surface_container, 0.6)

                    ColumnLayout {
                        id: offCol
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                        spacing: Sizes.spacing.xs

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "官方仓库"
                                font.pixelSize: Sizes.font.md
                                font.bold: true
                                color: Colorscheme.on_surface
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Updates.officialCount.toString()
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Sizes.font.md
                                font.bold: true
                                color: Colorscheme.primary
                            }
                        }

                        Repeater {
                            model: Updates.officialPackages
                            delegate: Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Sizes.font.xsm
                                color: Colorscheme.on_surface_variant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: Updates.aurCount > 0
                    implicitHeight: aurCol.implicitHeight + 28
                    radius: Sizes.rounding.normal
                    color: Qt.alpha(Colorscheme.surface_container, 0.6)

                    ColumnLayout {
                        id: aurCol
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                        spacing: Sizes.spacing.xs

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "AUR"
                                font.pixelSize: Sizes.font.md
                                font.bold: true
                                color: Colorscheme.on_surface
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Updates.aurCount.toString()
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Sizes.font.md
                                font.bold: true
                                color: Colorscheme.secondary
                            }
                        }

                        Repeater {
                            model: Updates.aurPackages
                            delegate: Text {
                                Layout.fillWidth: true
                                text: modelData
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Sizes.font.xsm
                                color: Colorscheme.on_surface_variant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
