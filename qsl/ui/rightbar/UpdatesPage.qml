// UpdatesPage — Rightbar 系统更新页
// 工具行：齿轮(tcr→Syu) + 刷新；摘要卡 + 官方/AUR 列表
//
// 性能：进页 hydrate+check；销毁 release 清包列表；无 Timer；ListView reuseItems

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.data.state
import qs.data.service

Item {
    id: root

    signal requestClose()

    Component.onCompleted: Updates.setDetailActive(true)
    Component.onDestruction: Updates.setDetailActive(false)

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.sm

        // 工具行：[升级] [刷新]
        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            Rectangle {
                width: 36
                height: 36
                radius: Size.rounding.md
                color: gearMa.containsMouse
                    ? Color.withAlpha(Color.text, 0.08)
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "settings"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.xl
                    color: Color.textMuted
                }
                MouseArea {
                    id: gearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Updates.openUpgrade()
                        root.requestClose()
                    }
                }
            }

            Rectangle {
                width: 36
                height: 36
                radius: Size.rounding.md
                color: refreshMa.containsMouse
                    ? Color.withAlpha(Color.text, 0.08)
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "refresh"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.xl
                    color: Updates.loading ? Color.primary : Color.textMuted
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: Updates.loading
                    }
                }
                MouseArea {
                    id: refreshMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !Updates.loading
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Updates.refresh()
                }
            }

            Item { Layout.fillWidth: true }
        }

        // 摘要卡
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 72
            radius: Size.rounding.md
            color: Updates.totalCount > 0
                ? Color.withAlpha(Color.primary, 0.12)
                : Color.withAlpha(Color.text, 0.06)
            Behavior on color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: Size.spacing.md

                Text {
                    text: "inventory_2"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.xl
                    color: Updates.totalCount > 0 ? Color.primary : Color.textMuted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (Updates.loading && Updates.totalCount === 0)
                                return "正在检查更新…"
                            if (Updates.totalCount > 0)
                                return Updates.totalCount + " 个可更新"
                            if (Updates.lastAppliedCount > 0)
                                return "系统已是最新（上次更新 "
                                    + Updates.lastAppliedCount + " 包）"
                            return "系统已是最新"
                        }
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Updates.totalCount > 0 ? Color.primary : Color.text
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!Updates.ok && Updates.errorAgo)
                                return "最近采集失败 " + Updates.errorAgo
                            if (Updates.totalCount > 0)
                                return "检查于 " + Updates.updatedAgo
                            if (Updates.lastAppliedCount > 0 && Updates.lastAppliedAgo)
                                return "上次更新于 " + Updates.lastAppliedAgo
                            return "检查于 " + Updates.updatedAgo
                        }
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        elide: Text.ElideRight
                    }
                }

                Text {
                    visible: Updates.totalCount > 0
                    text: Updates.totalCount.toString()
                    font.family: Size.fontMono
                    font.bold: true
                    font.pixelSize: Size.fontSize.lg
                    color: Color.primary
                }
            }
        }

        // 细条：检查中
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Updates.loading ? 3 : 0
            radius: 2
            color: Color.withAlpha(Color.primary, 0.25)
            clip: true
            opacity: Updates.loading ? 1 : 0
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Rectangle {
                width: parent.width * 0.35
                height: parent.height
                radius: 2
                color: Color.primary
                visible: Updates.loading

                SequentialAnimation on x {
                    running: Updates.loading
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: -width
                        to: parent.width
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        ListView {
            id: pkgList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            reuseItems: true
            model: Updates.flatRows
            boundsBehavior: Flickable.StopAtBounds

            Text {
                anchors.centerIn: parent
                visible: !Updates.loading && Updates.flatRows.length === 0
                text: Updates.ok ? "暂无可用更新" : "检查失败，点刷新重试"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }

            delegate: Item {
                id: row
                width: ListView.view ? ListView.view.width : 0
                height: isHeader ? 28 : 40

                required property var modelData
                readonly property bool isHeader: modelData && modelData.kind === "header"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.isHeader
                    text: {
                        if (!modelData)
                            return ""
                        const n = modelData.count || 0
                        return modelData.title + (n > 0 ? (" · " + n) : "")
                    }
                    color: {
                        if (!modelData)
                            return Color.textMuted
                        // AUR 分组头用 secondary，官方用 muted
                        if (modelData.section === "aur")
                            return Color.secondary
                        return Color.textMuted
                    }
                    font.pixelSize: Size.fontSize.xsm
                    font.bold: true
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 36
                    visible: !row.isHeader
                    radius: Size.rounding.md
                    color: pkgMa.containsMouse
                        ? Color.withAlpha(Color.text, 0.06)
                        : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: Size.spacing.sm

                        Text {
                            Layout.fillWidth: true
                            text: modelData ? (modelData.name || "") : ""
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.sm
                            color: Color.text
                            elide: Text.ElideRight
                        }

                        // 旧版 muted / 新版 primary，一眼分清方向
                        Row {
                            visible: !!(modelData && modelData.from && modelData.to)
                            spacing: 4
                            Layout.maximumWidth: parent.width * 0.5

                            Text {
                                text: modelData && modelData.from ? modelData.from : ""
                                font.family: Size.fontMono
                                font.pixelSize: Size.fontSize.xsm
                                color: Color.textMuted
                                elide: Text.ElideLeft
                                width: Math.min(implicitWidth, 90)
                            }
                            Text {
                                text: "→"
                                font.family: Size.fontMono
                                font.pixelSize: Size.fontSize.xsm
                                color: Color.outline
                            }
                            Text {
                                text: modelData && modelData.to ? modelData.to : ""
                                font.family: Size.fontMono
                                font.pixelSize: Size.fontSize.xsm
                                font.bold: true
                                color: Color.primary
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, 90)
                            }
                        }
                    }

                    MouseArea {
                        id: pkgMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }
    }
}
