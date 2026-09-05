// AppSearchCard — A 的第二个容器：搜索框（三拍里最后弹进那条缝的那张）
// 容器卡：背景/圆角/耳朵由宿主 RailContainer 提供，本卡只装内容
//
// 键盘的落点在这里，方向键却要驱动**另一张卡**的列表，所以选择态放在共享状态
// 里（见 Launcher.appState）。键位照搬旧 AppPage：
//   ↑↓ 移动   ←→ 翻页   Enter 启动   Esc 关（不在这里接，交给 RailPage 冒泡）
// 左右键给了翻页就意味着文本光标不能用方向键挪 —— 旧 A 就是这么定的，照旧。
//
// 输入框从开窗那一拍就存在（容器的 Loader 是同步的，只是被裁切框藏着），
// 所以三拍还没播完就打字也不会丢字。

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state

Item {
    id: root

    anchors.fill: parent

    // 指向 Launcher.appState
    property QtObject sharedState

    implicitHeight: root.sharedState ? root.sharedState.searchH : 48

    // 吃掉点击，避免穿透到 RailPage 那层「点空白关闭」；顺手把焦点抓回输入框
    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: Size.spacing.sm

        Text {
            text: "search"
            font.family: Size.fontIcon
            font.pixelSize: Size.iconSize.lg
            color: Color.textMuted
        }

        TextInput {
            id: input
            Layout.fillWidth: true
            color: Color.text
            font.pixelSize: Size.fontSize.bodyLarge
            selectionColor: Color.primary
            selectedTextColor: Color.primaryText
            clip: true

            // 焦点：声明 focus **不够**，必须自己抢一次。
            //
            // 原来这里写「RailPage 开窗会 keyScope.forceActiveFocus()，作用域自会
            // 把焦点交给声明了 focus 的子项」——错了，中间隔着 RailContainer 的
            // Loader，而 Loader 自己就是一个 focus scope：这里的 focus: true 只在
            // Loader 那层内部生效，keyScope 根本不知道下面有人要焦点。实测
            // keyboardOwner=qsl-launcher 而 input.activeFocus=false，键位全废。
            // forceActiveFocus() 会把链上每一级 scope 的 focus 都置真，才穿得过去。
            //
            // 抢完不和基类打架：基类那句 keyScope.forceActiveFocus() 是 callLater
            // 排在后面跑的，但链上 focus 已经指向本框，焦点会一路传回来
            focus: true

            Component.onCompleted: Qt.callLater(input.forceActiveFocus)

            // 每次开窗（reset 会把 focusTick 加一）重抢一次：卡片可能是上次开窗
            // 就建好的，只靠 onCompleted 抢不到第二次
            Connections {
                target: root.sharedState
                function onFocusTickChanged() { Qt.callLater(input.forceActiveFocus) }
            }

            // 单向绑定 + onTextEdited 回写：onTextChanged 会被 reset() 的程序性
            // 改写触发，容易绕成环；onTextEdited 只在用户敲键时来
            text: root.sharedState ? root.sharedState.query : ""
            onTextEdited: root.sharedState.setQuery(text)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "搜索应用..."
                color: Color.textMuted
                font.pixelSize: Size.fontSize.titleMedium
                visible: input.text.length === 0
            }

            Keys.onReturnPressed: (event) => { root.sharedState.run(); event.accepted = true }
            Keys.onEnterPressed: (event) => { root.sharedState.run(); event.accepted = true }
            Keys.onUpPressed: (event) => { root.sharedState.move(-1); event.accepted = true }
            Keys.onDownPressed: (event) => { root.sharedState.move(1); event.accepted = true }
            Keys.onLeftPressed: (event) => { root.sharedState.pageBy(-1); event.accepted = true }
            Keys.onRightPressed: (event) => { root.sharedState.pageBy(1); event.accepted = true }
        }

        Text {
            text: root.sharedState.count + " 个"
            color: Color.textMuted
            font.pixelSize: Size.fontSize.labelSmall
            visible: root.sharedState.count > 0
        }

        Text {
            text: "close"
            font.family: Size.fontIcon
            font.pixelSize: Size.iconSize.sm
            color: Color.textMuted
            visible: input.text.length > 0

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                // 清空走共享状态，不直接改 input.text：直接改会把上面那条
                // text 绑定打断，之后 reset() 就清不动这个框了
                onClicked: root.sharedState.setQuery("")
            }
        }
    }
}
