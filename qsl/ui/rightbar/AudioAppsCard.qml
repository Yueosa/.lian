// AudioAppsCard — audio 页应用音量卡
//
// 照 ~/Documents/qsl-v-designs.html 的行式语言：
//   应用音量
//   [◯ 🎵]  SPlayer                          70
//           [========音量条========]
// 圆底是该应用的静音钮；图标是应用图标（图片，不是字形）。
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
// 模型是 Pipewire 的 linkGroups（本身就是增量 ObjectModel），
// 所以应用起停自带 add/remove 过渡，不用 rowsync

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: Size.spacing.lg * 2
        + header.implicitHeight + Size.spacing.sm
        + listArea.implicitHeight

    // 首次填充不播行动画：那一拍容器自己的派生动画正在跑。一次性，触发完自己停
    property bool rowAnim: false
    Timer {
        interval: Size.anim.durNormal + 400
        running: true
        onTriggered: root.rowAnim = true
    }

    // 吃掉点击，避免穿透到 RailPage 点空白关闭层
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    QslSectionHeader {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Size.spacing.lg
        title: "应用音量"
        note: appList.count > 0 ? String(appList.count) : ""
    }

    Item {
        id: listArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: Size.spacing.sm
        anchors.leftMargin: Size.spacing.lg
        anchors.rightMargin: Size.spacing.lg
        anchors.bottomMargin: Size.spacing.lg

        // 列表自适应内容：留空态文案的位置，上限后滚动
        implicitHeight: Math.max(48, Math.min(420, appList.contentHeight))

        ListView {
            id: appList
            anchors.fill: parent
            clip: true
            spacing: Size.spacing.xs
            reuseItems: true
            model: Volume.appLinkGroups
            boundsBehavior: Flickable.StopAtBounds

            // 应用起停时行滑进/滑出，被顶开的行滑下去
            add: Transition {
                enabled: root.rowAnim
                Anim { property: "opacity"; from: 0; to: 1; type: Anim.Effects }
                Anim { property: "x"; from: 28; to: 0; type: Anim.Enter }
            }
            remove: Transition {
                enabled: root.rowAnim
                Anim { property: "opacity"; from: 1; to: 0; type: Anim.Exit }
                Anim { property: "x"; to: 28; type: Anim.Exit }
            }
            displaced: Transition {
                enabled: root.rowAnim
                Anim { properties: "x,y"; type: Anim.SpatialFast }
            }

            Text {
                anchors.centerIn: parent
                visible: appList.count === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "没有应用在播放"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.sm
            }

            delegate: QslRow {
                id: row

                required property var modelData

                width: appList.width
                height: implicitHeight

                readonly property var node: Volume.appNode(modelData)
                readonly property bool ready: Volume.appReady(node)
                readonly property bool muted: Volume.appMuted(node)
                readonly property real vol: Volume.appVolume(node)

                iconSource: Volume.appIconSource(row.node)
                iconActive: !row.muted
                iconInteractive: row.ready
                onIconClicked: Volume.toggleAppMute(row.node)

                title: Volume.appDisplayName(row.node)
                enabled: row.ready

                contentComponent: Component {
                    QslSlider {
                        value: row.vol
                        muted: row.muted
                        enabled: row.ready
                        onMoved: (v) => Volume.setAppVolume(row.node, v)
                    }
                }

                Text {
                    text: Math.round((row.muted ? 0 : row.vol) * 100)
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.sm
                    color: row.muted ? Color.textMuted : Color.primary
                }
            }
        }
    }
}
