// WeatherIcon — meteocons SVG（固定边长，asynchronous）
import QtQuick

Image {
    id: root
    property string sourceUrl: ""
    property int pixelSize: 32

    width: pixelSize
    height: pixelSize
    source: sourceUrl
    sourceSize: Qt.size(pixelSize * 2, pixelSize * 2)
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
    smooth: true
}
