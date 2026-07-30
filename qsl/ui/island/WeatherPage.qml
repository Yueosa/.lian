// WeatherPage — Hub 天气（去天穹，MetricTile 紧凑布局）
// 数据：Weather 服务；定位：点地名搜索
// 性能：随 Hub Loader 销毁；无 Astro/skyCanvas；hourly Canvas 仅数据/尺寸变更时重绘
// 布局：ColumnLayout 分区，避免锚点互相顶、顶行被裁

import QtQuick
import QtQuick.Layouts
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
    readonly property string todayHigh: (Weather.daily && Weather.daily.length > 0)
        ? Weather.daily[0].maxTemp : "--"
    readonly property string todayLow: (Weather.daily && Weather.daily.length > 0)
        ? Weather.daily[0].minTemp : "--"

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

    // 固定高度指标格：避免 Grid 压缩把「体感/湿度」标签挤没
    component MetricTile: Rectangle {
        id: tile
        property string iconGlyph: ""
        property string label: ""
        property string value: "--"

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Size.rounding.md
        color: Color.surfaceHighest
        clip: true

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
                color: Color.primary
                Layout.alignment: Qt.AlignVCenter
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
                Text {
                    Layout.fillWidth: true
                    text: tile.value
                    color: Color.text
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.md
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
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

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                radius: Size.rounding.lg
                color: Color.surfaceHigh

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

                                NumberAnimation {
                                    id: spinAnim
                                    target: refreshIcon
                                    property: "rotation"
                                    from: 0
                                    to: 360
                                    duration: 800
                                    loops: Animation.Infinite
                                }
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
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "↑" + root.todayHigh + "  ↓" + root.todayLow
                                    font.family: Size.fontMono
                                    font.pixelSize: Size.fontSize.sm
                                    color: Color.textMuted
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
                        MetricTile { iconGlyph: "\uf2c9"; label: "体感"; value: root.feelsLike }
                        MetricTile { iconGlyph: "\uf043"; label: "湿度"; value: root.humidity }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Size.spacing.sm
                        MetricTile { iconGlyph: "\uf72e"; label: "风速"; value: root.windSpeed }
                        MetricTile { iconGlyph: "\uf338"; label: "气压"; value: root.pressure }
                    }
                }
            }
        }

        // ---- 分段 ----
        Row {
            Layout.alignment: Qt.AlignLeft
            Layout.preferredHeight: 34
            Layout.maximumHeight: 34
            spacing: 4

            Rectangle {
                width: 96
                height: 34
                color: root.isHourly ? Color.primary : Color.surfaceHighest
                topLeftRadius: 17
                bottomLeftRadius: 17
                topRightRadius: root.isHourly ? 17 : 6
                bottomRightRadius: root.isHourly ? 17 : 6
                Behavior on color { ColorAnimation { duration: 180 } }

                Text {
                    anchors.centerIn: parent
                    text: "12 Hrs"
                    font.family: Size.fontSans
                    font.bold: true
                    font.pixelSize: Size.fontSize.sm
                    color: root.isHourly ? Color.textOnPrimary : Color.textMuted
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
                color: !root.isHourly ? Color.primary : Color.surfaceHighest
                topRightRadius: 17
                bottomRightRadius: 17
                topLeftRadius: !root.isHourly ? 17 : 6
                bottomLeftRadius: !root.isHourly ? 17 : 6
                Behavior on color { ColorAnimation { duration: 180 } }

                Text {
                    anchors.centerIn: parent
                    text: "7 Days"
                    font.family: Size.fontSans
                    font.bold: true
                    font.pixelSize: Size.fontSize.sm
                    color: !root.isHourly ? Color.textOnPrimary : Color.textMuted
                }
                MouseArea { anchors.fill: parent; onClicked: root.isHourly = false }
            }
        }

        // ---- 预报区：小时有底卡；七日取消套层，直接铺在岛底色上 ----
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: root.isHourly ? Size.rounding.lg : 0
            color: root.isHourly ? Color.surfaceHigh : "transparent"
            clip: true
            Behavior on color { ColorAnimation { duration: 180 } }

            Item {
                anchors.fill: parent
                anchors.margins: root.isHourly ? Size.spacing.md : Size.spacing.sm

                Canvas {
                    id: hourlyCanvas
                    anchors.fill: parent
                    renderTarget: Canvas.FramebufferObject
                    opacity: root.isHourly ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutSine } }

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
                            maxTemp += 2
                            minTemp -= 2
                        }

                        const padTop = 28, padBottom = 28, padSide = 36
                        const timeY = height - 4
                        const guideBottom = height - padBottom + 2
                        const drawHeight = Math.max(1, height - padTop - padBottom)
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

                        // 节点 → 时刻 垂直虚线（同一 paint，无额外 Item）
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

                        ctx.beginPath()
                        ctx.moveTo(points[0].x, points[0].y)
                        for (let k = 1; k < points.length; k++)
                            ctx.lineTo(points[k].x, points[k].y)
                        ctx.lineWidth = 2.5
                        ctx.strokeStyle = Color.primary
                        ctx.stroke()

                        for (let p = 0; p < points.length; p++) {
                            const pt = points[p]
                            ctx.beginPath()
                            ctx.arc(pt.x, pt.y, 4, 0, Math.PI * 2)
                            ctx.fillStyle = Color.surfaceHigh
                            ctx.fill()
                            ctx.lineWidth = 2
                            ctx.strokeStyle = Color.primary
                            ctx.stroke()

                            // 首尾点改对齐，避免温度/时刻贴边被裁
                            if (p === 0)
                                ctx.textAlign = "left"
                            else if (p === points.length - 1)
                                ctx.textAlign = "right"
                            else
                                ctx.textAlign = "center"

                            ctx.fillStyle = Color.textOnBackground
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
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutSine } }

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
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        readonly property real span: root.dailyTempSpan
                                        readonly property real startR: ((Number(modelData.minC) || 0) - root.dailyMinC) / span
                                        readonly property real widthR: Math.max(
                                            0.08,
                                            ((Number(modelData.maxC) || 0) - (Number(modelData.minC) || 0)) / span
                                        )
                                        x: parent.width * startR
                                        width: Math.max(12, parent.width * widthR)
                                        height: 7
                                        radius: 3.5
                                        color: Color.primary
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
        color: Color.surfaceHighest
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
