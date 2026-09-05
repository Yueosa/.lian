// WeatherNowcast — 天气页第二行：12 小时 / 7 日分段开关 + 降水临近预报胶囊
//
// 第 10 轮从 WeatherPage 摘出来。
//
// 跟页面的接口：
//   hourly    —— 当前选的是哪一段（由页面绑进来，本件不自己改）
//   shown     —— 错峰入场
//   pick(bool hourly) —— 用户点了哪一段，页面去改 isHourly

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.data.service

RowLayout {
    id: bar

    property bool hourly: true
    property bool shown: false

    signal pick(bool wantHourly)

    Layout.fillWidth: true
    Layout.preferredHeight: 34
    Layout.maximumHeight: 34
    spacing: Size.spacing.sm

    opacity: shown ? 1 : 0
    Behavior on opacity { Anim { type: Anim.EffectsSlow } }

    Row {
        spacing: 4

        Rectangle {
            width: 96
            height: 34
            color: bar.hourly ? Color.primary : Color.surfaceContainerHighest
            topLeftRadius: 17
            bottomLeftRadius: 17
            topRightRadius: bar.hourly ? 17 : 6
            bottomRightRadius: bar.hourly ? 17 : 6
            Behavior on color { CAnim {} }

            Text {
                anchors.centerIn: parent
                text: "12 Hrs"
                font.family: Size.fontSans
                font.bold: true
                font.pixelSize: Size.fontSize.labelMedium
                color: bar.hourly ? Color.primaryText : Color.textMuted
            }
            MouseArea {
                anchors.fill: parent
                onClicked: bar.pick(true)
            }
        }

        Rectangle {
            width: 96
            height: 34
            color: !bar.hourly ? Color.primary : Color.surfaceContainerHighest
            topRightRadius: 17
            bottomRightRadius: 17
            topLeftRadius: !bar.hourly ? 17 : 6
            bottomLeftRadius: !bar.hourly ? 17 : 6
            Behavior on color { CAnim {} }

            Text {
                anchors.centerIn: parent
                text: "7 Days"
                font.family: Size.fontSans
                font.bold: true
                font.pixelSize: Size.fontSize.labelMedium
                color: !bar.hourly ? Color.primaryText : Color.textMuted
            }
            MouseArea { anchors.fill: parent; onClicked: bar.pick(false) }
        }
    }

    Item { Layout.fillWidth: true }

    // 降水临近预报：15 分钟粒度，未来 2 小时。
    // 逐小时预报答不了「等下出门要不要带伞」——一小时里前 15 分钟下
    // 和后 15 分钟下是两回事。有雨才显示，晴天不占位。
    Rectangle {
        id: nowcastChip
        visible: Weather.minutely.length > 0 && Weather.rainingSoon
        Layout.preferredHeight: 34
        Layout.preferredWidth: nowcastRow.implicitWidth + 24
        radius: 17
        color: Color.withAlpha(Color.secondary, 0.16)
        border.width: 1
        border.color: Color.withAlpha(Color.secondary, 0.45)

        RowLayout {
            id: nowcastRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: "\uf73d"
                font.family: Size.fontMono
                font.pixelSize: Size.iconSize.md
                color: Color.secondary
            }
            Text {
                text: Weather.rainSoonText
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.bodySmall
                color: Color.text
            }
            // 8 根小柱 = 未来 2 小时逐 15 分钟的降水概率
            Row {
                spacing: 2
                Layout.alignment: Qt.AlignVCenter
                Repeater {
                    model: Weather.minutely
                    Rectangle {
                        required property var modelData
                        width: 3
                        height: 14
                        radius: 1.5
                        color: Color.withAlpha(Color.secondary, 0.22)
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            radius: parent.radius
                            height: Math.max(
                                2,
                                parent.height * Math.min(1, (Number(modelData.pop) || 0) / 100))
                            color: Color.secondary
                        }
                    }
                }
            }
        }
    }
}
