// AudioOutputCard — audio 页首卡：输出主音量 + 输出设备列表
//
// 照 ~/Documents/qsl-v-designs.html 的行式语言：
//   输出                                         ⚙
//   [◯ 🔊]  [========音量条========]           70
//   [◯ 🔊]  扬声器（USB）
//           默认设备
//   [◯ 🎧]  HECATE G1500
//           蓝牙音频
// 圆底就是静音钮（设计的 .iconc.on 状态）；设备行点选切默认。
// 主音量滑条是设计文档补的那一条（mockup 初版漏画）
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: col.implicitHeight + Size.spacing.lg * 2

    signal requestClose()

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

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Size.spacing.lg
        spacing: Size.spacing.xs

        QslSectionHeader {
            Layout.fillWidth: true
            Layout.bottomMargin: Size.spacing.xs
            title: "输出"

            QslIconButton {
                buttonSize: 26
                iconSize: Size.fontSize.md
                icon: "settings"
                onClicked: {
                    Volume.openPavucontrol()
                    root.requestClose()
                }
            }
        }

        // ---- 主音量行：圆底是静音钮，主区是滑条 ----
        QslRow {
            Layout.fillWidth: true
            visible: Volume.hasSink

            icon: Volume.sinkMuted
                ? "volume_off"
                : (Volume.isHeadphone ? "headphones" : "volume_up")
            iconActive: !Volume.sinkMuted
            iconInteractive: true
            onIconClicked: Volume.toggleSinkMute()

            contentComponent: Component {
                QslSlider {
                    value: Volume.sinkVolume
                    muted: Volume.sinkMuted
                    onMoved: (v) => Volume.setSinkVolume(v)
                }
            }

            Text {
                text: Math.round((Volume.sinkMuted ? 0 : Volume.sinkVolume) * 100)
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.sm
                color: Volume.sinkMuted ? Color.textMuted : Color.primary
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !Volume.hasSink
            text: "未找到输出设备"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Size.fontSize.sm
            color: Color.textMuted
        }

        // ---- 输出设备：点行切默认 ----
        ListView {
            id: devList
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            clip: true
            spacing: 0
            interactive: false
            reuseItems: true
            model: Volume.sinkRows

            // 设备插拔时行滑进/滑出，被顶开的行滑下去。
            // 首次填充不播，见 root.rowAnim
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
            delegate: QslRow {
                id: devRow

                required property var node

                width: devList.width
                height: implicitHeight

                readonly property bool isDefault: node === Volume.defaultSink

                icon: Volume.deviceIcon(node)
                iconActive: isDefault
                title: Volume.deviceLabel(node)
                titleAccent: isDefault
                subtitle: isDefault ? "默认设备" : Volume.deviceHint(node)
                interactive: !isDefault
                onClicked: Volume.setDefaultSink(node)

                Text {
                    visible: devRow.isDefault
                    text: "check"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.md
                    color: Color.primary
                }
            }
        }
    }
}
