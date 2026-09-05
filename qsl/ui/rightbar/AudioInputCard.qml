// AudioInputCard — audio 页输入卡：输入主音量 + 输入设备列表
//
// 照 ~/Documents/qsl-v-designs.html 的行式语言：
//   输入
//   [◯ 🎙️]  [========音量条========]           70
//   [◯ 🎙️]  G1500 麦克风
//            默认设备
// 结构与输出卡对称。设计的 mockup 里输入卡只画了设备行没画滑条，
// 但麦克风音量/静音是常用操作，跟着输出卡一起保留
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

    // RailPage 的容器占位协议：无输入设备时整卡不占位
    readonly property bool hasContent: Volume.hasSource

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
            title: "输入"
        }

        // ---- 主音量行：圆底是静音钮，主区是滑条 ----
        QslRow {
            Layout.fillWidth: true
            visible: Volume.hasSource

            icon: Volume.sourceMuted ? "mic_off" : "mic"
            iconActive: !Volume.sourceMuted
            iconInteractive: true
            onIconClicked: Volume.toggleSourceMute()

            contentComponent: Component {
                QslSlider {
                    value: Volume.sourceVolume
                    muted: Volume.sourceMuted
                    onMoved: (v) => Volume.setSourceVolume(v)
                }
            }

            Text {
                text: Math.round((Volume.sourceMuted ? 0 : Volume.sourceVolume) * 100)
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.sm
                color: Volume.sourceMuted ? Color.textMuted : Color.primary
            }
        }

        // ---- 输入设备：点行切默认 ----
        ListView {
            id: devList
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            clip: true
            spacing: 0
            interactive: false
            reuseItems: true
            model: Volume.sourceRows

            // **不要 add / remove**：那两条动的是透明度，被打断就冻在中途不回来
            // ——屏幕上是一行半透明的东西叠在别的行上，滚两下才消失。delegate 根
            // QslRow 上还挂着 Behavior on opacity，和过渡抢同一个属性，更容易断。
            // 完整证据见 ui/clipboard/ClipCard.qml 同一处。
            // 位置类的 displaced/move 留着：打断了下一次布局会自己纠正
            // 首次填充不播，见 root.rowAnim
            displaced: Transition {
                enabled: root.rowAnim
                Anim { properties: "x,y"; type: Anim.SpatialFast }
            }
            delegate: QslRow {
                id: devRow

                required property var node

                width: devList.width
                height: implicitHeight

                readonly property bool isDefault: node === Volume.defaultSource

                icon: Volume.deviceIcon(node)
                iconActive: isDefault
                title: Volume.deviceLabel(node)
                titleAccent: isDefault
                subtitle: isDefault ? "默认设备" : Volume.deviceHint(node)
                interactive: !isDefault
                onClicked: Volume.setDefaultSource(node)

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
