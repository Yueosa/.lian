// TimeTimerCard — 秒表 / 倒计时（TimePage 底部计时器拆出的容器卡）
// 永远展开：无收起逻辑（2026-09-02 用户定）
//
// 容器卡：背景/圆角由宿主 RailContainer 提供（原 timerPanel 外壳 Rectangle 取消）

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.service
import qs.data.state

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: contentCol.implicitHeight + 32   // 上下各 16 留白

    // 默认展开（用户要求）；收起状态仍可通过「收起 ▲」进入
    ColumnLayout {
        id: contentCol
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: Size.spacing.sm

        // 计时面板内容（原 timerPanel.timerCol 原样迁入）
        ColumnLayout {
            id: timerCol
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            // 标题行
            RowLayout {
                Layout.fillWidth: true
                spacing: Size.spacing.sm
                Text {
                    text: "计时"
                    font.pixelSize: Size.fontSize.labelMedium
                    font.bold: true
                    color: Color.text
                    Layout.alignment: Qt.AlignVCenter
                }
                Item { Layout.fillWidth: true }
            }

            // ---- 秒表 ----
            RowLayout {
                Layout.fillWidth: true; spacing: Size.spacing.sm
                Text { text: ""; font.family: Size.fontIcon; font.pixelSize: Size.fontSize.titleMedium; color: Color.primary; Layout.alignment: Qt.AlignVCenter }
                Text { text: "秒表"; font.pixelSize: Size.fontSize.labelMedium; font.bold: true; color: Color.text; Layout.alignment: Qt.AlignVCenter }
                Item { Layout.fillWidth: true }
                Text { text: Timers.formatSec(Timers.stopwatch.elapsed); font.family: Size.fontMono; font.pixelSize: Size.fontSize.titleMedium; color: Timers.stopwatch.running ? Color.primary : Color.text; Layout.alignment: Qt.AlignVCenter }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Size.spacing.xs
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 28; radius: Size.rounding.sm
                    color: Timers.stopwatch.running ? Color.withAlpha(Color.error, 0.15) : Color.withAlpha(Color.primary, 0.15)
                    Text { anchors.centerIn: parent; text: Timers.stopwatch.running ? "暂停" : "开始"; color: Timers.stopwatch.running ? Color.error : Color.primary; font.pixelSize: Size.fontSize.labelSmall; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Timers.stopwatch.running ? Timers.pauseStopwatch() : Timers.startStopwatch() }
                }
                Rectangle {
                    visible: Timers.stopwatch.elapsed > 0 && !Timers.stopwatch.running
                    Layout.preferredWidth: 52; Layout.preferredHeight: 28; radius: Size.rounding.sm; color: Color.withAlpha(Color.text, 0.06)
                    Text { anchors.centerIn: parent; text: "重置"; color: Color.textMuted; font.pixelSize: Size.fontSize.labelSmall }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Timers.resetStopwatch() }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Color.withAlpha(Color.outlineVariant, 0.3) }

            // ---- 倒计时 ----
            RowLayout {
                Layout.fillWidth: true; spacing: Size.spacing.sm
                Text { text: ""; font.family: Size.fontIcon; font.pixelSize: Size.fontSize.titleMedium; color: Color.primary; Layout.alignment: Qt.AlignVCenter }
                Text { text: "倒计时"; font.pixelSize: Size.fontSize.labelMedium; font.bold: true; color: Color.text; Layout.alignment: Qt.AlignVCenter }
                Item { Layout.fillWidth: true }
                Text { text: Timers.formatSec(Timers.countdown.remaining); font.family: Size.fontMono; font.pixelSize: Size.fontSize.titleMedium; color: Timers.countdown.running ? Color.primary : Color.text; Layout.alignment: Qt.AlignVCenter }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Size.spacing.xs
                visible: !Timers.countdown.running && Timers.countdown.remaining <= 0
                Repeater {
                    model: [{ label: "1分", secs: 60 }, { label: "5分", secs: 300 }, { label: "15分", secs: 900 }, { label: "25分", secs: 1500 }]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 28; radius: Size.rounding.sm
                        color: Color.withAlpha(Color.text, 0.06)
                        QslStateLayer { source: cdMa; tint: Color.primary; accent: true }
                        Text { anchors.centerIn: parent; text: modelData.label; color: cdMa.containsMouse ? Color.primary : Color.textMuted; font.pixelSize: Size.fontSize.labelSmall; font.bold: cdMa.containsMouse }
                        MouseArea { id: cdMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Timers.startCountdown(modelData.secs) }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Size.spacing.xs
                visible: Timers.countdown.running || Timers.countdown.remaining > 0
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 28; radius: Size.rounding.sm
                    color: Timers.countdown.running ? Color.withAlpha(Color.error, 0.15) : Color.withAlpha(Color.primary, 0.15)
                    Text { anchors.centerIn: parent; text: Timers.countdown.running ? "暂停" : "继续"; color: Timers.countdown.running ? Color.error : Color.primary; font.pixelSize: Size.fontSize.labelSmall; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Timers.countdown.running ? Timers.pauseCountdown() : Timers.startCountdown(0) }
                }
                Rectangle {
                    Layout.preferredWidth: 52; Layout.preferredHeight: 28; radius: Size.rounding.sm; color: Color.withAlpha(Color.text, 0.06)
                    Text { anchors.centerIn: parent; text: "重置"; color: Color.textMuted; font.pixelSize: Size.fontSize.labelSmall }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Timers.resetCountdown() }
                }
            }
        }
    }
}
