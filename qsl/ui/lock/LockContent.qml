// LockContent — 锁屏 UI 内容（时间 + 密码输入 + 状态提示）
//
// 性能：
//   - 纯 Rectangle + Text + TextInput，无 shader/blur/image
//   - 时间更新通过 Timer 1s，不用 binding chain

import QtQuick
import QtQuick.Layouts
import qs.data.state

Item {
    id: root

    property bool unlocking: false
    property bool failed: false

    // 对外暴露当前输入的密码（只读）
    readonly property string currentText: pwdInput.text

    signal submit()

    function focusInput() {
        pwdInput.forceActiveFocus()
    }

    function clearInput() {
        pwdInput.text = ""
    }

    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: Size.spacing.xl

        Item { Layout.fillHeight: true }

        // ---- 时间 ----
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: _timeStr
            color: Color.text
            font.pixelSize: Size.fontSize.jumbo
            font.family: Size.fontMono
            font.weight: Font.Light
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: _dateStr
            color: Color.textMuted
            font.pixelSize: Size.fontSize.xl
            font.family: Size.fontSans
        }

        Item { Layout.preferredHeight: Size.spacing.xl }

        // ---- 密码框 ----
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: parent.width
            height: 56
            radius: Size.rounding.lg
            color: Color.withAlpha(Color.surfaceHighest, 0.9)
            border.width: 2
            border.color: root.failed
                ? Color.error
                : (pwdInput.activeFocus ? Color.primary : Color.outlineVariant)

            Behavior on border.color {
                ColorAnimation { duration: Size.anim.fast }
            }

            TextInput {
                id: pwdInput
                anchors.fill: parent
                anchors.leftMargin: Size.spacing.lg
                anchors.rightMargin: Size.spacing.lg
                verticalAlignment: Text.AlignVCenter
                color: Color.text
                font.pixelSize: Size.fontSize.lg
                font.family: Size.fontSans
                echoMode: TextInput.Password
                passwordCharacter: "●"
                clip: true
                focus: true
                selectByMouse: true
                enabled: !root.unlocking

                Keys.onReturnPressed: root.submit()
                Keys.onEnterPressed: root.submit()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: !pwdInput.text && !pwdInput.activeFocus
                    text: "输入密码解锁…"
                    color: Color.textMuted
                    font: pwdInput.font
                }
            }
        }

        // ---- 状态提示 ----
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.unlocking || root.failed
            text: root.unlocking ? "验证中…" : "密码错误，请重试"
            color: root.failed ? Color.error : Color.textMuted
            font.pixelSize: Size.fontSize.sm
        }

        Item { Layout.fillHeight: true }
    }

    // ---- 时间更新 ----
    property string _timeStr: ""
    property string _dateStr: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date()
            root._timeStr = now.toLocaleTimeString(Qt.locale(), "HH:mm")
            root._dateStr = now.toLocaleDateString(Qt.locale(), "yyyy年M月d日 dddd")
        }
    }

    Component.onCompleted: pwdInput.forceActiveFocus()
}
