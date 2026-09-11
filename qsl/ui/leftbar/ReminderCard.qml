// ReminderCard — 工具页「提醒」容器卡（qsl.md M2）
//
// 三档：一次性（今天 HH:MM，过了排明天，响一次）/ 每天 / 指定日期（YYYY-MM-DD）。
// 表单在上：标题 + 时间（HH:MM）+ 档位芯片（指定日期多一个日期输入）+ 添加；
// 列表在下：计划时间（mono）+ 标题 + 删除按钮，按最近到点排序。
// 校验失败一句话提示（formError），不弹窗。
//
// 到点后的呈现不在这里——服务发 reminderFired，Island 收进常驻提醒队列，
// 一级岛变提醒形态、手动点掉（见 ui/island/ReminderContent.qml）。
//
// 行内「今天/明天」标签只跟分钟走（syncClock 节流，同 TimeClockCard），
// 不给每秒刷新的绑定付钱。
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.service
import qs.data.state

Item {
    id: root

    anchors.fill: parent
    implicitHeight: mainCol.implicitHeight + 32   // 上下各 16 留白

    // 指向 Leftbar.toolState（groupId / focusTick）
    property QtObject sharedState
    // 工具页用：非「提醒」组时自报空（占位协议），值由 Leftbar 装配处覆盖
    property bool hasContent: true

    // 表单态（本卡私有，不进服务）。标题/时间/日期直接读输入框的 text，
    // 不存副本——第一版存了 formTitle/formTime 但从没从输入框回读，
    // tryAdd 读到的永远是空串，提醒一条都建不出来（已修）
    property string formMode: "once"
    property string formError: ""

    readonly property bool dateMode: formMode === "date"
    readonly property int innerW: Math.round(root.width - 32)

    // 分钟节流时钟（同 TimeClockCard）：只跟「分钟」走
    property var now: Time.rawDate
    property int _minuteKey: -1

    function syncClock() {
        const d = Time.rawDate
        if (!d)
            return
        const key = d.getHours() * 60 + d.getMinutes()
        if (key === root._minuteKey)
            return
        root._minuteKey = key
        root.now = d
    }

    Connections {
        target: Time
        function onRawDateChanged() { root.syncClock() }
    }

    Component.onCompleted: root.syncClock()

    function tryAdd() {
        const r = Reminder.add(titleInput.text, formMode, timeInput.text, dateInput.text)
        if (!r.ok) {
            formError = r.error
            return
        }
        titleInput.text = ""
        timeInput.text = ""
        dateInput.text = ""
        formError = ""
        titleInput.forceActiveFocus()
    }

    // 行首的计划时间文案。once 的「今天/明天」跨午夜由分钟节流翻新
    function timeLabel(it) {
        const hh = it.at || "--:--"
        if (it.mode === "daily")
            return "每天 " + hh
        if (it.mode === "date")
            return (it.date || "").slice(5) + " " + hh
        const d = root.now
        if (!d)
            return hh
        const dayStart = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
        return it.nextAt >= dayStart + 86400000 ? "明天 " + hh : "今天 " + hh
    }

    // 按最近到点排序（不就地排：items 是服务层的数组，sort 会改写它）
    readonly property var sortedItems: {
        void Reminder.revision
        return Reminder.items.slice().sort((a, b) => a.nextAt - b.nextAt)
    }

    Connections {
        target: root.sharedState
        function onGroupIdChanged() {
            if (root.sharedState.groupId === "remind")
                Qt.callLater(() => titleInput.forceActiveFocus())
            else
                titleInput.focus = false
        }
        function onFocusTickChanged() {
            if (root.hasContent)
                Qt.callLater(() => titleInput.forceActiveFocus())
        }
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

        // ---- 表单 ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: Size.rounding.sm
            color: Color.surfaceContainerHigh

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Size.spacing.md
                anchors.rightMargin: Size.spacing.xs
                spacing: Size.spacing.sm

                TextInput {
                    id: titleInput
                    Layout.fillWidth: true
                    color: Color.text
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.bodySmall
                    clip: true
                    selectByMouse: true
                    verticalAlignment: Text.AlignVCenter
                    Keys.onReturnPressed: (e) => { root.tryAdd(); e.accepted = true }
                    Keys.onEnterPressed: (e) => { root.tryAdd(); e.accepted = true }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: !titleInput.text
                        text: "做什么"
                        color: Color.textMuted
                        font: titleInput.font
                    }
                }

                TextInput {
                    id: timeInput
                    Layout.preferredWidth: 56
                    color: Color.text
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.bodySmall
                    horizontalAlignment: Text.AlignHCenter
                    clip: true
                    selectByMouse: true
                    verticalAlignment: Text.AlignVCenter
                    Keys.onReturnPressed: (e) => { root.tryAdd(); e.accepted = true }
                    Keys.onEnterPressed: (e) => { root.tryAdd(); e.accepted = true }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        visible: !timeInput.text
                        text: "HH:MM"
                        color: Color.textMuted
                        font: timeInput.font
                    }
                }

                TextInput {
                    id: dateInput
                    Layout.preferredWidth: 100
                    visible: root.dateMode
                    color: Color.text
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.bodySmall
                    horizontalAlignment: Text.AlignHCenter
                    clip: true
                    selectByMouse: true
                    verticalAlignment: Text.AlignVCenter
                    Keys.onReturnPressed: (e) => { root.tryAdd(); e.accepted = true }
                    Keys.onEnterPressed: (e) => { root.tryAdd(); e.accepted = true }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        visible: !dateInput.text
                        text: "YYYY-MM-DD"
                        color: Color.textMuted
                        font: dateInput.font
                    }
                }

                // 添加按钮（固定 32×32，热区严格等于自身——TodoRow 的误触教训）
                Item {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "add"
                        font.family: Size.fontIcon
                        font.pixelSize: Size.iconSize.lg
                        color: Color.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tryAdd()
                    }
                }
            }
        }

        // ---- 档位芯片 ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.xs

            QslChip {
                text: "一次性"
                chipHeight: 32
                selected: root.formMode === "once"
                onClicked: root.formMode = "once"
            }
            QslChip {
                text: "每天"
                chipHeight: 32
                selected: root.formMode === "daily"
                onClicked: root.formMode = "daily"
            }
            QslChip {
                text: "指定日期"
                chipHeight: 32
                selected: root.formMode === "date"
                onClicked: root.formMode = "date"
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: root.formError.length > 0
                text: root.formError
                color: Color.error
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.labelSmall
                elide: Text.ElideRight
                Layout.maximumWidth: 150
            }
        }

        // ---- 列表 ----
        Column {
            Layout.fillWidth: true
            spacing: Size.spacing.xs

            Text {
                visible: root.sortedItems.length === 0
                width: parent.width
                height: 56
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "还没有提醒"
                color: Color.textMuted
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.bodySmall
            }

            Repeater {
                model: root.sortedItems

                delegate: Rectangle {
                    id: rowRoot
                    required property var modelData

                    width: root.innerW
                    height: 44
                    radius: Size.rounding.md
                    color: Color.surfaceContainerLow

                    QslStateLayer { source: rowMa }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Size.spacing.md
                        anchors.rightMargin: Size.spacing.xs
                        spacing: Size.spacing.sm

                        // 计划时间（mono，固定宽对齐）
                        Text {
                            Layout.preferredWidth: 92
                            text: root.timeLabel(modelData)
                            color: Color.primary
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.bodyMedium
                            elide: Text.ElideRight
                        }

                        // 标题
                        Text {
                            Layout.fillWidth: true
                            text: (modelData && modelData.title) ? modelData.title : ""
                            color: Color.text
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.bodyMedium
                            elide: Text.ElideRight
                        }

                        // 删除（悬停转 error 色）
                        Item {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: "delete"
                                font.family: Size.fontIcon
                                font.pixelSize: Size.iconSize.md
                                color: delMa.containsMouse ? Color.error : Color.textMuted
                                Behavior on color { CAnim {} }
                            }

                            QslStateLayer {
                                source: delMa
                                tint: Color.error
                            }

                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (modelData) Reminder.remove(modelData.id)
                            }
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }
    }
}
