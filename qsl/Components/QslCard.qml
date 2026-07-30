// QslCard — 统一卡片容器
// 自带 shadow + subtle border + 圆角背景 + 可选 header（icon+title）+ body slot
//
// 用法示例：
//   QslCard {
//       title: "网络"
//       icon: "\ue894"
//       contentItem: Column { ... }
//   }
//
// 性能：
//   - 阴影: QslShadow 纯 Repeater/Rectangle（3层），无 GPU 离屏
//   - 边框: 单层 Rectangle border，opacity 0.08
//   - body slot: 通过 default property alias，不额外 Loader 开销

import QtQuick
import QtQuick.Layouts
import qs.data.state

Rectangle {
    id: card

    property string title: ""
    property string icon: ""
    property real headerSpacing: Size.spacing.sm
    default property alias contentItem: bodyContainer.data

    // 对齐 Hub：实色表面（不再用 cardAlpha 半透明）
    color: Color.surfaceHigh
    radius: Size.rounding.lg
    border.width: Style.border.width
    border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)

    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2
    implicitWidth: 300

    QslShadow {
        target: card
        blur: Style.shadow.cardBlur
        offsetY: Style.shadow.cardOffsetY
        layers: Style.shadow.cardLayers
        shadowColor: Color.withAlpha(Color.shadow, Style.shadow.cardOpacity)
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Size.spacing.md
        spacing: card.headerSpacing

        // Header row（icon + title），仅在 title 非空时出现
        RowLayout {
            visible: card.title !== ""
            spacing: Size.spacing.xs
            Layout.fillWidth: true

            Text {
                visible: card.icon !== ""
                text: card.icon
                font.family: Size.fontIcon
                font.pixelSize: Size.fontSize.lg
                color: Color.primary
            }

            Text {
                text: card.title
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.md
                font.weight: Font.DemiBold
                color: Color.text
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Body：ColumnLayout 吃子项隐式高度（勿 fillHeight，否则卡片高度算死）
        ColumnLayout {
            id: bodyContainer
            Layout.fillWidth: true
            spacing: Size.spacing.sm
        }
    }
}
