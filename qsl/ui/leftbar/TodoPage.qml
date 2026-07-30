// TodoPage — 待办清单（两级分组：标签芯片 + 优先级排序）
//
// 性能：
//   - ListView reuseItems，delegate 最小化
//   - 无 Timer；数据变更通过 Todo singleton 的 signal 被动刷新
//   - 输入框为单行 TextInput，零 QTextDocument 开销

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.data.service

Item {
    id: root

    property string activeTag: ""

    readonly property var filteredItems: {
        const list = Todo.itemsByTag(activeTag)
        // 排序：未完成在前，组内按优先级 T0>T1>T2
        return [...list].sort((a, b) => {
            if (a.done !== b.done) return a.done ? 1 : -1
            return a.priority - b.priority
        })
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.md

        // ---- 页面标题 + 计数 ----
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "待办"
                color: Color.text
                font.pixelSize: Size.fontSize.lg
                font.bold: true
            }
            Text {
                text: Todo.doneCount + "/" + Todo.count
                color: Color.textMuted
                font.pixelSize: Size.fontSize.sm
                verticalAlignment: Text.AlignVCenter
            }
            Item { Layout.fillWidth: true }
        }

        // ---- 标签芯片行 ----
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

                // "全部" 芯片
                Rectangle {
                    readonly property bool selected: root.activeTag === ""
                    height: 32; width: allLbl.implicitWidth + 20
                    radius: Size.rounding.full
                    color: selected
                        ? Color.withAlpha(Color.primary, 0.18)
                        : (allMa.containsMouse
                            ? Color.withAlpha(Color.text, 0.06)
                            : Color.surface)
                    Text {
                        id: allLbl; anchors.centerIn: parent
                        text: "全部"
                        color: parent.selected ? Color.primary : Color.textMuted
                        font.pixelSize: Size.fontSize.sm
                        font.bold: parent.selected
                    }
                    MouseArea {
                        id: allMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTag = ""
                    }
                }

                Repeater {
                    model: Todo.tags
                    Rectangle {
                        required property string modelData
                        readonly property bool selected: root.activeTag === modelData
                        height: 32; width: tagLbl.implicitWidth + 20
                        radius: Size.rounding.full
                        color: selected
                            ? Color.withAlpha(Color.primary, 0.18)
                            : (tagMa.containsMouse
                                ? Color.withAlpha(Color.text, 0.06)
                                : Color.surface)
                        Text {
                            id: tagLbl; anchors.centerIn: parent
                            text: modelData
                            color: selected ? Color.primary : Color.textMuted
                            font.pixelSize: Size.fontSize.sm
                            font.bold: selected
                        }
                        MouseArea {
                            id: tagMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTag = modelData
                        }
                    }
                }
            }
        }

        // ---- 输入行 ----
        Rectangle {
            Layout.fillWidth: true
            height: 44
            radius: Size.rounding.sm
            color: Color.surface
            border.width: inputField.activeFocus ? 2 : 0
            border.color: Color.primary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Size.spacing.md
                anchors.rightMargin: Size.spacing.sm
                spacing: Size.spacing.sm

                TextInput {
                    id: inputField
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    color: Color.text
                    font.pixelSize: Size.fontSize.md
                    font.family: Size.fontSans
                    clip: true
                    selectByMouse: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: !inputField.text && !inputField.activeFocus
                        text: "添加新待办…"
                        color: Color.textMuted
                        font: inputField.font
                    }

                    Keys.onReturnPressed: _addItem()
                    Keys.onEnterPressed: _addItem()
                }

                // 优先级选择（小 badge）
                Row {
                    spacing: 2
                    Repeater {
                        model: ["T0", "T1", "T2"]
                        Rectangle {
                            required property string modelData
                            required property int index
                            readonly property bool selected: root._inputPriority === index
                            width: 28; height: 24
                            radius: Size.rounding.xs
                            color: selected
                                ? Color.withAlpha(Color.primary, 0.22)
                                : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: selected ? Color.primary : Color.textMuted
                                font.pixelSize: Size.fontSize.xsm
                                font.bold: selected
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root._inputPriority = index
                            }
                        }
                    }
                }
            }
        }

        // ---- 列表 ----
        ListView {
            id: todoList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Size.spacing.xs
            reuseItems: true
            model: root.filteredItems
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view ? ListView.view.width : 0
                height: 52
                radius: Size.rounding.md
                color: delegateMa.containsMouse
                    ? Color.withAlpha(Color.text, 0.04)
                    : Color.surface

                MouseArea {
                    id: delegateMa
                    anchors.fill: parent
                    hoverEnabled: true
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Size.spacing.md
                    anchors.rightMargin: Size.spacing.md
                    spacing: Size.spacing.sm

                    // 勾选框
                    Rectangle {
                        width: 22; height: 22
                        radius: Size.rounding.xs
                        color: modelData.done
                            ? Color.primary
                            : "transparent"
                        border.width: modelData.done ? 0 : 2
                        border.color: Color.outlineVariant
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            visible: modelData.done
                            text: "\ue876"
                            font.family: Size.fontIcon
                            font.pixelSize: 14
                            color: Color.surface
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Todo.toggle(modelData.id)
                        }
                    }

                    // 内容
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: modelData.text || ""
                            color: modelData.done ? Color.textMuted : Color.text
                            font.pixelSize: Size.fontSize.md
                            font.strikeout: modelData.done
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            visible: modelData.tag !== ""
                            text: modelData.tag + " · T" + modelData.priority
                            color: Color.textMuted
                            font.pixelSize: Size.fontSize.xsm
                        }
                    }

                    // 收藏按钮
                    Text {
                        text: modelData.starred ? "\ue838" : "\ue83a"
                        font.family: Size.fontIcon
                        font.pixelSize: 18
                        color: modelData.starred ? Color.primary : Color.textMuted
                        Layout.alignment: Qt.AlignVCenter
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Todo.star(modelData.id)
                        }
                    }

                    // 删除按钮（hover 时显示）
                    Text {
                        visible: delegateMa.containsMouse
                        text: "\ue872"
                        font.family: Size.fontIcon
                        font.pixelSize: 18
                        color: Color.error
                        Layout.alignment: Qt.AlignVCenter
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Todo.remove(modelData.id)
                        }
                    }
                }
            }

            // 空状态
            Text {
                anchors.centerIn: parent
                visible: todoList.count === 0
                text: root.activeTag
                    ? "「" + root.activeTag + "」暂无待办"
                    : "无待办事项"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }
        }
    }

    // ---- 内部状态 ----
    property int _inputPriority: 1

    function _addItem() {
        const txt = inputField.text.trim()
        if (!txt) return
        const tag = root.activeTag === "" || root.activeTag === "重要"
            ? "生活" : root.activeTag
        Todo.add(txt, tag, root._inputPriority)
        inputField.text = ""
    }
}
