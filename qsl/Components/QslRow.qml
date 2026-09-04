// QslRow — V 面板四页共用的行式单元（行式语言照 caelestia / M3）
//
// 结构：圆形图标底 + 主标题 + 副标题 + 尾部件，可选行内展开区。
//   [◯ 图标]  主标题              [尾部件…]
//             副标题
//   └── 展开区（expandComponent，expanded 时长出来）
//
// 设计规则（见 ~/Documents/qsl-v-designs.html）：点行 = 展开/切换，
// 操作放行尾，不再弹独立对话框；破坏性确认（忘记网络/设备）改成行内二次确认。
//
// 用法：嵌套子项直接进尾部位（default property）
//   QslRow {
//       icon: "wifi"; title: "WLAN"; subtitle: "已连接 · 2103"
//       QslSwitch {}
//   }

import QtQuick
import QtQuick.Layouts
import qs.data.state

Item {
    id: root

    // ---- 图标 ----
    property string icon: ""
    // 应用图标是图片不是字形（Volume.appIconSource），给了就用它替掉 icon
    property url iconSource: ""
    // 图标字体：Material Symbols 名称走 fontIcon，Nerd Font 码点走 fontMono
    property string iconFamily: Size.fontIcon
    property int iconSize: Size.fontSize.lg
    // 圆底填充态（已连接/已启用/当前默认设备）
    property bool iconActive: false
    // 圆底自己可点（音量行的圆底就是静音钮）
    property bool iconInteractive: false
    signal iconClicked()
    // 无图标的行（已保存网络、包列表）把圆底整个省掉，文字左对齐
    readonly property bool hasIcon: icon !== "" || String(iconSource) !== ""

    // ---- 文字 ----
    property string title: ""
    property string subtitle: ""
    // IP / 版本号 / 包名走等宽
    property bool titleMono: false
    // 高亮主标题（当前连接、默认设备）
    property bool titleAccent: false

    // ---- 交互 ----
    // false = 纯展示行（当前连接摘要、输出音量条），不给 hover/手型
    property bool interactive: false
    property bool enabled: true
    signal clicked()

    // ---- 主区补件 / 行内展开 ----
    // contentComponent 进文字区（音量条）；expandComponent 在整行下面长出来
    property Component contentComponent: null
    property Component expandComponent: null
    property bool expanded: false

    // ---- 尾部件（默认属性：嵌套子项自动进这里）----
    default property alias trailingData: trailingRow.data
    property int trailingSpacing: Size.spacing.sm

    readonly property int rowH: Math.max(hasIcon ? 32 : 0, textCol.implicitHeight)
    // 展开区高度单独算：只有它需要动画，行本体高度是稳定的
    readonly property int expandH: (expanded && expandLoader.item)
        ? expandLoader.item.implicitHeight + Size.spacing.sm
        : 0

    implicitHeight: rowH + Size.spacing.xs * 2 + expandArea.height
    opacity: enabled ? 1 : 0.4
    Behavior on opacity { Anim { type: Anim.EffectsFast } }

    // 行底：hover/press 反馈；仅 interactive 行有
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: -Size.spacing.xs
        height: root.rowH + Size.spacing.xs * 2
        radius: Size.rounding.md
        color: !root.interactive || !root.enabled
            ? "transparent"
            : (ma.pressed
                ? Color.withAlpha(Color.text, 0.12)
                : (ma.containsMouse ? Color.withAlpha(Color.text, 0.06) : "transparent"))
        Behavior on color { CAnim {} }

        MouseArea {
            id: ma
            anchors.fill: parent
            enabled: root.interactive && root.enabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.clicked()
        }
    }

    // 圆形图标底
    Rectangle {
        id: iconCircle
        visible: root.hasIcon
        width: 32
        height: 32
        y: (root.rowH - height) / 2
        radius: Size.rounding.full
        color: root.iconActive
            ? Color.primary
            : Color.withAlpha(Color.primary, 0.16)
        Behavior on color { CAnim {} }

        Text {
            anchors.centerIn: parent
            visible: String(root.iconSource) === ""
            text: root.icon
            font.family: root.iconFamily
            font.pixelSize: root.iconSize
            color: root.iconActive ? Color.primaryText : Color.text
            Behavior on color { CAnim {} }
        }

        Image {
            anchors.centerIn: parent
            visible: String(root.iconSource) !== ""
            source: root.iconSource
            sourceSize.width: 20
            sourceSize.height: 20
            width: 20
            height: 20
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        // 圆底当按钮用时的悬停反馈
        Rectangle {
            anchors.fill: parent
            visible: root.iconInteractive
            radius: Size.rounding.full
            color: iconMa.pressed
                ? Color.withAlpha(Color.text, 0.16)
                : (iconMa.containsMouse ? Color.withAlpha(Color.text, 0.09) : "transparent")
            Behavior on color { CAnim {} }

            MouseArea {
                id: iconMa
                anchors.fill: parent
                enabled: root.iconInteractive && root.enabled
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.iconClicked()
            }
        }
    }

    ColumnLayout {
        id: textCol
        anchors.left: root.hasIcon ? iconCircle.right : parent.left
        anchors.leftMargin: root.hasIcon ? Size.spacing.md : 0
        anchors.right: trailingRow.left
        anchors.rightMargin: root.trailingSpacing
        y: 0
        spacing: 2

        Text {
            Layout.fillWidth: true
            visible: root.title !== ""
            text: root.title
            font.family: root.titleMono ? Size.fontMono : Size.fontSans
            font.pixelSize: Size.fontSize.sm
            color: root.titleAccent ? Color.primary : Color.text
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.subtitle !== ""
            text: root.subtitle
            font.pixelSize: Size.fontSize.xsm
            color: Color.textMuted
            elide: Text.ElideRight
        }

        // 主区补件：音量条之类。放在标题/副标题下面，占满文字区宽度
        Loader {
            Layout.fillWidth: true
            active: root.contentComponent !== null
            sourceComponent: root.contentComponent
        }
    }

    // 尾部件：宽度自适应内容，行文字区让位给它
    RowLayout {
        id: trailingRow
        anchors.right: parent.right
        y: (root.rowH - height) / 2
        spacing: root.trailingSpacing
    }

    // 展开区：只在 expanded 时实例化；高度动画在这里，不牵动行本体
    Item {
        id: expandArea
        anchors.left: parent.left
        anchors.right: parent.right
        y: root.rowH + Size.spacing.xs * 2
        height: root.expandH
        clip: true

        Behavior on height { Anim { type: Anim.SpatialFast } }

        Loader {
            id: expandLoader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            active: root.expanded || expandArea.height > 0
            sourceComponent: root.expandComponent
        }
    }
}
