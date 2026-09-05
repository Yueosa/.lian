// KeysTabsCard — 快捷键一级组芯片条（KeysPage 头部拆出的容器卡）
// 组选中状态在 Leftbar.keysState（与 KeysListCard 共享），本卡只读写它
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: mainCol.implicitHeight + 32   // 上下各 16 留白

    // 指向 Leftbar.keysState（groupId / ensureGroup()）
    // 不叫 state：Item 自带同名属性（状态机当前态），避免遮蔽
    property QtObject sharedState

    ColumnLayout {
        id: mainCol
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: Size.spacing.md

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "快捷键"
                color: Color.text
                font.pixelSize: Size.fontSize.titleMedium
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: Hotkeys.error.length > 0
                text: Hotkeys.error
                color: Color.error
                font.pixelSize: Size.fontSize.bodySmall
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
                        selected: gid === root.sharedState.groupId
                        chipHeight: 32
                        onClicked: root.sharedState.groupId = gid
                    }
                }
            }
        }
    }
}
