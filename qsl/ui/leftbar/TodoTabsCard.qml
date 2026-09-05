// TodoTabsCard — 待办筛选条（TodoPage 头部拆出的容器卡）
// 筛选状态在 Leftbar.todoState（与 TodoListCard 共享）：activeTag / starredOnly
// 新标签输入跟随芯片条，creatingTag 是本卡私有 UI 态
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

    // 指向 Leftbar.todoState（activeTag / starredOnly）
    // 不叫 state：Item 自带同名属性（状态机当前态），避免遮蔽
    property QtObject sharedState
    property bool creatingTag: false

    ColumnLayout {
        id: mainCol
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: Size.spacing.md

        // ---- 页面标题 + 计数 ----
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "待办"
                color: Color.text
                font.pixelSize: Size.fontSize.titleMedium
                font.bold: true
            }
            Text {
                text: Todo.doneCount + "/" + Todo.count
                color: Color.textMuted
                font.pixelSize: Size.fontSize.bodySmall
                verticalAlignment: Text.AlignVCenter
            }
            Item { Layout.fillWidth: true }
        }

        // ---- 筛选行：星标开关 + 标签芯片 ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.xs

            // 星标是独立开关而非标签，所以放在分隔线左边
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 32
                radius: Size.rounding.sm
                color: root.sharedState.starredOnly
                    ? Color.primaryContainer
                    : Color.surfaceContainerHigh

                Text {
                    anchors.centerIn: parent
                    text: "star"
                    font.family: Size.fontIcon
                    font.pixelSize: 18
                    // 这套图标是可变字体，实心靠 FILL 轴而不是换字形：
                    // 老 Material Icons 的 star / star_border 两个码点
                    // 在 Material Symbols 里被合并成了同一个 star
                    font.variableAxes: ({ "FILL": root.sharedState.starredOnly ? 1 : 0,
                                          "opsz": 20 })
                    color: root.sharedState.starredOnly ? Color.primaryContainerText : Color.textMuted
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sharedState.starredOnly = !root.sharedState.starredOnly
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 20
                color: Color.surfaceContainerHighest
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                contentWidth: tagRow.implicitWidth
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: tagRow
                    spacing: Size.spacing.xs

                    QslChip {
                        text: "全部"
                        selected: root.sharedState.activeTag === ""
                        chipHeight: 32
                        onClicked: root.sharedState.activeTag = ""
                    }

                    Repeater {
                        model: Todo.tags
                        QslChip {
                            required property string modelData
                            text: modelData
                            selected: root.sharedState.activeTag === modelData
                            chipHeight: 32
                            onClicked: root.sharedState.activeTag = modelData
                            // 右键删标签：条目不会跟着没，只是退回无标签
                            onRightClicked: {
                                if (root.sharedState.activeTag === modelData)
                                    root.sharedState.activeTag = ""
                                Todo.removeTag(modelData)
                            }
                        }
                    }

                    // 新建标签
                    Rectangle {
                        width: 32
                        height: 32
                        radius: Size.rounding.sm
                        color: Color.surfaceContainerHigh

                        QslStateLayer { source: newTagMa }

                        Text {
                            anchors.centerIn: parent
                            text: "add"
                            font.family: Size.fontIcon
                            font.pixelSize: Size.iconSize.lg
                            color: Color.textMuted
                        }
                        MouseArea {
                            id: newTagMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.creatingTag = true
                                newTagInput.forceActiveFocus()
                            }
                        }
                    }
                }
            }
        }

        // 新标签输入，只在按下 + 后出现
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.creatingTag ? 36 : 0
            visible: root.creatingTag
            radius: Size.rounding.sm
            color: Color.surfaceContainerHigh
            border.width: Style.border.width
            border.color: Color.withAlpha(Color.primary, 0.5)

            TextInput {
                id: newTagInput
                anchors.fill: parent
                anchors.leftMargin: Size.spacing.md
                anchors.rightMargin: Size.spacing.md
                verticalAlignment: Text.AlignVCenter
                color: Color.text
                font.pixelSize: Size.fontSize.bodySmall
                font.family: Size.fontSans
                clip: true
                selectByMouse: true

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: !newTagInput.text
                    text: "新标签名，回车确认，Esc 取消"
                    color: Color.textMuted
                    font: newTagInput.font
                }

                function commit() {
                    const t = newTagInput.text.trim()
                    if (t)
                        Todo.addTag(t)
                    newTagInput.text = ""
                    root.creatingTag = false
                }

                Keys.onReturnPressed: (e) => { commit(); e.accepted = true }
                Keys.onEnterPressed: (e) => { commit(); e.accepted = true }
                Keys.onEscapePressed: (e) => {
                    newTagInput.text = ""
                    root.creatingTag = false
                    e.accepted = true
                }
            }
        }
    }
}
