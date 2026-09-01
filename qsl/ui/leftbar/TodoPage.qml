// TodoPage — 待办清单（两级分组：标签芯片 + 优先级排序）
//
// 性能：
//   - ListView reuseItems，delegate 最小化
//   - 无 Timer；数据变更通过 Todo singleton 的 signal 被动刷新
//   - 输入框为单行 TextInput，零 QTextDocument 开销

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    property string activeTag: ""
    // 星标与标签正交：可以同时「只看重要」和「只看开发」
    property bool starredOnly: false
    property bool showDone: false

    // revision 强制依赖：完成态会重排，避免 ListView 吃旧 modelData
    readonly property var _matching: {
        void Todo.revision
        let list = (Todo.items || []).filter(i => !!i)
        if (root.starredOnly)
            list = list.filter(i => i.starred)
        if (root.activeTag)
            list = list.filter(i => i.tag === root.activeTag)
        return list
    }

    readonly property var pendingItems: {
        const list = root._matching.filter(i => !i.done)
        return list.sort((a, b) => {
            if (!!a.starred !== !!b.starred)
                return a.starred ? -1 : 1
            return (a.priority || 0) - (b.priority || 0)
        })
    }

    readonly property var doneItems: {
        // 后完成的排前面，回头看「今天做了什么」才是自然顺序
        return root._matching.filter(i => i.done)
                   .sort((a, b) => (b.created || 0) - (a.created || 0))
    }

    // 展开时把已完成接在未完成后面，共用一个 ListView，
    // 两个 ListView 会各自持有一套 delegate 池，没必要
    readonly property var visibleItems:
        root.showDone ? root.pendingItems.concat(root.doneItems) : root.pendingItems

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

        // ---- 筛选行：星标开关 + 标签芯片 ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.xs

            // 星标是独立开关而非标签，所以放在分隔线左边
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 32
                radius: Size.rounding.sm
                color: root.starredOnly
                    ? Color.withAlpha(Color.primary, 0.22)
                    : Color.surfaceHigh

                Text {
                    anchors.centerIn: parent
                    text: "star"
                    font.family: Size.fontIcon
                    font.pixelSize: 18
                    // 这套图标是可变字体，实心靠 FILL 轴而不是换字形：
                    // 老 Material Icons 的 star / star_border 两个码点
                    // 在 Material Symbols 里被合并成了同一个 star
                    font.variableAxes: ({ "FILL": root.starredOnly ? 1 : 0,
                                          "opsz": 20 })
                    color: root.starredOnly ? Color.primary : Color.textMuted
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.starredOnly = !root.starredOnly
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 20
                color: Color.surfaceHighest
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
                        selected: root.activeTag === ""
                        chipHeight: 32
                        onClicked: root.activeTag = ""
                    }

                    Repeater {
                        model: Todo.tags
                        QslChip {
                            required property string modelData
                            text: modelData
                            selected: root.activeTag === modelData
                            chipHeight: 32
                            onClicked: root.activeTag = modelData
                            // 右键删标签：条目不会跟着没，只是退回无标签
                            onRightClicked: {
                                if (root.activeTag === modelData)
                                    root.activeTag = ""
                                Todo.removeTag(modelData)
                            }
                        }
                    }

                    // 新建标签
                    Rectangle {
                        width: 32
                        height: 32
                        radius: Size.rounding.sm
                        color: newTagMa.containsMouse
                            ? Color.surfaceHighest : Color.surfaceHigh

                        Text {
                            anchors.centerIn: parent
                            text: "add"
                            font.family: Size.fontIcon
                            font.pixelSize: 16
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
            color: Color.surfaceHigh
            border.width: Style.border.width
            border.color: Color.withAlpha(Color.primary, 0.5)

            TextInput {
                id: newTagInput
                anchors.fill: parent
                anchors.leftMargin: Size.spacing.md
                anchors.rightMargin: Size.spacing.md
                verticalAlignment: Text.AlignVCenter
                color: Color.text
                font.pixelSize: Size.fontSize.sm
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

        // ---- 输入行 ----
        Rectangle {
            Layout.fillWidth: true
            height: 44
            radius: Size.rounding.sm
            color: Color.surfaceHigh
            border.width: inputField.activeFocus ? 2 : Style.border.width
            border.color: inputField.activeFocus
                ? Color.primary
                : Color.withAlpha(Color.outlineVariant, Style.border.opacity)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Size.spacing.md
                anchors.rightMargin: Size.spacing.sm
                spacing: Size.spacing.sm

                TextInput {
                    id: inputField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    verticalAlignment: Text.AlignVCenter
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

                    Keys.onReturnPressed: (event) => {
                        root._addItem()
                        event.accepted = true
                    }
                    Keys.onEnterPressed: (event) => {
                        root._addItem()
                        event.accepted = true
                    }
                }

                // 优先级选择（小 badge）
                Row {
                    Layout.alignment: Qt.AlignVCenter
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
            model: root.visibleItems
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
                        width: 24; height: 24
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
                            text: "check"
                            font.family: Size.fontIcon
                            font.pixelSize: 16
                            font.variableAxes: ({ "opsz": 20 })
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
                            visible: text.length > 0
                            text: {
                                const t = modelData.tag || ""
                                const p = "T" + modelData.priority
                                return t.length > 0 ? t + " · " + p : p
                            }
                            color: Color.textMuted
                            font.pixelSize: Size.fontSize.xsm
                        }
                    }

                    // 两个按钮都给固定尺寸，热区严格等于自身：
                    // 原先用 anchors.margins:-4 各自外扩，正好吃掉中间的
                    // 间距而互相重叠，点星标右缘会误触删除
                    Item {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        Layout.alignment: Qt.AlignVCenter

                        // 24 正是这个字体 opsz 轴的默认值，也就是轮廓的原生
                        // 设计尺寸，不用再拿 opsz 去补偿缩小造成的笔画变细
                        Text {
                            anchors.centerIn: parent
                            text: "star"
                            font.family: Size.fontIcon
                            font.pixelSize: 24
                            font.variableAxes: ({ "FILL": modelData.starred ? 1 : 0 })
                            color: modelData.starred ? Color.primary : Color.textMuted
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Todo.star(modelData.id)
                        }
                    }

                    // 用 opacity 而非 visible：RowLayout 会把不可见项踢出布局，
                    // 于是每次划过一行，垃圾桶冒出来都把左边整排往左推一下
                    Item {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        Layout.alignment: Qt.AlignVCenter
                        opacity: delegateMa.containsMouse ? 1 : 0
                        Behavior on opacity {
                            Anim { type: Anim.EffectsFast }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "delete"
                            font.family: Size.fontIcon
                            font.pixelSize: 24
                            color: Color.error
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: delegateMa.containsMouse
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
                text: {
                    if (root.starredOnly)
                        return "没有标记为重要的事项"
                    if (root.activeTag)
                        return "「" + root.activeTag + "」暂无待办"
                    return root.doneItems.length > 0 ? "都做完了" : "无待办事项"
                }
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }
        }

        // ---- 已完成折叠条 ----
        // 打完勾的事项从主列表收进来，列表自己保持干净，又还能回头看
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            visible: root.doneItems.length > 0
            radius: Size.rounding.sm
            color: doneMa.containsMouse ? Color.surfaceHigh : "transparent"

            MouseArea {
                id: doneMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showDone = !root.showDone
            }

            Text {
                id: doneChevron
                anchors.left: parent.left
                anchors.leftMargin: Size.spacing.sm
                anchors.verticalCenter: parent.verticalCenter
                text: "expand_more"
                font.family: Size.fontIcon
                font.pixelSize: 18
                color: Color.textMuted
                rotation: root.showDone ? 0 : -90
                Behavior on rotation {
                    Anim { type: Anim.SpatialFast }
                }
            }

            Text {
                anchors.left: doneChevron.right
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: "已完成 " + root.doneItems.length
                color: Color.textMuted
                font.pixelSize: Size.fontSize.sm
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: Size.spacing.sm
                anchors.verticalCenter: parent.verticalCenter
                visible: doneMa.containsMouse || clearMa.containsMouse
                text: "清空"
                color: clearMa.containsMouse ? Color.error : Color.textMuted
                font.pixelSize: Size.fontSize.xsm

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
    }

    // ---- 内部状态 ----
    property int _inputPriority: 1
    property bool creatingTag: false

    function _addItem() {
        const txt = inputField.text.trim()
        if (!txt) return
        // 停在某个标签下时按该标签归类，"全部" 下新增则不带标签
        Todo.add(txt, root.activeTag, root._inputPriority)
        inputField.text = ""
    }
}
