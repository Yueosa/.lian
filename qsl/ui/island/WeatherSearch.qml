// WeatherSearch — 天气页的定位搜索浮层：输入地名或坐标，选一个候选换定位
//
// 第 10 轮从 WeatherPage 摘出来。输入框（searchInput）原先长在页尾，而开合它的
// toggleSearch() 长在页头，中间隔着 800 行——现在框和开关在同一个文件里。
//
// 显隐由 Weather.searching 决定，本件只负责在打开时抢焦点、关闭时清空。

import QtQuick
import qs.Components
import qs.data.state
import qs.data.service

Rectangle {
    id: overlay

    z: 20
    visible: Weather.searching
    width: 280
    height: searchCol.implicitHeight + 16
    radius: Size.rounding.md
    color: Color.surfaceContainerHighest
    border.color: Color.outlineVariant
    border.width: 1

    // 页面点地名时调这个
    function toggle() {
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
            color: Color.surfaceContainerLow

            // 一个区能横跨十几公里、落在不同预报网格里，
            // 与其在同名候选里猜，不如直接把坐标喂进去（daemon 会反查地名）
            Text {
                anchors.fill: parent
                anchors.margins: 8
                visible: searchInput.text.length === 0
                text: "地名，或 25.02, 102.75"
                color: Color.textMuted
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.labelMedium
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.margins: 8
                color: Color.text
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.bodySmall
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
                color: Color.surfaceContainerLow

                QslStateLayer {
                    source: geoMa
                    tint: Color.primary
                    accent: true
                }

                Text {
                    anchors.fill: parent
                    anchors.margins: 6
                    text: modelData.label || modelData.name || ""
                    color: Color.text
                    font.pixelSize: Size.fontSize.labelSmall
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: geoMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: overlay.pickLocation(modelData.latitude, modelData.longitude,
                        modelData.label || modelData.name || "")
                }
            }
        }

        Text {
            text: "恢复 IP 定位"
            color: Color.primary
            font.pixelSize: Size.fontSize.labelSmall
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Weather.resetLocation()
            }
        }
    }
}
