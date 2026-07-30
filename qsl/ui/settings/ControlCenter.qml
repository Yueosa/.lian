// ControlCenter — 设置面板（P2 #10）
// 左 Rail + 单 Loader；关窗/关动画后卸页（尤其 Arch Canvas）
// Esc / 点窗外关闭；Rail 无关闭钮
// 性能：无常驻 Timer；仅 contentActive 时挂载页面

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.ui.freewindow

FreeWindow {
    id: root

    shellNamespace: "qsl-settings"

    property string currentPage: "arch"
    readonly property var pages: [
        { id: "arch", title: "架构", icon: "account_tree" },
        { id: "guide", title: "说明", icon: "menu_book" },
        { id: "ipc", title: "IPC", icon: "terminal" },
        { id: "maintain", title: "维护", icon: "build" },
        { id: "files", title: "文件", icon: "folder_open" }
    ]

    function openView(view) {
        let id = String(view || "arch")
        // 旧别名
        if (id === "hotkeys" || id === "calendar" || id === "about")
            id = "files"
        if (id === "overview" || id === "docs")
            id = "guide"
        let ok = false
        for (let i = 0; i < pages.length; i++) {
            if (pages[i].id === id) {
                ok = true
                break
            }
        }
        currentPage = ok ? id : "arch"
        openWindow()
    }

    function pageComponent(id) {
        switch (id) {
        case "guide": return guidePage
        case "ipc": return ipcPage
        case "maintain": return maintainPage
        case "files": return filesPage
        default: return archPage
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Color.background
        radius: Size.rounding.xxl
        border.width: 1
        border.color: Color.outlineVariant
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: Size.spacing.md
            spacing: Size.spacing.md

            // ----- 左 Rail -----
            Rectangle {
                Layout.preferredWidth: 88
                Layout.fillHeight: true
                radius: Size.rounding.lg
                color: Color.surfaceHigh
                border.width: Style.border.width
                border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Size.spacing.sm
                    spacing: 4

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        Layout.bottomMargin: 8
                        text: "settings"
                        font.family: Size.fontIcon
                        font.pixelSize: 28
                        color: Color.primary
                    }

                    Repeater {
                        model: root.pages
                        delegate: Item {
                            id: railItem
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56

                            readonly property bool selected: root.currentPage === modelData.id

                            Rectangle {
                                anchors.fill: parent
                                radius: Size.rounding.md
                                color: railItem.selected
                                    ? Color.withAlpha(Color.primary, 0.14)
                                    : (railMa.containsMouse
                                        ? Color.withAlpha(Color.text, 0.06)
                                        : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: railItem.modelData.icon
                                        font.family: Size.fontIcon
                                        font.pixelSize: Size.fontSize.xl
                                        color: railItem.selected ? Color.primary : Color.textMuted
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: railItem.modelData.title
                                        font.pixelSize: Size.fontSize.xsm
                                        font.bold: railItem.selected
                                        color: railItem.selected ? Color.primary : Color.textMuted
                                    }
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 20
                                    radius: 2
                                    visible: railItem.selected
                                    color: Color.primary
                                }

                                MouseArea {
                                    id: railMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.currentPage = railItem.modelData.id
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            Loader {
                id: pageLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: root.contentActive
                sourceComponent: root.pageComponent(root.currentPage)
            }
        }
    }

    Component { id: archPage; ArchPage {} }
    Component { id: guidePage; GuidePage {} }
    Component { id: ipcPage; IpcPage {} }
    Component { id: maintainPage; MaintainPage {} }
    Component { id: filesPage; FilesPage {} }
}
