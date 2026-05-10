import QtQuick
import qs.config

// 共享卡片样式：参考 WeatherInsightCard。半透明 surface_container_high + 大圆角 + 极淡边框。
// 不要 1px 硬边框、不要 hover 整块换色。
Rectangle {
    id: card

    property real cardOpacity: 0.93
    property real borderOpacity: 0.22
    property real cardRadius: Sizes.rounding.large

    radius: cardRadius
    color: Qt.rgba(Colorscheme.surface_container_high.r,
                   Colorscheme.surface_container_high.g,
                   Colorscheme.surface_container_high.b,
                   cardOpacity)
    border.width: 1
    border.color: Qt.rgba(Colorscheme.outline_variant.r,
                          Colorscheme.outline_variant.g,
                          Colorscheme.outline_variant.b,
                          borderOpacity)
}
