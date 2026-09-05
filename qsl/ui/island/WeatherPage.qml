// WeatherPage — Hub 天气（去天穹，MetricTile 紧凑布局）
// 数据：Weather 服务；定位：点地名搜索
// 性能：随 Hub Loader 销毁；无 Astro/skyCanvas；hourly Canvas 仅数据/尺寸变更时重绘
// 布局：ColumnLayout 分区，避免锚点互相顶、顶行被裁

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root
    anchors.fill: parent

    readonly property string locationName: Weather.locationName || "定位中…"
    readonly property string currentTemp: Weather.tempText
    readonly property string currentDesc: Weather.weatherText || "--"
    readonly property string feelsLike: Weather.feelsText
    readonly property string humidity: Weather.humidityText
    readonly property string windSpeed: Weather.windText
    readonly property string pressure: Weather.pressureText
    // 走常驻的 todayMaxC/MinC，不依赖只在详情页解析的 daily 数组
    readonly property string todayHigh: Weather.ready ? (Math.round(Weather.todayMaxC) + "°") : "--"
    readonly property string todayLow: Weather.ready ? (Math.round(Weather.todayMinC) + "°") : "--"

    property bool isHourly: true

    // 7 日温差条全局范围（随 daily 变；无额外对象常驻）
    readonly property real dailyMinC: {
        const d = Weather.daily
        if (!d || d.length === 0)
            return 0
        let lo = 999
        for (let i = 0; i < d.length; i++)
            lo = Math.min(lo, Number(d[i].minC) || 0)
        return lo
    }
    readonly property real dailyMaxC: {
        const d = Weather.daily
        if (!d || d.length === 0)
            return 1
        let hi = -999
        for (let i = 0; i < d.length; i++)
            hi = Math.max(hi, Number(d[i].maxC) || 0)
        return hi
    }
    readonly property real dailyTempSpan: Math.max(1, dailyMaxC - dailyMinC)

    // 冷 → 热的四段色标。与 UV / PM2.5 刻度条共用同一套，
    // 于是「颜色越靠后 = 程度越强」在整页里是同一条规则。
    readonly property var rampStops: [Color.primary, Color.secondary, Color.tertiary, Color.error]

    // 取色标上任意位置的颜色。纯算术，不建对象、不开缓冲；
    // 调用点是 7 日条（14 次/刷新）和 Canvas 渐变（1 次/重绘），量可以忽略。
    function rampColor(t) {
        const s = root.rampStops
        const n = s.length - 1
        const x = Math.max(0, Math.min(1, Number(t) || 0)) * n
        const i = Math.min(n - 1, Math.floor(x))
        const f = x - i
        const a = s[i], b = s[i + 1]
        return Qt.rgba(a.r + (b.r - a.r) * f,
                       a.g + (b.g - a.g) * f,
                       a.b + (b.b - a.b) * f, 1)
    }

    // 固定高度指标格：避免 Grid 压缩把「体感/湿度」标签挤没
    // 刻度条 — 让「严重程度」变成位置，而不是一个要心算的数字
    //
    // UV 3 和 UV 9 写成数字看不出差别，画成游标在渐变条上的位置就一目了然。
    // 渐变用 Rectangle 内建的横向 Gradient，不走 shader，也不开离屏缓冲。
    component GaugeTile: Rectangle {
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
                    font.pixelSize: Size.fontSize.xsm
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: gauge.valueText
                    color: Color.text
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.md
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: gauge.hint.length > 0
                    text: gauge.hint
                    color: Color.textMuted
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.xsm
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

    component MetricTile: Rectangle {
        id: tile
        property string iconGlyph: ""
        property string label: ""
        property string value: "--"
        // 分级词（如 UV「很高」、空气「良」）——数值本身不说明严重程度
        property string hint: ""
        property color hintColor: Color.textMuted
        property color iconColor: Color.primary
        // 图标旋转角（风向箭头用），0 为不转
        property real iconRotation: 0
        // 0–1：卡片自身按比例填充；负值关闭。
        // 让容器承载信息，而不是当背景板——「湿度 94%」不用读数字也看得出来。
        property real fillRatio: -1

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Size.rounding.md
        color: Color.surfaceContainerHighest
        clip: true

        // 一个 Rectangle，无渐变无 shader，不额外占显存
        Rectangle {
            visible: tile.fillRatio >= 0
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, tile.fillRatio))
            // 父级的 clip 只裁矩形边界、裁不掉圆角，所以填充块必须自带圆角，
            // 否则方角会从卡片的圆角处支出来。窄填充时按半宽收敛成胶囊。
            radius: Math.min(tile.radius, width / 2)
            color: Color.withAlpha(tile.iconColor, 0.16)
            Behavior on width {
                Anim {}
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Size.spacing.md
            anchors.rightMargin: Size.spacing.md
            anchors.topMargin: Size.spacing.sm
            anchors.bottomMargin: Size.spacing.sm
            spacing: Size.spacing.sm

            Text {
                text: tile.iconGlyph
                font.family: Size.fontMono
                font.pixelSize: 18
                color: tile.iconColor
                rotation: tile.iconRotation
                Layout.alignment: Qt.AlignVCenter
                Behavior on rotation {
                    RotationAnimation { duration: 400; direction: RotationAnimation.Shortest }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: tile.label
                    color: Color.textMuted
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.xsm
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: tile.value
                        color: Color.text
                        font.family: Size.fontMono
                        font.pixelSize: Size.fontSize.md
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: tile.hint.length > 0
                        text: tile.hint
                        color: tile.hintColor
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.xsm
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    function toggleSearch() {
        Weather.searching = !Weather.searching
        if (Weather.searching)
            Qt.callLater(() => searchInput.forceActiveFocus())
        else
            searchInput.text = ""
    }

    function pickLocation(lat, lon, name) {
        Weather.setLocation(lat, lon, name)
        searchInput.text = ""
    }

    function stopRefreshAnim() {
        forceStopTimer.stop()
        if (spinAnim.running)
            spinAnim.stop()
        resetAnim.start()
    }

    function repaintHourly() {
        if (hourlyCanvas.available)
            hourlyCanvas.requestPaint()
    }

    Component.onCompleted: Weather.setDetailActive(true)
    Component.onDestruction: Weather.setDetailActive(false)

    Timer {
        id: forceStopTimer
        interval: 5000
        onTriggered: root.stopRefreshAnim()
    }

    Connections {
        target: Weather
        function onLoadingChanged() {
            if (!Weather.loading)
                root.stopRefreshAnim()
        }
        function onHourlyChanged() { root.repaintHourly() }
        function onReadyChanged() { root.repaintHourly() }
    }

    QslStagger { id: stagger }
    function playEnter() { stagger.restart() }

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        anchors.margins: Size.spacing.lg
        spacing: Size.spacing.sm

        // ---- 上排：当前天气 + MetricTile ----
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 176
            Layout.maximumHeight: 176
            spacing: Size.spacing.md
            opacity: stagger.shown(0) ? 1 : 0
            transform: Translate {
                y: stagger.shown(0) ? 0 : 12
                Behavior on y { Anim { type: Anim.Enter } }
            }
            Behavior on opacity { Anim { type: Anim.EffectsSlow } }

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
                            text: root.locationName
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.sm
                            font.bold: true
                            color: Color.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleSearch()
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
                                font.pixelSize: Size.fontSize.md
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
                                    text: root.currentTemp
                                    font.family: Size.fontMono
                                    font.pixelSize: 52
                                    font.weight: Font.Light
                                    color: Color.text
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.currentDesc
                                    font.family: Size.fontSans
                                    font.pixelSize: Size.fontSize.md
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
                                        text: root.todayLow
                                        font.family: Size.fontMono
                                        font.pixelSize: Size.fontSize.sm
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
                                                    color: root.rampColor(
                                                        (dayScale.lo - root.dailyMinC)
                                                        / root.dailyTempSpan)
                                                }
                                                GradientStop {
                                                    position: 1
                                                    color: root.rampColor(
                                                        (dayScale.hi - root.dailyMinC)
                                                        / root.dailyTempSpan)
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
                                        text: root.todayHigh
                                        font.family: Size.fontMono
                                        font.pixelSize: Size.fontSize.sm
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
                        MetricTile {
                            iconGlyph: "\uf2c9"
                            label: "体感"
                            value: root.feelsLike
                            readonly property real delta: Weather.feelsLikeC - Weather.tempC
                            hint: (!Weather.ready || Math.abs(delta) < 0.5) ? "与实测持平"
                                : (delta > 0 ? "偏热 " : "偏冷 ") + Math.abs(delta).toFixed(1) + "°"
                        }
                        MetricTile {
                            iconGlyph: "\uf043"
                            label: "湿度"
                            value: root.humidity
                            fillRatio: Weather.ready ? Weather.humidity / 100 : -1
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Size.spacing.sm
                        // 箭头指向风「吹去」的方向；气象上的风向记的是来向，故 +180
                        MetricTile {
                            iconGlyph: "\u2191"
                            iconRotation: Weather.ready ? Weather.windDirDeg + 180 : 0
                            label: "风速"
                            value: root.windSpeed
                            hint: Weather.windDirText ? Weather.windDirText + "风" : ""
                            // 40 km/h 已是六级，再快在这条上分不出来
                            fillRatio: Weather.ready
                                ? Math.min(1, Weather.windSpeedMs * 3.6 / 40) : -1
                        }
                        // 1011 hPa 这个数说明不了任何事；3 小时的涨跌才是转晴还是转雨
                        MetricTile {
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
                        GaugeTile {
                            label: "紫外线"
                            valueText: Weather.uvText
                            hint: Weather.uvLevel
                            value: Weather.uvIndex
                            // WHO 分级到 11+ 封顶，超过按满格算
                            maxValue: 11
                            stops: [Color.primary, Color.secondary, Color.tertiary, Color.error]
                        }
                        GaugeTile {
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

        // ---- 分段 + 临近预报 ----
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            Layout.maximumHeight: 34
            spacing: Size.spacing.sm
            opacity: stagger.shown(1) ? 1 : 0
            Behavior on opacity { Anim { type: Anim.EffectsSlow } }

        Row {
            spacing: 4

            Rectangle {
                width: 96
                height: 34
                color: root.isHourly ? Color.primary : Color.surfaceContainerHighest
                topLeftRadius: 17
                bottomLeftRadius: 17
                topRightRadius: root.isHourly ? 17 : 6
                bottomRightRadius: root.isHourly ? 17 : 6
                Behavior on color { CAnim {} }

                Text {
                    anchors.centerIn: parent
                    text: "12 Hrs"
                    font.family: Size.fontSans
                    font.bold: true
                    font.pixelSize: Size.fontSize.sm
                    color: root.isHourly ? Color.primaryText : Color.textMuted
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.isHourly = true
                        root.repaintHourly()
                    }
                }
            }

            Rectangle {
                width: 96
                height: 34
                color: !root.isHourly ? Color.primary : Color.surfaceContainerHighest
                topRightRadius: 17
                bottomRightRadius: 17
                topLeftRadius: !root.isHourly ? 17 : 6
                bottomLeftRadius: !root.isHourly ? 17 : 6
                Behavior on color { CAnim {} }

                Text {
                    anchors.centerIn: parent
                    text: "7 Days"
                    font.family: Size.fontSans
                    font.bold: true
                    font.pixelSize: Size.fontSize.sm
                    color: !root.isHourly ? Color.primaryText : Color.textMuted
                }
                MouseArea { anchors.fill: parent; onClicked: root.isHourly = false }
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
                        font.pixelSize: 14
                        color: Color.secondary
                    }
                    Text {
                        text: Weather.rainSoonText
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.sm
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

        // ---- 预报区：小时有底卡；七日取消套层，直接铺在岛底色上 ----
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: root.isHourly ? Size.rounding.lg : 0
            color: root.isHourly ? Color.surfaceContainerHigh : "transparent"
            clip: true
            opacity: stagger.shown(2) ? 1 : 0
            transform: Translate {
                y: stagger.shown(2) ? 0 : 16
                Behavior on y { Anim { type: Anim.Enter } }
            }
            Behavior on opacity { Anim { type: Anim.EffectsSlow } }
            Behavior on color { CAnim {} }

            Item {
                anchors.fill: parent
                anchors.margins: root.isHourly ? Size.spacing.md : Size.spacing.sm

                Canvas {
                    id: hourlyCanvas
                    anchors.fill: parent
                    renderTarget: Canvas.FramebufferObject
                    opacity: root.isHourly ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { Anim { type: Anim.Effects } }

                    Connections {
                        target: Color
                        function onPrimaryChanged() { root.repaintHourly() }
                    }

                    Component.onCompleted: Qt.callLater(root.repaintHourly)
                    onWidthChanged: root.repaintHourly()
                    onHeightChanged: root.repaintHourly()

                    onPaint: {
                        const data = Weather.hourly
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        if (!data || data.length === 0) {
                            ctx.fillStyle = Color.textMuted
                            ctx.font = "14px '" + Size.fontSans + "'"
                            ctx.textAlign = "center"
                            ctx.fillText("暂无小时预报", width / 2, height / 2)
                            return
                        }

                        let minTemp = 999, maxTemp = -999
                        for (let i = 0; i < data.length; i++) {
                            const t = data[i].temp
                            if (t < minTemp) minTemp = t
                            if (t > maxTemp) maxTemp = t
                        }
                        if (maxTemp - minTemp < 4) {
                            const mid = (maxTemp + minTemp) / 2
                            maxTemp = mid + 2
                            minTemp = mid - 2
                        }
                        // 无条件留余量。此前只在温差 < 4 时补，于是 18–23° 这种
                        // 刚好不触发的量程会把最低温那条线压在画布最底边：
                        // 平段贴底、上半片全空，到降水带的虚线也被压成零长度。
                        const headroom = (maxTemp - minTemp) * 0.18
                        maxTemp += headroom
                        minTemp -= headroom

                        const padTop = 28, padBottom = 28, padSide = 36
                        const timeY = height - 4
                        // 底部让出一条降水带；温度曲线相应上移
                        const precipH = 26
                        const precipBottom = height - padBottom + 2
                        const precipTop = precipBottom - precipH
                        // 概率数字单独占一行：96% 的柱子几乎填满泳道，
                        // 数字压在柱子上会被盖掉
                        const popLabelY = precipTop - 4
                        const guideBottom = popLabelY - 10
                        const drawHeight = Math.max(1, guideBottom - padTop)
                        const drawWidth = Math.max(1, width - padSide * 2)
                        const stepX = data.length > 1 ? drawWidth / (data.length - 1) : 0
                        const points = []

                        for (let j = 0; j < data.length; j++) {
                            const normalized = (data[j].temp - minTemp) / (maxTemp - minTemp)
                            points.push({
                                x: padSide + j * stepX,
                                y: padTop + (1 - normalized) * drawHeight,
                                data: data[j]
                            })
                        }

                        // ---- 昼夜底色 ----
                        // 只给夜间段压一层暗色，白天不画。这样无论配色怎么变，
                        // 「暗的是夜里」都成立；若两边都上色则依赖冷暖对比，换主题就失效。
                        // 到 precipTop 为止：底下那条降水带必须保持统一底色，
                        // 否则同样概率的柱子压在夜色上和白天上会呈现两种深浅。
                        ctx.save()
                        ctx.fillStyle = Color.withAlpha(Color.background, 0.38)
                        for (let n = 0; n < points.length; n++) {
                            if (points[n].data.day)
                                continue
                            const half = stepX / 2
                            let x0 = points[n].x - half
                            let x1 = points[n].x + half
                            // 首尾段补到画布边缘，免得留两条突兀的白边
                            if (n === 0) x0 = 0
                            if (n === points.length - 1) x1 = width
                            ctx.fillRect(x0, 0, x1 - x0, precipTop)
                        }
                        ctx.restore()

                        // ---- 昼夜分界 ----
                        // 光有深浅两块底色，看到的人只会问「为什么一半深一半浅」。
                        // 在交界处画线并标出日出 / 日落，那块底色才成为信息。
                        ctx.save()
                        ctx.strokeStyle = Color.withAlpha(Color.textMuted, 0.55)
                        ctx.lineWidth = 1
                        ctx.setLineDash([3, 3])
                        ctx.textAlign = "center"
                        for (let m = 1; m < points.length; m++) {
                            if (points[m].data.day === points[m - 1].data.day)
                                continue
                            const bx = Math.round((points[m - 1].x + points[m].x) / 2) + 0.5
                            ctx.beginPath()
                            ctx.moveTo(bx, 13)
                            ctx.lineTo(bx, precipTop)
                            ctx.stroke()
                            ctx.fillStyle = Color.withAlpha(Color.textMuted, 0.95)
                            ctx.font = "10px '" + Size.fontSans + "'"
                            ctx.fillText(points[m].data.day ? "日出" : "日落", bx, 10)
                        }
                        ctx.restore()

                        // ---- 降水柱 ----
                        // 柱高 = 降水概率，柱色深浅 = 雨量。
                        // 只有图标的话，「30% 飘点雨」和「96% 下大雨」长得一模一样。
                        ctx.save()
                        // 独立底槽：让降水带自成一条泳道，柱子才不会被读成背景色块
                        ctx.fillStyle = Color.withAlpha(Color.background, 0.55)
                        ctx.fillRect(0, precipTop, width, precipH)

                        const barW = Math.max(3, Math.min(14, stepX * 0.46))
                        for (let b = 0; b < points.length; b++) {
                            const pop = Number(points[b].data.pop) || 0
                            if (pop <= 0)
                                continue
                            const mm = Number(points[b].data.mm) || 0
                            const h = Math.max(2, (pop / 100) * precipH)
                            // 1mm 以上就按最深画，再大在这个尺度上看不出差别
                            const alpha = 0.45 + Math.min(1, mm) * 0.55
                            ctx.fillStyle = Color.withAlpha(Color.secondary, alpha)
                            ctx.fillRect(points[b].x - barW / 2, precipBottom - h, barW, h)
                        }
                        // 泳道标签。没有它，这排柱子就是一排看不懂的方块
                        ctx.fillStyle = Color.withAlpha(Color.textMuted, 0.75)
                        ctx.font = "10px '" + Size.fontSans + "'"
                        ctx.textAlign = "left"
                        ctx.fillText("降水", 2, precipBottom - 8)

                        // 概率数字。柱高已经编码了概率，但「看着挺高」答不了
                        // 「到底是 66% 还是 96%」——要不要带伞是靠后者决定的
                        ctx.fillStyle = Color.withAlpha(Color.textMuted, 0.9)
                        ctx.font = "10px '" + Size.fontMono + "'"
                        ctx.textAlign = "center"
                        for (let q = 0; q < points.length; q++) {
                            const pq = Number(points[q].data.pop) || 0
                            if (pq <= 0)
                                continue
                            ctx.fillText(pq + "%", points[q].x, popLabelY)
                        }

                        // 降水带基线，给柱子一个落脚点
                        ctx.strokeStyle = Color.withAlpha(Color.outlineVariant, 0.5)
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(0, precipBottom + 0.5)
                        ctx.lineTo(width, precipBottom + 0.5)
                        ctx.stroke()
                        ctx.restore()

                        // 节点 → 降水带 垂直虚线（同一 paint，无额外 Item）
                        ctx.save()
                        ctx.strokeStyle = Color.withAlpha(Color.textMuted, 0.45)
                        ctx.lineWidth = 1.25
                        ctx.setLineDash([4, 5])
                        for (let g = 0; g < points.length; g++) {
                            const gp = points[g]
                            ctx.beginPath()
                            ctx.moveTo(gp.x, gp.y + 6)
                            ctx.lineTo(gp.x, guideBottom)
                            ctx.stroke()
                        }
                        ctx.restore()

                        // ---- 温度曲线 ----
                        // 按高度上色标：低处冷色、高处暖色，与 UV / PM2.5 那两条
                        // 刻度条同一套配色。于是「哪段热」不必去读数字。
                        // 一次 createLinearGradient，不额外分配纹理。
                        const tempGrad = ctx.createLinearGradient(0, padTop, 0, guideBottom)
                        const rs = root.rampStops
                        for (let s = 0; s < rs.length; s++)
                            tempGrad.addColorStop(s / (rs.length - 1), rs[rs.length - 1 - s])

                        ctx.beginPath()
                        ctx.moveTo(points[0].x, points[0].y)
                        for (let k = 1; k < points.length; k++)
                            ctx.lineTo(points[k].x, points[k].y)
                        ctx.lineWidth = 2.5
                        ctx.strokeStyle = tempGrad
                        ctx.stroke()

                        for (let p = 0; p < points.length; p++) {
                            const pt = points[p]
                            // 节点取自己那档温度的颜色，和曲线上的位置对得上
                            const dotColor = root.rampColor(
                                (pt.data.temp - minTemp) / (maxTemp - minTemp))
                            ctx.beginPath()
                            ctx.arc(pt.x, pt.y, 4, 0, Math.PI * 2)
                            ctx.fillStyle = Color.surfaceContainerHigh
                            ctx.fill()
                            ctx.lineWidth = 2
                            ctx.strokeStyle = dotColor
                            ctx.stroke()

                            // 首尾点改对齐，避免温度/时刻贴边被裁
                            if (p === 0)
                                ctx.textAlign = "left"
                            else if (p === points.length - 1)
                                ctx.textAlign = "right"
                            else
                                ctx.textAlign = "center"

                            ctx.fillStyle = Color.backgroundText
                            ctx.font = "bold 13px '" + Size.fontMono + "'"
                            ctx.fillText(pt.data.temp + "°", pt.x, pt.y - 14)

                            ctx.fillStyle = Color.textMuted
                            ctx.font = "12px '" + Size.fontSans + "'"
                            ctx.fillText(pt.data.time, pt.x, timeY)
                        }
                    }
                }

                // 7 日：用 Column 均分高度（不靠 Layout.fillHeight，那个在这里会收成 0）
                Column {
                    id: dailyCol
                    anchors.fill: parent
                    opacity: root.isHourly ? 0.0 : 1.0
                    visible: opacity > 0.01
                    Behavior on opacity { Anim { type: Anim.Effects } }

                    readonly property int rowH: Math.max(
                        36,
                        Math.floor(height / Math.max(1, Weather.daily.length))
                    )

                    Repeater {
                        model: Weather.daily

                        Item {
                            required property var modelData
                            required property int index
                            width: dailyCol.width
                            height: dailyCol.rowH

                            RowLayout {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: Size.spacing.md
                                height: 34

                                Text {
                                    Layout.preferredWidth: 58
                                    text: modelData.day
                                    color: index === 0 ? Color.primary : Color.textMuted
                                    font.family: Size.fontSans
                                    font.pixelSize: Size.fontSize.md
                                    font.bold: index === 0
                                    elide: Text.ElideRight
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                WeatherIcon {
                                    sourceUrl: modelData.icon
                                    pixelSize: 30
                                    contentScale: 1.2
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    Layout.preferredWidth: 38
                                    text: modelData.minTemp
                                    color: Color.textMuted
                                    font.family: Size.fontMono
                                    font.pixelSize: Size.fontSize.md
                                    horizontalAlignment: Text.AlignRight
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 8
                                    Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 3
                                        radius: 1.5
                                        color: Color.withAlpha(Color.textMuted, 0.2)
                                    }
                                    // 条的左右端各取自己那档温度的颜色。位置说的是
                                    // 「这天在这周里偏冷还是偏热」，颜色把同一件事再说一遍，
                                    // 于是扫一眼就能分出「凉到热」和「一直热」。
                                    Rectangle {
                                        id: tempBar
                                        anchors.verticalCenter: parent.verticalCenter
                                        readonly property real span: root.dailyTempSpan
                                        readonly property real loR: ((Number(modelData.minC) || 0) - root.dailyMinC) / span
                                        readonly property real hiR: ((Number(modelData.maxC) || 0) - root.dailyMinC) / span
                                        x: parent.width * loR
                                        width: Math.max(12, parent.width * Math.max(0.08, hiR - loR))
                                        height: 7
                                        radius: 3.5
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: root.rampColor(tempBar.loR) }
                                            GradientStop { position: 1; color: root.rampColor(tempBar.hiR) }
                                        }
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 38
                                    text: modelData.maxTemp
                                    color: Color.text
                                    font.family: Size.fontMono
                                    font.pixelSize: Size.fontSize.md
                                    font.bold: true
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            Rectangle {
                                visible: index < (Weather.daily.length - 1)
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Color.withAlpha(Color.textMuted, 0.1)
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- 定位搜索浮层 ----
    Rectangle {
        z: 20
        visible: Weather.searching
        width: 280
        height: searchCol.implicitHeight + 16
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Size.spacing.lg + 36
        anchors.leftMargin: Size.spacing.lg
        radius: Size.rounding.md
        color: Color.surfaceContainerHighest
        border.color: Color.outlineVariant
        border.width: 1

        Column {
            id: searchCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 6

            Rectangle {
                width: parent.width
                height: 32
                radius: Size.rounding.sm
                color: Color.surface

                // 一个区能横跨十几公里、落在不同预报网格里，
                // 与其在同名候选里猜，不如直接把坐标喂进去（daemon 会反查地名）
                Text {
                    anchors.fill: parent
                    anchors.margins: 8
                    visible: searchInput.text.length === 0
                    text: "地名，或 25.02, 102.75"
                    color: Color.textMuted
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.sm
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 8
                    color: Color.text
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.sm
                    clip: true
                    onTextChanged: geoDebounce.restart()
                    Keys.onReturnPressed: (event) => {
                        Weather.geocode(text)
                        event.accepted = true
                    }
                    Keys.onEscapePressed: (event) => {
                        Weather.searching = false
                        text = ""
                        event.accepted = true
                    }
                }
            }

            Timer {
                id: geoDebounce
                interval: 420
                repeat: false
                onTriggered: {
                    if (searchInput.text.trim().length >= 2)
                        Weather.geocode(searchInput.text)
                }
            }

            Repeater {
                model: Weather.geocodeResults.slice(0, 5)
                Rectangle {
                    required property var modelData
                    width: searchCol.width
                    height: 28
                    radius: Size.rounding.sm
                    color: geoMa.containsMouse ? Color.withAlpha(Color.primary, 0.15) : Color.surface

                    Text {
                        anchors.fill: parent
                        anchors.margins: 6
                        text: modelData.label || modelData.name || ""
                        color: Color.text
                        font.pixelSize: Size.fontSize.xsm
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: geoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pickLocation(modelData.latitude, modelData.longitude,
                            modelData.label || modelData.name || "")
                    }
                }
            }

            Text {
                text: "恢复 IP 定位"
                color: Color.primary
                font.pixelSize: Size.fontSize.xsm
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Weather.resetLocation()
                }
            }
        }
    }
}
