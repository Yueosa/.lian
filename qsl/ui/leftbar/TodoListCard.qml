// TodoListCard — 待办输入 + 列表（todo 页三容器之二；已完成在 TodoDoneCard）
// 筛选状态在 Leftbar.todoState（activeTag / starredOnly）；过滤/排序模型原样保留，改读 state
// 列表高度随内容自适应（有上限，超出滚动）
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
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

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: mainCol.implicitHeight + 32   // 上下各 16 留白

    // 指向 Leftbar.todoState（activeTag / starredOnly）
    // 不叫 state：Item 自带同名属性（状态机当前态），避免遮蔽
    property QtObject sharedState

    // 筛选状态在加载时捕获：回放（收回→派生）时旧实例继续显示旧
    // 筛选结果播退出，新实例加载时才读新状态——内容不再先于动画变
    property string _tag: ""
    property bool _star: false
    Component.onCompleted: {
        _tag = sharedState.activeTag
        _star = sharedState.starredOnly
    }

    // revision 强制依赖：完成态会重排，避免 ListView 吃旧 modelData
    readonly property var _matching: {
        void Todo.revision
        let list = (Todo.items || []).filter(i => !!i)
        if (root._star)
            list = list.filter(i => i.starred)
        if (root._tag)
            list = list.filter(i => i.tag === root._tag)
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

    ColumnLayout {
        id: mainCol
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: Size.spacing.md

        // ---- 输入行 ----
        Rectangle {
            Layout.fillWidth: true
            height: 44
            radius: Size.rounding.sm
            color: Color.surfaceContainerHigh
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
            // 自适应内容：下限留空态文案位置，上限后滚动
            Layout.preferredHeight: Math.max(120, Math.min(440, contentHeight))
            clip: true
            spacing: Size.spacing.xs
            reuseItems: true
            model: root.pendingItems
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view ? ListView.view.width : 0
                height: 52
                radius: Size.rounding.md
                color: Color.surface

                QslStateLayer { source: delegateMa }

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
                    if (root._star)
                        return "没有标记为重要的事项"
                    if (root._tag)
                        return "「" + root._tag + "」暂无待办"
                    return root.doneItems.length > 0 ? "都做完了" : "无待办事项"
                }
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
        // 停在某个标签下时按该标签归类，"全部" 下新增则不带标签
        Todo.add(txt, root.sharedState.activeTag, root._inputPriority)
        inputField.text = ""
    }
}
