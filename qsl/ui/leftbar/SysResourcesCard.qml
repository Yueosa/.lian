// SysResourcesCard — CPU / GPU / 内存 / 网络（SystemPage 上半拆出的容器卡）
// 卡头 = 原工具行（标题 + sysmond 告警 + 齿轮 → kitty btop）
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
// 性能：Sparkline 直读 Sysmon 历史；无 Canvas

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

    signal requestClose()

    readonly property color cpuColor: Color.primary
    readonly property color memColor: Color.secondary

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

    ColumnLayout {
        id: mainCol
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: Size.spacing.md

        // 工具行
        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            Text {
                text: "系统"
                color: Color.text
                font.pixelSize: Size.fontSize.lg
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: !Sysmon.daemonOk && Sysmon.detailActive
                text: "sysmond 未启动"
                color: Color.error
                font.pixelSize: Size.fontSize.sm
            }
            Rectangle {
                width: 40
                height: 40
                radius: Size.rounding.md
                color: btopMa.containsMouse
                    ? Color.withAlpha(Color.text, 0.08)
                    : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "settings"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.title
                    color: Color.textMuted
                }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sysmon.openBtop()
                        root.requestClose()
                    }
                }
            }
        }

        // 上：CPU / GPU / 内存
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            FillCapsule {
                title: "CPU"
                iconName: "speed"
                primaryText: Sysmon.cpuPercent.toFixed(1) + "%"
                secondaryText: Sysmon.cpuTemp > 0
                    ? (Math.round(Sysmon.cpuTemp) + "°C")
                    : "占用"
                fraction: Sysmon.cpuPercent / 100
                accent: Sysmon.cpuTemp > 85 ? Color.error : root.cpuColor
                history: Sysmon.cpuHistory
            }
            FillCapsule {
                show: Sysmon.gpuAvailable
                title: "GPU"
                iconName: "developer_board"
                primaryText: Sysmon.gpuPercent.toFixed(0) + "%"
                secondaryText: Sysmon.gpuTemp > 0
                    ? (Math.round(Sysmon.gpuTemp) + "°C")
                    : "占用"
                fraction: Sysmon.gpuPercent / 100
                accent: Sysmon.gpuTemp > 85 ? Color.error : Color.secondary
                history: Sysmon.gpuHistory
            }
            FillCapsule {
                title: "内存"
                iconName: "memory"
                primaryText: Sysmon.ramUsedGB.toFixed(1) + " / " + Sysmon.ramTotalGB.toFixed(1) + " GiB"
                secondaryText: "使用 "
                    + Sysmon.ramAppGB.toFixed(1) + "  ·  缓存 "
                    + Sysmon.ramCacheGB.toFixed(1) + " GiB"
                dual: true
                fraction: Sysmon.ramTotalGB > 0 ? (Sysmon.ramAppGB / Sysmon.ramTotalGB) : 0
                fraction2: Sysmon.ramTotalGB > 0 ? (Sysmon.ramCacheGB / Sysmon.ramTotalGB) : 0
                accent: root.memColor
                accent2: Color.withAlpha(root.memColor, 0.22)
                history: Sysmon.memHistory
            }
        }

        // 网络：上下行各一条，共用同一纵轴（按近期峰值自适应），
        // 否则两条各自归一化，视觉上会把 1 K/s 画得和 10 M/s 一样高。
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            radius: Size.rounding.lg
            color: Color.surfaceHigh
            border.width: Style.border.width
            border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Size.spacing.md
                anchors.rightMargin: Size.spacing.md
                anchors.topMargin: Size.spacing.sm
                anchors.bottomMargin: Size.spacing.sm
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Size.spacing.sm

                    Text {
                        text: "网络"
                        color: Color.textMuted
                        font.pixelSize: Size.fontSize.sm
                    }
                    Text {
                        text: Sysmon.netIface
                        color: Color.withAlpha(Color.textMuted, 0.7)
                        font.pixelSize: Size.fontSize.xsm
                        elide: Text.ElideRight
                    }
                    Item { Layout.fillWidth: true }
                    // 纵轴量程放在标题行，压在曲线上会被尖峰撞到
                    Text {
                        text: Sysmon.netPeak > 0
                            ? ("峰值 " + Sysmon.formatBytes(Sysmon.netPeak))
                            : ""
                        color: Color.withAlpha(Color.textMuted, 0.6)
                        font.pixelSize: Size.fontSize.xsm
                    }
                    Text {
                        text: "↓ " + Sysmon.formatBytes(Sysmon.netDownBps)
                        color: root.cpuColor
                        font.pixelSize: Size.fontSize.sm
                        font.bold: true
                        font.family: Size.fontMono
                    }
                    Text {
                        text: "↑ " + Sysmon.formatBytes(Sysmon.netUpBps)
                        color: Color.tertiary
                        font.pixelSize: Size.fontSize.sm
                        font.bold: true
                        font.family: Size.fontMono
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Sparkline {
                        anchors.fill: parent
                        values: Sysmon.netDownHistory
                        overrideMax: Sysmon.netPeak
                        lineColor: root.cpuColor
                    }
                    Sparkline {
                        anchors.fill: parent
                        values: Sysmon.netUpHistory
                        overrideMax: Sysmon.netPeak
                        lineColor: Color.tertiary
                        fillOpacity: 0.10
                    }
                }
            }
        }
    }
}
