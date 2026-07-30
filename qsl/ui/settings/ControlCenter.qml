// ControlCenter — 设置占位窗（P2 #10）
// 复用 FreeWindow；关窗 mask=0；无 Image/blur

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.ui.freewindow

FreeWindow {
    id: root

    shellNamespace: "qsl-settings"

    Rectangle {
        anchors.fill: parent
        color: Color.background
        radius: Size.rounding.xxl
        border.width: 1
        border.color: Color.outlineVariant

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(420, parent.width - 80)
            spacing: Size.spacing.lg

            RowLayout {
                Layout.fillWidth: true
                spacing: Size.spacing.md

                Text {
                    text: "settings"
                    font.family: Size.fontIcon
                    font.pixelSize: 36
                    color: Color.primary
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "设置"
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.hero
                        font.bold: true
                        color: Color.textOnBackground
                    }
                    Text {
                        text: "ControlCenter 占位（P2 #10）"
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.md
                        color: Color.textMuted
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "顶栏齿轮已接通。完整面板稍后实现。\nIPC：qs ipc call settings open / toggle / close"
                wrapMode: Text.WordWrap
                color: Color.textMuted
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.md
                lineHeight: 1.4
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Size.spacing.md
                width: closeLabel.implicitWidth + 28
                height: 36
                radius: Size.rounding.full
                color: closeMa.containsMouse
                    ? Color.withAlpha(Color.primary, 0.2)
                    : Color.surfaceHigh

                Text {
                    id: closeLabel
                    anchors.centerIn: parent
                    text: "关闭"
                    color: Color.primary
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.md
                    font.bold: true
                }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeWindow()
                }
            }
        }
    }
}
