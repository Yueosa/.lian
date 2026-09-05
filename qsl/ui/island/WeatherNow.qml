// WeatherNow — 天气页上排：地名/刷新 + 主视觉 + 今日温标 + 六个指标格
//
// 第 10 轮从 WeatherPage 摘出来（原文件 1233 行，一个 ColumnLayout 吃掉 801 行）。
// 刷新转圈的三件套（spinAnim / resetAnim / forceStopTimer）跟着刷新钮一起搬过来了，
// 转圈归谁、谁来停它，现在在同一个文件里能一眼看完。
//
// 跟页面的接口：
//   page      —— 回引页根，取跨区共用的色标和七日温差范围（见 WeatherPage 文件头）
//   shown     —— 错峰入场，由页面的 QslStagger 给
//   searchRequested() —— 点地名，页面去开搜索浮层

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.data.service

RowLayout {
    id: nowRow

    property Item page: null
    property bool shown: false

    signal searchRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: 176
    Layout.maximumHeight: 176
    spacing: Size.spacing.md

    opacity: shown ? 1 : 0
    transform: Translate {
        y: nowRow.shown ? 0 : 12
        Behavior on y { Anim { type: Anim.Enter } }
    }
    Behavior on opacity { Anim { type: Anim.EffectsSlow } }

    // 刷新转圈超时兜底：weatherd 卡住时别让图标一直转
    Timer {
        id: forceStopTimer
        interval: 5000
        onTriggered: nowRow.stopRefreshAnim()
    }

    Connections {
        target: Weather
        function onLoadingChanged() {
            if (!Weather.loading)
                nowRow.stopRefreshAnim()
        }
    }

    function stopRefreshAnim() {
        forceStopTimer.stop()
        if (spinAnim.running)
            spinAnim.stop()
        resetAnim.start()
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        radius: Size.rounding.lg
        color: Color.surfaceContainerHigh

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Size.spacing.md
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: Size.spacing.sm

                Text {
                    text: Weather.locationName || "定位中…"
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.labelMedium
                    font.bold: true
                    color: Color.textMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nowRow.searchRequested()
                    }
                }

                Item {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: "\uf021"
                        font.family: Size.fontMono
                        font.pixelSize: Size.iconSize.md
                        color: refreshMa.containsMouse ? Color.primary : Color.textMuted

                        // 装饰性/刷新动画，不走令牌（plan.md 白名单）
                        NumberAnimation {
                            id: spinAnim
                            target: refreshIcon
                            property: "rotation"
                            from: 0
                            to: 360
                            duration: 800
                            loops: Animation.Infinite
                        }
                        // 装饰性/刷新动画，不走令牌（plan.md 白名单）
                        RotationAnimation {
                            id: resetAnim
                            target: refreshIcon
                            property: "rotation"
                            to: 0
                            duration: 300
                            direction: RotationAnimation.Shortest
                        }
                    }
                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!spinAnim.running) {
                                resetAnim.stop()
                                refreshIcon.rotation = 0
                                spinAnim.start()
                                forceStopTimer.restart()
                                Weather.refresh(true)
                            }
                        }
                    }
                }
            }

            // 主视觉 4:6 — 左图标格居中，右文字格居中
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 120
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 4

                    WeatherIcon {
                        anchors.centerIn: parent
                        sourceUrl: Weather.iconSource
                        // 图标格宽约卡宽 40%，边长取格高主导，略放大抵消 SVG 留白
                        pixelSize: Math.round(Math.min(parent.width, parent.height) * 0.92)
                        contentScale: 1.35
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 6

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Weather.tempText
                            font.family: Size.fontMono
                            font.pixelSize: 52
                            font.weight: Font.Light
                            color: Color.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Weather.weatherText || "--"
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.titleSmall
                            font.bold: true
                            color: Color.text
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.parent.width - 8)
                        }
                        // 今日温标：↑24 ↓17 只说了区间两端，说不出「现在 19° 处在
                        // 这个区间的哪里」。游标一放，冷热就不用心算了。
                        Row {
                            id: dayScale
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6
                            topPadding: 4

                            readonly property real lo: Weather.todayMinC
                            readonly property real hi: Weather.todayMaxC
                            readonly property real span: Math.max(1, hi - lo)
                            readonly property real ratio: Weather.ready
                                ? Math.max(0, Math.min(1, (Weather.tempC - lo) / span))
                                : 0

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Weather.ready ? (Math.round(Weather.todayMinC) + "°") : "--"
                                font.family: Size.fontMono
                                font.pixelSize: Size.fontSize.bodySmall
                                color: Color.textMuted
                            }

                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 104
                                height: 10

                                Rectangle {
                                    id: dayTrack
                                    anchors.fill: parent
                                    anchors.topMargin: 2
                                    anchors.bottomMargin: 2
                                    radius: height / 2
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop {
                                            position: 0
                                            color: nowRow.page
                                                ? nowRow.page.rampColor(
                                                    (dayScale.lo - nowRow.page.dailyMinC)
                                                    / nowRow.page.dailyTempSpan)
                                                : Color.primary
                                        }
                                        GradientStop {
                                            position: 1
                                            color: nowRow.page
                                                ? nowRow.page.rampColor(
                                                    (dayScale.hi - nowRow.page.dailyMinC)
                                                    / nowRow.page.dailyTempSpan)
                                                : Color.error
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: Weather.ready
                                    width: 10
                                    height: 10
                                    radius: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.round(dayScale.ratio * (parent.width - width))
                                    color: Color.text
                                    border.width: 2
                                    border.color: Color.surfaceContainerHigh
                                    Behavior on x {
                                        Anim {}
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Weather.ready ? (Math.round(Weather.todayMaxC) + "°") : "--"
                                font.family: Size.fontMono
                                font.pixelSize: Size.fontSize.bodySmall
                                color: Color.text
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1

        ColumnLayout {
            anchors.fill: parent
            spacing: Size.spacing.sm

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Size.spacing.sm
                // 体感的信息量在「和实测差多少」，单看 21°C 等于把气温读了两遍
                WeatherMetricTile {
                    iconGlyph: "\uf2c9"
                    label: "体感"
                    value: Weather.feelsText
                    readonly property real delta: Weather.feelsLikeC - Weather.tempC
                    hint: (!Weather.ready || Math.abs(delta) < 0.5) ? "与实测持平"
                        : (delta > 0 ? "偏热 " : "偏冷 ") + Math.abs(delta).toFixed(1) + "°"
                }
                WeatherMetricTile {
                    iconGlyph: "\uf043"
                    label: "湿度"
                    value: Weather.humidityText
                    fillRatio: Weather.ready ? Weather.humidity / 100 : -1
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Size.spacing.sm
                // 箭头指向风「吹去」的方向；气象上的风向记的是来向，故 +180
                WeatherMetricTile {
                    iconGlyph: "\u2191"
                    iconRotation: Weather.ready ? Weather.windDirDeg + 180 : 0
                    label: "风速"
                    value: Weather.windText
                    hint: Weather.windDirText ? Weather.windDirText + "风" : ""
                    // 40 km/h 已是六级，再快在这条上分不出来
                    fillRatio: Weather.ready
                        ? Math.min(1, Weather.windSpeedMs * 3.6 / 40) : -1
                }
                // 1011 hPa 这个数说明不了任何事；3 小时的涨跌才是转晴还是转雨
                WeatherMetricTile {
                    readonly property int dir: Weather.pressureTrendDir
                    iconGlyph: dir === 0 ? "\u2192" : (dir > 0 ? "\u2197" : "\u2198")
                    iconColor: dir < 0 ? Color.tertiary : Color.primary
                    label: "气压 3h"
                    value: Weather.ready
                        ? (Weather.pressureTrend >= 0 ? "+" : "")
                          + Weather.pressureTrend.toFixed(1)
                        : "--"
                    hint: Weather.pressureTrendText
                    hintColor: dir < 0 ? Color.tertiary : Color.textMuted
                }
            }
            // UV 与空气质量：weatherd 一直在抓，此前从没露过面。
            // 用刻度条而非数字——严重程度该是位置，不是要心算的数值。
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Size.spacing.sm
                WeatherGaugeTile {
                    label: "紫外线"
                    valueText: Weather.uvText
                    hint: Weather.uvLevel
                    value: Weather.uvIndex
                    // WHO 分级到 11+ 封顶，超过按满格算
                    maxValue: 11
                    stops: [Color.primary, Color.secondary, Color.tertiary, Color.error]
                }
                WeatherGaugeTile {
                    label: "PM2.5"
                    valueText: Weather.pm25Text
                    hint: Weather.airLevel
                    value: Weather.pm25
                    dataOk: Weather.airAvailable
                    // HJ 633 的「重度污染」下限，再高已经没有区分意义
                    maxValue: 150
                    stops: [Color.primary, Color.secondary, Color.tertiary, Color.error]
                }
            }
        }
    }
}
