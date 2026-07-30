// WeatherIcon — meteocons SVG
// contentScale：抵消 SVG viewBox 留白（图面往往只占 60–70%）
// 性能：asynchronous；sourceSize 跟显示尺寸走，避免解码过大纹理

import QtQuick

Item {
    id: root
    property string sourceUrl: ""
    property int pixelSize: 32
    // 1.0 = 原样；主卡建议 1.25–1.35
    property real contentScale: 1.0

    width: pixelSize
    height: pixelSize

    Image {
        anchors.centerIn: parent
        width: root.pixelSize * root.contentScale
        height: root.pixelSize * root.contentScale
        source: root.sourceUrl
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
    }
}
