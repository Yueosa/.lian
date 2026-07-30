// KeysPage — 快捷键速查（asset/hotkeys.json）
// 一级组芯片 + 组内二级分区标题 + 条目胶囊
//
// 性能：只读 JSON；无 Timer；ListView reuseItems

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    property string groupId: "hypr"

    readonly property var flatRows: Hotkeys.flatRowsOf(groupId)

    function ensureGroup() {
        if (Hotkeys.groupById(groupId))
            return
        const gs = Hotkeys.groups || []
        if (gs.length > 0 && gs[0] && gs[0].id)
            groupId = String(gs[0].id)
    }

    Connections {
        target: Hotkeys
        function onGroupsChanged() { root.ensureGroup() }
        function onReadyChanged() { root.ensureGroup() }
    }

    Component.onCompleted: ensureGroup()

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.md

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "快捷键"
                color: Color.text
                font.pixelSize: Size.fontSize.lg
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: Hotkeys.error.length > 0
                text: Hotkeys.error
                color: Color.error
                font.pixelSize: Size.fontSize.sm
                elide: Text.ElideRight
                Layout.maximumWidth: 180
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            contentWidth: chipRow.implicitWidth
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: chipRow
                spacing: Size.spacing.xs
                Repeater {
                    model: Hotkeys.groups
                    QslChip {
                        required property var modelData
                        readonly property string gid: modelData && modelData.id ? String(modelData.id) : ""
                        text: (modelData && modelData.title) ? modelData.title : gid
                        selected: gid === root.groupId
                        chipHeight: 32
                        onClicked: root.groupId = gid
                    }
                }
            }
        }

        ListView {
            id: keyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Size.spacing.xs
            reuseItems: true
            model: root.flatRows
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                required property var modelData
                width: ListView.view ? ListView.view.width : 0
                height: modelData.kind === "header" ? 28 : 48

                // 分区标题
                Text {
                    visible: modelData.kind === "header"
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    text: modelData.title || ""
                    color: Color.textMuted
                    font.pixelSize: Size.fontSize.sm
                    font.bold: true
                }

                // 条目胶囊
                Rectangle {
                    visible: modelData.kind === "item"
                    anchors.fill: parent
                    radius: Size.rounding.md
                    color: Color.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Size.spacing.md
                        anchors.rightMargin: Size.spacing.md
                        spacing: Size.spacing.md

                        Text {
                            Layout.preferredWidth: Math.min(200, parent.width * 0.48)
                            text: modelData.keys || ""
                            color: Color.primary
                            font.pixelSize: Size.fontSize.md
                            font.family: Size.fontMono
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.desc || ""
                            color: Color.text
                            font.pixelSize: Size.fontSize.md
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: keyList.count === 0
                text: Hotkeys.ready
                    ? "此分组暂无条目"
                    : "等待 hotkeys.json…"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }
        }
    }
}
