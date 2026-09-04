// BtToggleCard — bluetooth 页首卡：蓝牙开关行
//
// 照 ~/Documents/qsl-v-designs.html 的行式语言：
//   [◯ 🔵]  蓝牙                        [⚙ blueman] [开关]
//           YeaArch · 可被发现
// 扫描细条 / 错误条挂在行下面，按需长出来。
// 扫描动作在「附近设备」卡的分区标题上；主设备断开在「已配对」卡的行尾
//（设计的行尾操作规则，本卡不再重复）
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

        QslRow {
            Layout.fillWidth: true

            icon: Bluetooth.enabled ? "bluetooth" : "bluetooth_disabled"
            iconActive: Bluetooth.enabled
            title: "蓝牙"
            titleAccent: Bluetooth.connectedCount > 0
            subtitle: {
                void Bluetooth.revision
                if (!Bluetooth.hasAdapter)
                    return "未找到蓝牙适配器"
                if (!Bluetooth.enabled)
                    return "已关闭"
                const parts = []
                if (Bluetooth.adapterName)
                    parts.push(Bluetooth.adapterName)
                if (Bluetooth.connectedCount > 0)
                    parts.push("已连接 " + Bluetooth.connectedCount + " 台")
                else if (Bluetooth.discoverable)
                    parts.push("可被发现")
                return parts.join(" · ")
            }

            QslIconButton {
                buttonSize: 32
                iconSize: Size.fontSize.lg
                icon: "settings"
                onClicked: {
                    Bluetooth.openBlueman()
                    root.requestClose()
                }
            }

            QslSwitch {
                sizeScale: 0.8
                checked: Bluetooth.enabled
                onToggled: (wantOn) => {
                    if (wantOn === Bluetooth.enabled)
                        return
                    Bluetooth.toggle()
                }
            }
        }

        // ---- 扫描细条 ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Bluetooth.discovering ? 3 : 0
            radius: 2
            color: Color.withAlpha(Color.primary, 0.25)
            clip: true
            opacity: Bluetooth.discovering ? 1 : 0
            Behavior on Layout.preferredHeight {
                Anim { type: Anim.SpatialFast }
            }
            Behavior on opacity { Anim { type: Anim.EffectsFast } }

            Rectangle {
                width: parent.width * 0.35
                height: parent.height
                radius: 2
                color: Color.primary
                visible: Bluetooth.discovering

                // 装饰性/刷新动画，不走令牌（plan.md 白名单）
                SequentialAnimation on x {
                    running: Bluetooth.discovering
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: -width
                        to: parent.width
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // ---- 错误条 ----
        Rectangle {
            Layout.fillWidth: true
            visible: Bluetooth.lastError !== ""
            Layout.preferredHeight: visible ? 34 : 0
            radius: Size.rounding.sm
            color: Color.withAlpha(Color.error, 0.12)
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: Size.spacing.sm

                Text {
                    text: "error"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.md
                    color: Color.error
                }
                Text {
                    Layout.fillWidth: true
                    text: Bluetooth.lastError
                    color: Color.error
                    font.pixelSize: Size.fontSize.sm
                    elide: Text.ElideRight
                }
            }
        }
    }
}
