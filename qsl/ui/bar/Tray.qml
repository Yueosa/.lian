// Tray — 芯片式托盘：pin 常驻 + 悬停横向展开 overflow
// 学 AudioChip/SysMonitor 的悬停横展语言：无展开按钮、无 overflow 弹窗、
// 无全屏输入捕获，点击行为全在图标上
// 展开状态 = 悬停 || 有菜单开着：菜单打开期间保持展开，
//   否则鼠标移向菜单 → 折叠 → 图标 Loader 销毁 → 菜单跟着死
// overflow 整组一个宽度动画：N 个槽位各自动画 + chip 再追 = 多点过冲互相打架（抖动）
// chip 宽度直绑内容：平滑由组的动画提供，自己不加 Behavior（双重动画会滞后）
// 栏上 / overflow：Loader.active 才建 TrayItem+Image，未 pin 且未展开不占解码缓存

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.data.service

Item {
    id: root

    property var screen: null

    // overflow 里有几个菜单开着
    property int openMenuCount: 0

    function noteMenu(open) {
        openMenuCount = Math.max(0, openMenuCount + (open ? 1 : -1))
    }

    // 悬停意图：进入即锁存展开；菜单开着时 collapse 无效（保菜单命）
    property bool expanded: false

    readonly property bool hovered: hoverMa.containsMouse

    function collapse() {
        if (openMenuCount === 0)
            expanded = false
    }

    // 空托盘时整个 chip 消失。不要拿 TrayService.items.count 做判空——
    // 它是 SNI 的对象模型，没有 count 属性，判空失败会把 chip 宽度压成 0，
    // 内容左溢盖住旁边的 chip（曾经整排盖住 BT/音频/设置）
    implicitHeight: 36
    implicitWidth: content.implicitWidth > 0 ? content.implicitWidth + 16 : 0

    function relayoutBar() {
        if (content.forceLayout)
            content.forceLayout()
    }

    function onTrayPinChanged() {
        root.relayoutBar()
    }

    Component {
        id: trayItemComp
        TrayItem {
            // modelData / 信号在 Loader.onLoaded 注入
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Color.background
        radius: height / 2
    }

    RowLayout {
        id: content
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: Size.spacing.sm

        // overflow 组：expanded 时整组展开； pinned 图标钉在右端不动，
        // 组收窄时图标从左边被裁掉
        Item {
            id: overflowGroup

            // 动画驱动进度再取整：分数宽度会让 20px 栅格图标逐帧
            // 重采样（图标边缘爬行=抖），取整后整条链路坐标都是整数
            property real reveal: root.expanded ? 1 : 0

            Behavior on reveal {
                Anim { type: Anim.SpatialFast }
            }

            Layout.preferredWidth: Math.round(overflowRow.implicitWidth * overflowGroup.reveal)
            Layout.preferredHeight: 20
            opacity: root.expanded ? 1 : 0
            clip: true

            Behavior on opacity {
                Anim { type: Anim.EffectsFast }
            }

            Row {
                id: overflowRow
                anchors.right: parent.right
                height: 20
                spacing: Size.spacing.sm

                Repeater {
                    model: TrayService.items

                    delegate: Item {
                        id: ovSlot
                        required property var modelData

                        property bool show: false

                        function syncShow() {
                            ovSlot.show = TrayService.inOverflow(ovSlot.modelData)
                        }

                        Component.onCompleted: syncShow()
                        Connections {
                            target: TrayService
                            function onPinSignatureChanged() { ovSlot.syncShow() }
                            function onRevisionChanged() { ovSlot.syncShow() }
                        }

                        visible: show
                        width: show ? 20 : 0
                        height: 20
                        clip: true

                        Loader {
                            id: ovLoader
                            anchors.fill: parent
                            active: ovSlot.show && root.expanded
                            sourceComponent: trayItemComp
                            onLoaded: {
                                item.modelData = ovSlot.modelData
                                item.pinChanged.connect(root.onTrayPinChanged)
                                item.menuToggled.connect(root.noteMenu)
                            }
                        }

                        Binding {
                            when: ovLoader.status === Loader.Ready && !!ovLoader.item
                            target: ovLoader.item
                            property: "modelData"
                            value: ovSlot.modelData
                        }
                    }
                }
            }
        }

        // pin 常驻图标
        Repeater {
            model: TrayService.items

            delegate: Item {
                id: barSlot
                required property var modelData

                property bool show: false

                function syncShow() {
                    barSlot.show = TrayService.isPinned(barSlot.modelData)
                }

                Component.onCompleted: syncShow()
                Connections {
                    target: TrayService
                    function onPinSignatureChanged() { barSlot.syncShow() }
                    function onRevisionChanged() { barSlot.syncShow() }
                }

                visible: show
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: show ? 20 : 0
                Layout.preferredHeight: show ? 20 : 0
                Layout.maximumWidth: show ? 20 : 0
                implicitWidth: show ? 20 : 0
                implicitHeight: show ? 20 : 0
                width: show ? 20 : 0
                height: show ? 20 : 0
                clip: true

                // 未 pin：active=false，不建 Image / TrayMenu
                Loader {
                    id: barLoader
                    anchors.fill: parent
                    active: barSlot.show
                    sourceComponent: trayItemComp
                    onLoaded: {
                        item.modelData = barSlot.modelData
                        item.pinChanged.connect(root.onTrayPinChanged)
                    }
                }

                Binding {
                    when: barLoader.status === Loader.Ready && !!barLoader.item
                    target: barLoader.item
                    property: "modelData"
                    value: barSlot.modelData
                }
            }
        }
    }

    // 只感应悬停，点击穿透给图标
    MouseArea {
        id: hoverMa
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: {
            if (containsMouse)
                root.expanded = true
        }
    }

    Connections {
        target: TrayService
        function onPinSignatureChanged() {
            root.relayoutBar()
        }
    }
}
