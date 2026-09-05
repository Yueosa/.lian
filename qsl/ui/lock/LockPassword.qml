// LockPassword — 锁屏右下的密码框，含输错抖动
//
// 第 10 轮从 LockContent 摘出来。抖动动画跟输入框一起搬：它 target 的是本件
// 自己的 Translate，原先隔着 70 行放在页尾。
//
// 对外只给四个动作（forceFocus / clear / text / shake），页根把它们原样转发给
// LockSurface——密码明文不往外散，页根也拿不到，只能问「现在框里是什么」。

import QtQuick
import qs.data.state

Item {
    id: pwdWrap

    property color ink: "white"
    property color inkFaint: "white"
    property bool failed: false
    property bool unlocking: false
    property bool dismissing: false
    // 大钟 peek 状态：Esc 先收 peek，不是直接清空密码
    property bool clockPeek: false

    signal submit()
    signal peekDismissed()

    width: 300
    height: 54
    z: 3
    transform: Translate { id: pwdShake; x: 0 }

    function forceFocus() {
        if (!pwdWrap.dismissing)
            pwdInput.forceActiveFocus()
    }
    function clear() { pwdInput.text = "" }
    function text() { return pwdInput.text }
    function shake() { shakeAnim.restart() }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1.5
        border.color: pwdWrap.failed
            ? Color.error
            : (pwdInput.activeFocus
                ? Qt.rgba(1, 1, 1, 0.7)
                : Qt.rgba(1, 1, 1, 0.22))
        Behavior on border.color { CAnim {} }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 18
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "lock"
                font.family: Size.fontIcon
                font.pixelSize: Size.iconSize.xl
                color: pwdWrap.failed ? Color.error : pwdWrap.inkFaint
            }

            TextInput {
                id: pwdInput
                width: parent.width - 40
                anchors.verticalCenter: parent.verticalCenter
                color: pwdWrap.ink
                font.pixelSize: 15
                font.family: Size.fontSans
                echoMode: TextInput.Password
                passwordCharacter: "●"
                clip: true
                focus: true
                selectByMouse: true
                enabled: !pwdWrap.unlocking && !pwdWrap.dismissing
                horizontalAlignment: Text.AlignHCenter

                Keys.onReturnPressed: pwdWrap.submit()
                Keys.onEnterPressed: pwdWrap.submit()
                Keys.onEscapePressed: {
                    if (pwdWrap.clockPeek)
                        pwdWrap.peekDismissed()
                }

                Text {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    visible: !pwdInput.text
                    text: pwdWrap.unlocking ? "验证中…"
                        : (pwdWrap.failed ? "密码错误" : "输入密码")
                    color: pwdWrap.failed ? Color.error : pwdWrap.inkFaint
                    font: pwdInput.font
                }
            }
        }
    }

    // 装饰性/刷新动画，不走令牌（plan.md 白名单）：密码错误抖动
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: pwdShake; property: "x"; to: 14; duration: 40 }
        NumberAnimation { target: pwdShake; property: "x"; to: -12; duration: 50 }
        NumberAnimation { target: pwdShake; property: "x"; to: 8; duration: 40 }
        NumberAnimation { target: pwdShake; property: "x"; to: -6; duration: 40 }
        NumberAnimation { target: pwdShake; property: "x"; to: 0; duration: 40 }
    }
}
