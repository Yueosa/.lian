// CalcCard — 工具页「计算器」容器卡
//
// 表达式行是 TextInput（键盘直接打），下面 4×5+1 键位网格（鼠标/触摸），
// 结果随输入实时算；回车或「=」把「表达式 = 结果」压进历史（会话内、最多 10 条），
// 点历史行把结果值插回表达式。求值在 calc.js：递归下降，不用 eval——
// 用户输入不能当代码执行。
//
// 焦点：切到「计算器」组或面板开窗（focusTick）时主动夺焦，键盘开箱即用；
// 切走时放掉焦点，避免卡已收回、按键还打进看不见的输入框。
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import "calc.js" as Calc

Item {
    id: root

    anchors.fill: parent
    implicitHeight: mainCol.implicitHeight + 32   // 上下各 16 留白

    // 指向 Leftbar.toolState（groupId / focusTick）
    property QtObject sharedState
    // 工具页用：非「计算器」组时自报空（占位协议），值由 Leftbar 装配处覆盖
    property bool hasContent: true

    // 历史：{ e: 表达式, v: 数值 }，最新在前，会话内不落盘
    property var history: []

    readonly property int innerW: Math.round(root.width - 32)
    readonly property int cellW: Math.floor((innerW - 3 * 8) / 4)

    readonly property var evalResult: Calc.evaluate(input.text)

    // 4 列 × 5 行 + 通宽「=」。l=显示（正文字体）、g=连字名（图标字体）、
    // c=插进表达式的字符、a=动作
    readonly property var keyRows: [
        [ { l: "C", a: "clear" }, { l: "(", c: "(" }, { l: ")", c: ")" },
          { g: "backspace", a: "back" } ],
        [ { l: "7", c: "7" }, { l: "8", c: "8" }, { l: "9", c: "9" }, { l: "÷", c: "/" } ],
        [ { l: "4", c: "4" }, { l: "5", c: "5" }, { l: "6", c: "6" }, { l: "×", c: "*" } ],
        [ { l: "1", c: "1" }, { l: "2", c: "2" }, { l: "3", c: "3" }, { l: "−", c: "-" } ],
        [ { l: "0", c: "0" }, { l: ".", c: "." }, { l: "%", c: "%" }, { l: "+", c: "+" } ],
        [ { l: "=", a: "commit", accent: true, wide: true } ]
    ]

    // 结果压进表达式后光标停尾，方便接着算
    function setExpression(s) {
        input.text = s
        input.cursorPosition = input.text.length
        input.forceActiveFocus()
    }

    function commit() {
        if (!evalResult.ok)
            return
        history = history.concat([{ e: input.text, v: evalResult.value }]).slice(0, 10)
        setExpression(Calc.format(evalResult.value))
    }

    function pressKey(md) {
        const a = md.a
        if (a === "clear") {
            input.text = ""
        } else if (a === "back") {
            const pos = input.cursorPosition
            if (pos > 0)
                input.remove(pos - 1, pos)
        } else if (a === "commit") {
            commit()
        } else {
            input.insert(input.cursorPosition, md.c)
        }
        input.forceActiveFocus()
    }

    Connections {
        target: root.sharedState
        function onGroupIdChanged() {
            if (root.sharedState.groupId === "calc")
                Qt.callLater(() => input.forceActiveFocus())
            else
                input.focus = false
        }
        function onFocusTickChanged() {
            if (root.hasContent)
                Qt.callLater(() => input.forceActiveFocus())
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

        // ---- 表达式行 ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: Size.rounding.sm
            color: Color.surfaceContainerHigh
            border.width: input.activeFocus ? Style.border.width : 0
            border.color: Color.withAlpha(Color.primary, 0.5)

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: Size.spacing.md
                anchors.rightMargin: Size.spacing.md
                verticalAlignment: Text.AlignVCenter
                color: Color.text
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.bodyLarge
                clip: true
                selectByMouse: true

                Keys.onReturnPressed: (e) => { root.commit(); e.accepted = true }
                Keys.onEnterPressed: (e) => { root.commit(); e.accepted = true }
            }
        }

        // ---- 结果行 ----
        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            text: evalResult.ok
                ? Calc.format(evalResult.value)
                : (input.text.length > 0 ? evalResult.error : "0")
            color: evalResult.ok ? Color.primary : Color.textMuted
            font.family: Size.fontMono
            font.pixelSize: Size.fontSize.titleMedium
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideLeft
        }

        // ---- 历史（会话内）----
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(3, history.length) * 24
            visible: history.length > 0
            clip: true
            interactive: history.length > 3
            model: root.history
            boundsBehavior: Flickable.StopAtBounds

            delegate: Row {
                required property var modelData

                width: root.innerW
                height: 24

                Text {
                    width: parent.width
                    height: parent.height
                    text: (modelData.e || "") + " = " + Calc.format(modelData.v)
                    color: Color.textMuted
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.labelSmall
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                QslStateLayer { source: histMa }

                MouseArea {
                    id: histMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setExpression(Calc.format(modelData.v))
                }
            }
        }

        // ---- 键位网格 ----
        Column {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.keyRows

                Row {
                    required property var modelData

                    spacing: 8

                    Repeater {
                        model: modelData

                        delegate: Rectangle {
                            id: k

                            required property var modelData

                            width: modelData.wide ? root.innerW : root.cellW
                            height: 44
                            radius: Size.rounding.sm
                            // 「=」用强调底：全网格唯一一个「这是会提交的」
                            color: modelData.accent
                                ? Color.primaryContainer
                                : Color.surfaceContainerHigh

                            QslStateLayer {
                                source: kma
                                tint: modelData.accent
                                    ? Color.primaryContainerText : Color.text
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.l || modelData.g || ""
                                font.family: modelData.g ? Size.fontIcon : Size.fontSans
                                font.pixelSize: modelData.g
                                    ? Size.iconSize.lg : Size.fontSize.bodyLarge
                                color: modelData.accent
                                    ? Color.primaryContainerText : Color.text
                            }

                            MouseArea {
                                id: kma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pressKey(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
