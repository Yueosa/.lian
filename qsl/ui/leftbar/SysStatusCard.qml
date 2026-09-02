// SysStatusCard — Swap / Uptime / 磁盘 / 电池（SystemPage 中下部拆出的容器卡）
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
// FillCapsule / InfoCapsule 与 SysResourcesCard 同源（机械切割，各自持有副本）

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

    function batStatusText() {
        if (Battery.charging)
            return "充电中"
        if (Battery.discharging)
            return "放电中"
        if (Battery.fullyCharged)
            return "已充满"
        return "空闲"
    }

    // 大胶囊：进度 z0；文案 z1。短进度强制 minWidth=2*radius，圆角始终等于容器，避免「小胶囊鼓边」
    component FillCapsule: Rectangle {
        id: cap
        property string title: ""
        property string iconName: ""
        property string primaryText: ""
        property string secondaryText: ""
        property real fraction: 0
        property real fraction2: 0
        property color accent: Color.primary
        property color accent2: Color.withAlpha(Color.primary, 0.28)
        property bool dual: false
        property bool show: true
        // 趋势曲线：给了数据才画，纵轴固定 0–100（这几项都是百分比）
        property var history: []

        visible: show
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Size.rounding.lg
        color: Color.surfaceHigh
        border.width: Style.border.width
        border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)
        clip: true

        // 有占用时至少 2*radius 宽，圆角才能与父容器一致
        readonly property real minBar: radius * 2
        function barWidth(frac) {
            const f = Math.max(0, Math.min(1, frac))
            if (f <= 0 || width <= 0)
                return 0
            const raw = width * f
            return Math.min(width, Math.max(cap.minBar, raw))
        }

        readonly property real fillW: dual
            ? barWidth(fraction + fraction2)
            : barWidth(fraction)
        readonly property real appW: dual ? barWidth(fraction) : 0

        Rectangle {
            z: 0
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: cap.fillW
            visible: width > 0
            radius: cap.radius
            color: cap.dual ? cap.accent2 : Color.withAlpha(cap.accent, 0.18)
        }
        Rectangle {
            z: 0
            visible: cap.dual && width > 0
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: cap.appW
            radius: cap.radius
            color: Color.withAlpha(cap.accent, 0.35)
        }

        RowLayout {
            z: 1
            anchors.fill: parent
            anchors.margins: Size.spacing.sm
            anchors.leftMargin: Size.spacing.md
            anchors.rightMargin: Size.spacing.md
            spacing: Size.spacing.sm

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Size.rounding.md
                color: Color.surfaceHighest
                border.width: 1
                border.color: Color.withAlpha(cap.accent, 0.35)
                Text {
                    anchors.centerIn: parent
                    text: cap.iconName
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.lg
                    color: cap.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: cap.title
                        color: Color.text
                        font.pixelSize: Size.fontSize.md
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: cap.primaryText
                        color: cap.accent
                        font.pixelSize: Size.fontSize.lg
                        font.bold: true
                        font.family: Size.fontMono
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: cap.secondaryText
                    color: Color.textMuted
                    font.pixelSize: Size.fontSize.sm
                    elide: Text.ElideRight
                }
            }

            // 暗底由 Sparkline 自己画：内存胶囊的进度条会一路铺到最右，
            // 曲线画在浅色填充上会糊掉，垫一层才有稳定对比度。
            // 圆角也交给它——外层套 Rectangle 的话，Item.clip 只裁矩形，
            // 填充区的下面两个角会溢出到圆角外面。
            Sparkline {
                Layout.preferredWidth: 68
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignVCenter
                visible: cap.history.length > 1
                values: cap.history
                maxValue: 100
                lineColor: cap.accent
                cornerRadius: Size.rounding.sm
                backgroundColor: Color.withAlpha(Color.background, 0.45)
            }
        }
    }

    // 单行：左标题 · 右短数值
    component InfoCapsule: Rectangle {
        id: info
        property string title: ""
        property string value: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 48
        radius: Size.rounding.lg
        color: Color.surfaceHigh
        border.width: Style.border.width
        border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Size.spacing.md
            anchors.rightMargin: Size.spacing.md
            spacing: Size.spacing.sm

            Text {
                text: info.title
                color: Color.textMuted
                font.pixelSize: Size.fontSize.sm
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: implicitWidth
            }
            Item { Layout.fillWidth: true }
            Text {
                text: info.value
                color: Color.text
                font.pixelSize: Size.fontSize.md
                font.bold: true
                font.family: Size.fontMono
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
                // 短文案不 elide，避免 ↓/数字被裁成 ...
            }
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

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Size.spacing.sm

            InfoCapsule {
                title: "Swap"
                value: Sysmon.swapTotalGB > 0.01
                    ? (Sysmon.swapUsedGB.toFixed(1) + "/" + Sysmon.swapTotalGB.toFixed(1))
                    : "—"
            }
            InfoCapsule {
                title: "Uptime"
                value: Sysmon.uptimeText
            }
        }

        FillCapsule {
            title: "磁盘 /"
            iconName: "hard_drive_2"
            primaryText: Sysmon.diskPercent.toFixed(0) + "%"
            secondaryText: Sysmon.diskUsedGB.toFixed(0) + " / "
                + Sysmon.diskTotalGB.toFixed(0) + " GB"
            fraction: Sysmon.diskPercent / 100
            accent: Color.tertiary
        }
        FillCapsule {
            show: Battery.isPresent
            title: "电池"
            iconName: Battery.charging ? "battery_charging_full" : "battery_full"
            primaryText: Math.round(Battery.percentage) + "%"
            secondaryText: root.batStatusText()
                + (Math.abs(Battery.changeRate) > 0.2
                    ? ("  ·  " + Math.abs(Battery.changeRate).toFixed(1) + " W")
                    : "")
            fraction: Battery.percentage / 100
            accent: Battery.percentage < 20 ? Color.error : Color.secondary
        }
    }
}
