// SysDialCard — CPU/GPU/内存三圆盘（系统页首卡）
// Shape+PathAngleArc 双环（TimeClockCard 同款 idiom）：
//   CPU/GPU 外环=使用率，内环=温度（(t-30)/70 归一）
//   内存  外环=使用(ramAppGB/total)，内环=缓存(ramCacheGB/total)
// 弧长跟随数值 Anim.Spatial，与全 shell 手感一致
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    anchors.fill: parent
    implicitHeight: 176   // 盘 110 + 下挂行 18 + 边距/间距

    // 温度归一：30~100°C → 0..1
    function tempNorm(t) {
        return Math.max(0, Math.min(1, (t - 30) / 70))
    }

    component GaugeDial: Item {
        id: dial
        property real value: 0
        property real innerValue: 0
        property color ringColor: Color.primary
        property color innerColor: Color.tertiary
        property string center: ""
        property string label: ""

        implicitWidth: 110
        implicitHeight: 128

        Shape {
            anchors.top: parent.top
            width: 110
            height: 110
            antialiasing: true

            // 外环轨道 + 值
            ShapePath {
                strokeColor: Color.withAlpha(dial.ringColor, 0.16)
                strokeWidth: 8
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                PathAngleArc {
                    centerX: 55; centerY: 55
                    radiusX: 46; radiusY: 46
                    startAngle: -90; sweepAngle: 360
                }
            }
            ShapePath {
                strokeColor: dial.ringColor
                strokeWidth: 8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 55; centerY: 55
                    radiusX: 46; radiusY: 46
                    startAngle: -90
                    sweepAngle: 360 * Math.max(0, Math.min(1, dial.value))
                    Behavior on sweepAngle {
                        Anim { type: Anim.Spatial }
                    }
                }
            }

            // 内环轨道 + 值
            ShapePath {
                strokeColor: Color.withAlpha(dial.innerColor, 0.15)
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                PathAngleArc {
                    centerX: 55; centerY: 55
                    radiusX: 35; radiusY: 35
                    startAngle: -90; sweepAngle: 360
                }
            }
            ShapePath {
                strokeColor: dial.innerColor
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 55; centerY: 55
                    radiusX: 35; radiusY: 35
                    startAngle: -90
                    sweepAngle: 360 * Math.max(0, Math.min(1, dial.innerValue))
                    Behavior on sweepAngle {
                        Anim { type: Anim.Spatial }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: dial.center
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.xl
                font.bold: true
                color: Color.text
            }
        }

        Text {
            anchors.top: parent.top
            anchors.topMargin: 114
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.label
            font.pixelSize: Size.fontSize.xsm
            color: Color.textMuted
        }
    }

    RowLayout {
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Item { Layout.fillWidth: true }
        GaugeDial {
            value: Sysmon.cpuPercent / 100
            innerValue: root.tempNorm(Sysmon.cpuTemp)
            ringColor: Color.primary
            innerColor: Color.tertiary
            center: Math.round(Sysmon.cpuPercent) + "%"
            label: "CPU " + Math.round(Sysmon.cpuTemp) + "°C"
        }
        Item { Layout.fillWidth: true }
        GaugeDial {
            value: Sysmon.gpuPercent / 100
            innerValue: root.tempNorm(Sysmon.gpuTemp)
            ringColor: Color.secondary
            innerColor: Color.tertiary
            center: Math.round(Sysmon.gpuPercent) + "%"
            label: "GPU " + Math.round(Sysmon.gpuTemp) + "°C"
            visible: Sysmon.gpuAvailable
        }
        Item { Layout.fillWidth: true }
        GaugeDial {
            value: Sysmon.ramTotalGB > 0 ? Sysmon.ramAppGB / Sysmon.ramTotalGB : 0
            innerValue: Sysmon.ramTotalGB > 0 ? Sysmon.ramCacheGB / Sysmon.ramTotalGB : 0
            ringColor: Color.tertiary
            innerColor: Color.primary
            center: Sysmon.ramAppGB.toFixed(1) + "G"
            label: "使用 " + Sysmon.ramAppGB.toFixed(1) + "G · 缓存 " + Sysmon.ramCacheGB.toFixed(1) + "G"
        }
        Item { Layout.fillWidth: true }
    }
}
