// WeatherGaugeTile — 刻度条格：让「严重程度」变成位置，而不是一个要心算的数字
//
// UV 3 和 UV 9 写成数字看不出差别，画成游标在渐变条上的位置就一目了然。
// 渐变用 Rectangle 内建的横向 Gradient，不走 shader，也不开离屏缓冲。
//
// 天气页专用（紫外线 / PM2.5 两处），第 10 轮从 WeatherPage 的内联 component 摘出来

import QtQuick
import QtQuick.Layouts
import qs.data.state

Rectangle {
    id: gauge

    property string label: ""
    property string valueText: "--"
    property string hint: ""
    property real value: 0
    property real maxValue: 100
    property bool dataOk: true
    // 分段色标，位置是归一化的 0–1
    property var stops: []

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: Size.rounding.md
    color: Color.surfaceContainerHighest
    clip: true

    readonly property real ratio: maxValue > 0
        ? Math.max(0, Math.min(1, value / maxValue))
        : 0

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Size.spacing.md
        anchors.rightMargin: Size.spacing.md
        anchors.topMargin: Size.spacing.sm
        anchors.bottomMargin: Size.spacing.sm
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: gauge.label
                color: Color.textMuted
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.labelSmall
            }
            Item { Layout.fillWidth: true }
            Text {
                text: gauge.valueText
                color: Color.text
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.titleSmall
                font.weight: Font.DemiBold
            }
            Text {
                visible: gauge.hint.length > 0
                text: gauge.hint
                color: Color.textMuted
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.labelSmall
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: height / 2
                opacity: gauge.dataOk ? 1 : 0.25

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: gauge.stops.length > 0 ? gauge.stops[0] : Color.primary }
                    GradientStop { position: 0.33; color: gauge.stops.length > 1 ? gauge.stops[1] : Color.primary }
                    GradientStop { position: 0.66; color: gauge.stops.length > 2 ? gauge.stops[2] : Color.primary }
                    GradientStop { position: 1.00; color: gauge.stops.length > 3 ? gauge.stops[3] : Color.error }
                }
            }

            // 游标：白心深边，压在任何底色上都看得见
            Rectangle {
                visible: gauge.dataOk
                width: 10
                height: 10
                radius: 5
                anchors.verticalCenter: track.verticalCenter
                x: Math.round(gauge.ratio * (track.width - width))
                color: Color.text
                border.width: 2
                border.color: Color.surfaceContainerHighest
                Behavior on x {
                    Anim {}
                }
            }
        }
    }
}
