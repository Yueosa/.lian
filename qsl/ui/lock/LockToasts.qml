// LockToasts — 锁屏右上的通知 toast，最多三条，点一条展开正文
//
// 第 10 轮从 LockContent 摘出来。
//
// 关闭走 Notification.dismiss(整条 entry)，不是 dismiss(notifId)。协议 id 会被
// 不同应用复用，只传它就会退化成「关一条连带关一批」——第 9 轮修过，锁屏这个
// 侧门第 10 轮又差点放回来一次。entry 里的 id 字段由页根的 notifRows 带上。

import QtQuick
import qs.data.state
import qs.data.service

Column {
    id: toasts

    property color ink: "white"
    property color inkDim: "white"
    property color inkFaint: "white"
    property var notifRows: []
    // 当前展开的那条，用协议 id 认（只是本地展开态，不涉及关闭）
    property int expandedNotif: -1

    signal expandRequested(int notifId)
    signal focusWanted()

    width: 300
    spacing: 8
    z: 3

    Repeater {
        model: toasts.notifRows
        delegate: Rectangle {
            id: toastCard
            required property var modelData
            readonly property bool open: toasts.expandedNotif === modelData.notifId
            width: 300
            height: toastCol.implicitHeight + 20
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)

            Column {
                id: toastCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 3

                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 20
                        text: modelData.appName || "应用"
                        color: Color.inversePrimary
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.labelSmall
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "close"
                        color: toasts.inkFaint
                        font.family: Size.fontIcon
                        font.pixelSize: Size.iconSize.lg
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Notification.dismiss(modelData)
                                toasts.focusWanted()
                            }
                        }
                    }
                }
                Text {
                    width: parent.width
                    text: modelData.summary || ""
                    color: toasts.ink
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.labelMedium
                    font.weight: Font.Medium
                    elide: toastCard.open ? Text.ElideNone : Text.ElideRight
                    wrapMode: toastCard.open ? Text.Wrap : Text.NoWrap
                    maximumLineCount: toastCard.open ? 4 : 1
                }
                Text {
                    width: parent.width
                    visible: toastCard.open
                        && (modelData.body || "").length > 0
                        && modelData.body !== modelData.summary
                    text: modelData.body || ""
                    color: toasts.inkDim
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.labelSmall
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    toasts.expandRequested(toastCard.open ? -1 : modelData.notifId)
                    toasts.focusWanted()
                }
            }
        }
    }

    Text {
        visible: toasts.notifRows.length > 0
        anchors.right: parent.right
        text: "全部清除"
        color: toasts.inkFaint
        font.family: Size.fontSans
        font.pixelSize: Size.fontSize.labelMedium
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Notification.dismissAll()
                toasts.focusWanted()
            }
        }
    }
}
