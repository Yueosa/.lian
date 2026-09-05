// NotifAppRow — 应用列表页的一行：图标 + 应用名/预览 + 条数药丸
//
// 第 10 轮拆分从 NotifListCard 摘出来（原 536 行，两个 delegate 各吃掉一大截）。
// 清空波次那一串（Connections → exitDelay → exitAnim → resetVisual）跟着行一起
// 搬过来了：谁排的队、谁滑出去、谁把它复位，现在同一个文件里一眼看得完。
//
// 跟卡根的接口：
//   card      —— 回引 NotifListCard，取 sharedState / appRowHeight / rowIconSize
//   group     —— 本行的分组数据，卡根在 delegate 处用 required modelData 传进来
//   rowIndex  —— 行序号，清空错峰按它排队（同上，来自 required index）
//
// 打开某个应用直接调 sharedState.openApp()，不经卡根转信号：currentApp 本来就
// 住在 sharedState 上，绕一手只是多一层。

import QtQuick
import qs.Components
import qs.data.state

Item {
    id: appRow

    property Item card: null
    property var group: null
    property int rowIndex: -1

    // 下面读它十来次，写全 card.sharedState.xxx 太长
    readonly property QtObject shared: card.sharedState

    width: ListView.view ? ListView.view.width : 0
    height: card.appRowHeight
    clip: true

    property bool exiting: false

    function resetVisual() {
        exitAnim.stop()
        exitDelay.stop()
        exiting = false
        appBody.x = 0
        appBody.opacity = 1
    }

    // 只有清空波次会调（应用行没有单条关闭钮），只滑不收高
    function beginExit() {
        if (exiting)
            return
        exiting = true
        exitAnim.start()
    }

    ListView.onPooled: resetVisual()
    ListView.onReused: resetVisual()

    // 与详情列表同款清空退出：错开向右滑出（N 在 rightrail 上，
    // 往右滑 = 收回 rail 方向）
    Connections {
        target: appRow.shared
        function onClearingChanged() {
            if (!appRow.shared.clearing || appRow.exiting)
                return
            if (appRow.rowIndex >= appRow.shared.clearAnimMax)
                return
            exitDelay.interval = appRow.rowIndex * appRow.shared.clearStaggerMs
            exitDelay.start()
        }
    }

    Timer {
        id: exitDelay
        repeat: false
        onTriggered: appRow.beginExit()
    }

    ParallelAnimation {
        id: exitAnim
        Anim {
            target: appBody; property: "x"
            to: appRow.width; type: Anim.Spatial
        }
        Anim {
            target: appBody; property: "opacity"
            to: 0; type: Anim.EffectsFast
        }
    }

    Rectangle {
        id: appBody
        width: appRow.width
        height: appRow.height - 4
        y: 2
        radius: Size.rounding.lg
        color: Color.withAlpha(Color.surfaceContainerHighest, 0.35)

        QslStateLayer { source: appMa }

        Rectangle {
            id: appIconBox
            width: appRow.card.rowIconSize
            height: appRow.card.rowIconSize
            anchors.left: parent.left
            anchors.leftMargin: Size.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            radius: Size.rounding.md
            color: Color.primaryContainer
            clip: true

            Image {
                id: appGroupImg
                anchors.fill: parent
                anchors.margins: 4
                source: appRow.group.icon
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                sourceSize.width: appRow.card.rowIconSize
                sourceSize.height: appRow.card.rowIconSize
                visible: status === Image.Ready
            }
            // 没图标就用应用名首字，比统一的铃铛好认
            Text {
                anchors.centerIn: parent
                visible: appGroupImg.status !== Image.Ready
                text: (appRow.group.name || "?").charAt(0).toUpperCase()
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.titleMedium
                font.bold: true
                color: Color.primary
            }
        }

        Rectangle {
            id: countPill
            anchors.right: parent.right
            anchors.rightMargin: Size.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            width: countLabel.implicitWidth + Size.spacing.md
            height: 24
            radius: Size.rounding.full
            color: Color.primaryContainer
            Text {
                id: countLabel
                anchors.centerIn: parent
                text: appRow.group.count + " 条"
                color: Color.primaryContainerText
                font.pixelSize: Size.fontSize.labelSmall
                font.bold: true
            }
        }

        Column {
            anchors.left: appIconBox.right
            anchors.leftMargin: Size.spacing.md
            anchors.right: countPill.left
            anchors.rightMargin: Size.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: appRow.group.name
                color: Color.text
                font.pixelSize: Size.fontSize.titleSmall
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                width: parent.width
                text: appRow.group.preview
                color: Color.textMuted
                font.pixelSize: Size.fontSize.bodySmall
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                height: text.length > 0 ? Math.ceil(font.pixelSize * 1.35) : 0
                visible: text.length > 0
            }
        }

        MouseArea {
            id: appMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: appRow.shared.openApp(appRow.group.key)
        }
    }
}
