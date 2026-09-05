// KeysListCard — 快捷键分区标题 + 条目胶囊列表（KeysPage 列表拆出的容器卡）
// 组选中来自 Leftbar.keysState；高度随内容自适应（有上限，超出滚动）
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
// 性能：只读 JSON；无 Timer；ListView reuseItems

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.data.service

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    // 列表自适应内容：下限留空态文案位置，上限后滚动
    implicitHeight: Math.max(160, Math.min(520, keyList.contentHeight)) + 32

    // 指向 Leftbar.keysState（groupId）
    property QtObject sharedState

    // 组选中在加载时捕获（同 TodoListCard 的回放冻结）
    property string _groupId: ""
    Component.onCompleted: _groupId = sharedState ? sharedState.groupId : ""

    readonly property var flatRows: Hotkeys.flatRowsOf(root._groupId)

    ListView {
        id: keyList
        anchors.fill: parent
        anchors.margins: 16
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
                font.pixelSize: Size.fontSize.labelMedium
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

                    // 键位列按内容伸缩：IPC 组里 "rightbar open network"
                    // 这种长串，固定 200 会被 elide 成没法复制的半截
                    Text {
                        Layout.preferredWidth: Math.min(Math.max(150, implicitWidth),
                                                        parent.width * 0.55)
                        text: modelData.keys || ""
                        color: Color.primary
                        font.pixelSize: Size.fontSize.titleSmall
                        font.family: Size.fontMono
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.desc || ""
                        color: Color.text
                        font.pixelSize: Size.fontSize.bodyMedium
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
            font.pixelSize: Size.fontSize.bodyMedium
        }
    }
}
