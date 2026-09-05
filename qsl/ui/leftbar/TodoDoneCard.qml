// TodoDoneCard — 已完成列表（todo 页三容器之三）
// 已完成从主列表拆出：打完勾的事项收进这里，主列表保持干净
// 筛选状态在 Leftbar.todoState；后完成的排前面
// 没有已完成时整卡不占位（hasContent=false，Column 直接跳过）
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.data.service

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: mainCol.implicitHeight + 32   // 上下各 16 留白

    // 指向 Leftbar.todoState（activeTag / starredOnly）
    property QtObject sharedState

    // 筛选状态在加载时捕获（同 TodoListCard 的回放冻结）
    property string _tag: ""
    property bool _star: false
    Component.onCompleted: {
        _tag = sharedState.activeTag
        _star = sharedState.starredOnly
    }

    // RailPage 的容器占位协议：false 时整卡不占位
    readonly property bool hasContent: doneItems.length > 0

    readonly property var doneItems: {
        void Todo.revision
        let list = (Todo.items || []).filter(i => !!i && i.done)
        if (root._star)
            list = list.filter(i => i.starred)
        if (root._tag)
            list = list.filter(i => i.tag === root._tag)
        // 后完成的排前面，回头看「今天做了什么」才是自然顺序
        return list.sort((a, b) => (b.created || 0) - (a.created || 0))
    }

    ColumnLayout {
        id: mainCol
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: Size.spacing.sm

        // 标题行 + 清空
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "已完成 " + root.doneItems.length
                font.pixelSize: Size.fontSize.labelMedium
                font.bold: true
                color: Color.text
                Layout.alignment: Qt.AlignVCenter
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "清空"
                color: clearMa.containsMouse ? Color.error : Color.textMuted
                font.pixelSize: Size.fontSize.labelSmall
                Layout.alignment: Qt.AlignVCenter
                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Todo.clearDone()
                }
            }
        }

        ListView {
            id: doneList
            Layout.fillWidth: true
            // 自适应内容：上限后滚动
            Layout.preferredHeight: Math.max(56, Math.min(280, contentHeight))
            clip: true
            spacing: Size.spacing.xs
            reuseItems: true
            model: root.doneItems
            boundsBehavior: Flickable.StopAtBounds

            // 行本体见 TodoRow.qml，跟主列表共用一份
            delegate: TodoRow {
                required property var modelData
                width: doneList.width
                height: 44
                item: modelData
                // 已完成这儿只有「打回」和「删」，星标是主列表的事
                showStar: false
            }

            Text {
                anchors.centerIn: parent
                visible: doneList.count === 0
                text: "暂无已完成"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.labelLarge
            }
        }
    }
}
