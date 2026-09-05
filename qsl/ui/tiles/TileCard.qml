// TileCard — X 的唯一容器：区切换条 + 3 列磁贴网格
// 容器卡：背景/圆角/耳朵由宿主 RailContainer 提供，本卡只装内容
//
// 磁贴有两种，形状一样、行为不一样：
//   执行区  点一下跑完就关窗
//   服务区  点一下切 start/stop，**不关窗**（要看状态翻过来），底行显示状态
//
// 网格换区/换清单时是直接换 Repeater 的 model，**不挂任何 add/remove 过渡**：
// 那两条动的是透明度，被打断就冻在中途不回来，屏幕上留下半透明的残格
// （wifi 扫描页和剪贴板列表都栽在这上面，完整说明见 ui/clipboard/ClipCard.qml）

import QtQuick
import qs.Components
import qs.data.service
import qs.data.state

Item {
    id: root

    anchors.fill: parent

    // 指向 TilePanel.tileState
    property QtObject sharedState

    readonly property QtObject s: root.sharedState

    implicitHeight: root.s
        ? root.s.tabH + root.s.pad + root.s.gridH + root.s.pad
        : 0

    // 吃掉点击，避免穿透到 RailPage 那层「点空白关闭」；顺手把键盘焦点收回来
    MouseArea {
        anchors.fill: parent
        onClicked: keyCatcher.forceActiveFocus()
    }

    // ============================================================
    // 键盘
    // ============================================================
    // 这个面板没有输入框，所以要自己找个东西持有 activeFocus，否则方向键/回车
    // 谁都收不到（Tab 和 Esc 是壳的 keyScope 收的，那两个不受影响）。
    // Loader 是 focus scope，光写 focus: true 传不出去 → 盯着 focusTick 抢
    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: true

        Connections {
            target: root.s
            function onFocusTickChanged() {
                Qt.callLater(() => keyCatcher.forceActiveFocus())
            }
        }

        Component.onCompleted: Qt.callLater(() => keyCatcher.forceActiveFocus())

        Keys.onUpPressed: (event) => { event.accepted = true; root.s.move(-1) }
        Keys.onDownPressed: (event) => { event.accepted = true; root.s.move(1) }
        Keys.onLeftPressed: (event) => { event.accepted = true; root.s.moveSide(-1) }
        Keys.onRightPressed: (event) => { event.accepted = true; root.s.moveSide(1) }
        Keys.onReturnPressed: (event) => { event.accepted = true; root.s.activateCurrent() }
        Keys.onEnterPressed: (event) => { event.accepted = true; root.s.activateCurrent() }
    }

    // ============================================================
    // 区切换条
    // ============================================================
    Row {
        id: tabRow

        x: root.s ? root.s.pad : 8
        y: 0
        height: root.s ? root.s.tabH : 40
        spacing: Size.spacing.xs

        QslChip {
            text: "执行"
            icon: "bolt"
            chipHeight: 32
            anchors.verticalCenter: parent.verticalCenter
            selected: root.s && root.s.zone === "run"
            onClicked: {
                if (root.s && root.s.zone !== "run")
                    root.s.cycleZone(1)
            }
        }
        QslChip {
            text: "服务"
            icon: "settings_applications"
            chipHeight: 32
            anchors.verticalCenter: parent.verticalCenter
            selected: root.s && root.s.zone === "svc"
            onClicked: {
                if (root.s && root.s.zone !== "svc")
                    root.s.cycleZone(1)
            }
        }
    }

    // Tab 提示：贴着切换条右端，告诉人这两个区能用键盘换
    Text {
        anchors.right: parent.right
        anchors.rightMargin: root.s ? root.s.pad + 4 : 12
        anchors.verticalCenter: tabRow.verticalCenter
        text: "Tab"
        font.family: Size.fontMono
        font.pixelSize: Size.fontSize.labelSmall
        color: Color.textMuted
        opacity: 0.6
    }

    // ============================================================
    // 网格
    // ============================================================
    Grid {
        id: grid

        x: root.s ? root.s.pad : 8
        y: (root.s ? root.s.tabH + root.s.pad : 48)
        width: root.s ? root.s.innerW : 0
        columns: root.s ? root.s.columns : 3
        spacing: root.s ? root.s.gap : 8

        Repeater {
            model: root.s ? root.s.tiles : []

            delegate: Rectangle {
                id: tile

                required property int index
                required property var modelData

                readonly property bool selected: root.s && root.s.current === tile.index
                readonly property bool isSvc: root.s && root.s.isSvc
                // 从清单本体取 units，不走 Repeater 的 modelData：那边会把
                // JS 数组包成 QVariantList，Systemd.groupActive 曾经因此永远 false
                readonly property var src: {
                    const list = root.s ? root.s.tiles : []
                    return (tile.index >= 0 && tile.index < list.length)
                        ? list[tile.index] : tile.modelData
                }
                readonly property var units: tile.src && tile.src.units
                    ? tile.src.units : []

                // 服务区：一组单元全 active 才算开着。
                // 这条绑定靠读 Systemd.states 自动重算（那边是整份换新对象，
                // 换新才发通知——就地改内容不会），revision 只是给它一个显式依赖
                readonly property bool on: tile.isSvc
                    && Systemd.revision >= 0 && Systemd.groupActive(tile.units)
                readonly property bool changing: tile.isSvc
                    && Systemd.groupBusy(tile.units)

                width: root.s ? root.s.tileW : 120
                height: root.s ? root.s.tileH : 88
                radius: Size.rounding.md

                // 「开着」是持久状态，用底色表达；悬停另外叠一层
                color: tile.on
                    ? Color.primaryContainer
                    : Color.withAlpha(Color.text, 0.04)

                border.width: tile.selected ? 2 : 0
                border.color: Color.withAlpha(Color.primary, 0.7)

                Behavior on color { CAnim {} }

                QslStateLayer {
                    source: ma
                    tint: tile.on ? Color.primaryContainerText : Color.text
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        // 连字名走 Material Symbols；其余（🌸 这种）走彩色 emoji。
                        // Symbols 字体没有樱花，硬塞进去是个方框
                        readonly property string iconName: (tile.modelData && tile.modelData.icon)
                            ? String(tile.modelData.icon) : "widgets"
                        readonly property bool ligature: /^[a-z0-9_]+$/.test(iconName)
                        text: iconName
                        font.family: ligature ? Size.fontIcon : "Noto Color Emoji"
                        font.pixelSize: ligature ? 24 : 22
                        color: ligature
                            ? (tile.on ? Color.primaryContainerText : Color.text)
                            : "#000000"
                        Behavior on color { CAnim {} }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: (tile.modelData && tile.modelData.title)
                            ? tile.modelData.title : ""
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.bodySmall
                        color: tile.on ? Color.primaryContainerText : Color.text
                        elide: Text.ElideRight
                    }

                    // 底行：服务区显示状态，执行区显示注解（域名之类）
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.isSvc
                            ? (tile.changing
                                ? "切换中…"
                                : (tile.on ? "运行中" : "已停止"))
                            : ((tile.modelData && tile.modelData.note)
                                ? tile.modelData.note : "")
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.labelSmall
                        color: tile.on ? Color.primary : Color.textMuted
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.s)
                            return
                        root.s.current = tile.index
                        root.s.activate(tile.index)
                    }
                }
            }
        }
    }

    // 清单读不出来（json 写坏了）时给个说法，而不是一张空卡
    Text {
        anchors.centerIn: grid
        visible: root.s && root.s.tiles.length === 0
        width: root.s ? root.s.innerW : 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: Tiles.error.length > 0
            ? "tiles.json：" + Tiles.error
            : "tiles.json 里这个区是空的"
        font.family: Size.fontSans
        font.pixelSize: Size.fontSize.bodySmall
        color: Color.textMuted
    }

    // systemctl 报错（单元名写错、服务自己起不来）浮在卡底，不然点了没反应
    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 2
        visible: root.s && root.s.isSvc && Systemd.lastError.length > 0
        width: root.s ? root.s.innerW : 0
        horizontalAlignment: Text.AlignHCenter
        text: Systemd.lastError
        font.family: Size.fontSans
        font.pixelSize: Size.fontSize.labelSmall
        color: Color.error
        elide: Text.ElideRight
    }
}
