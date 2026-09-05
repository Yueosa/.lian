// WeatherMetricTile — 固定高度指标格：避免 Grid 压缩把「体感/湿度」标签挤没
//
// 天气页专用（体感 / 湿度 / 风速 / 气压四处），第 10 轮从 WeatherPage 的内联
// component 摘出来。上面那句原先落在 GaugeTile 头上，其实说的是这个件。

import QtQuick
import QtQuick.Layouts
import qs.data.state

Rectangle {
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
            // 风向依赖 direction: Shortest 跨 0° 走最短路径，令牌表达不了
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
                font.pixelSize: Size.fontSize.labelSmall
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: tile.value
                    color: Color.text
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.titleSmall
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: tile.hint.length > 0
                    text: tile.hint
                    color: tile.hintColor
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.labelSmall
                    elide: Text.ElideRight
                }
            }
        }
    }
}
