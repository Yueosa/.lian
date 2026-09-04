// BtListCard — bluetooth 页设备列表卡：已配对（mode:"paired"）/ 附近设备（mode:"nearby"）
//
// 照 ~/Documents/qsl-v-designs.html 的行式语言：
//   已配对                                        2
//   [◯ 🎧]  HECATE G1500                    [断开]
//           已连接 · 电量 80%
//   附近设备                              ⟳ 扫描中…
//   [◯ 🔉]  小米音箱                        [配对]
// 「已连接」并进已配对卡（连接态体现在副标题和行尾操作上，不单开一节）。
// 忘记 = 行内二次确认，不再弹对话框
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
// 模型是 Bluetooth 的增量 ListModel，新扫到的设备才有 add/displaced 过渡可播

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

    // "paired"（已配对，含已连接）| "nearby"（附近设备）
    property string mode: "nearby"

    // 指向 Rightbar.btState（forgetTarget：行内遗忘确认跨卡共用）
    property QtObject sharedState

    readonly property bool isNearby: mode === "nearby"
    readonly property var rowModel: isNearby
        ? Bluetooth.nearbyRows
        : Bluetooth.pairedRows

    // 蓝牙关 / 无适配器时整卡不占位（状态由首卡承担）；
    // 已配对卡再加一条：没有配对过的设备就别占地方
    readonly property bool hasContent: Bluetooth.hasAdapter && Bluetooth.enabled
        && (isNearby || rowModel.count > 0)

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

        title: root.isNearby ? "附近设备" : "已配对"
        note: root.isNearby ? "" : String(root.rowModel.count)
        // 扫描态并进动作标签，不另开 note
        action: root.isNearby
            ? (Bluetooth.discovering ? "扫描中…" : "扫描")
            : ""
        actionIcon: root.isNearby ? "refresh" : ""
        actionBusy: Bluetooth.discovering
        actionEnabled: Bluetooth.enabled
        onActionClicked: Bluetooth.toggleScan()
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

        // 列表自适应内容：附近设备卡留空态文案的位置，上限后滚动
        implicitHeight: Math.max(root.isNearby ? 64 : 0,
                                 Math.min(360, deviceList.contentHeight))

        ListView {
            id: deviceList
            anchors.fill: parent
            clip: true
            spacing: 2
            reuseItems: true
            model: root.rowModel
            boundsBehavior: Flickable.StopAtBounds

            // 新行滑出来（从 rail 那侧进），被顶开的行滑下去。
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
            move: Transition {
                enabled: root.rowAnim
                Anim { properties: "x,y"; type: Anim.SpatialFast }
            }

            // ---- 空态：只在附近设备卡出现 ----
            Text {
                anchors.centerIn: parent
                visible: root.isNearby && deviceList.count === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Bluetooth.discovering ? "正在扫描…" : "附近没有设备"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.sm
            }

            delegate: QslRow {
                id: row

                required property var device

                width: deviceList.width
                height: implicitHeight

                readonly property string section: Bluetooth.sectionOf(device)
                readonly property bool connected: Bluetooth.isConnected(device)
                readonly property bool busy: Bluetooth.isBusy(device)
                readonly property bool askingForget:
                    root.sharedState.forgetTarget === device

                icon: Bluetooth.deviceIcon(device)
                iconActive: row.connected
                title: Bluetooth.displayName(device)
                titleAccent: row.connected
                subtitle: Bluetooth.statusHint(device, row.section)

                // 点行 = 主操作（连接 / 断开 / 配对）
                interactive: !!device && !row.busy
                onClicked: {
                    root.sharedState.forgetTarget = null
                    if (row.section === "connected")
                        Bluetooth.disconnectDevice(device)
                    else if (row.section === "paired")
                        Bluetooth.connectDevice(device)
                    else
                        Bluetooth.pairDevice(device)
                }

                expanded: row.askingForget
                expandComponent: forgetComp

                // ---- 尾部：主操作 + 忘记（已配对才有）----
                Text {
                    visible: row.busy
                    text: "sync"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.md
                    color: Color.primary

                    // 装饰性/刷新动画，不走令牌（plan.md 白名单）
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: row.busy
                    }
                }

                QslActionChip {
                    visible: !row.busy
                    text: {
                        if (row.section === "connected")
                            return "断开"
                        if (row.section === "paired")
                            return "连接"
                        return "配对"
                    }
                    filled: row.section !== "connected"
                    onClicked: {
                        root.sharedState.forgetTarget = null
                        if (row.section === "connected")
                            Bluetooth.disconnectDevice(row.device)
                        else if (row.section === "paired")
                            Bluetooth.connectDevice(row.device)
                        else
                            Bluetooth.pairDevice(row.device)
                    }
                }

                QslActionChip {
                    visible: !root.isNearby && !row.busy
                    text: "忘记"
                    accent: Color.error
                    onClicked: {
                        root.sharedState.forgetTarget =
                            row.askingForget ? null : row.device
                    }
                }

                // ---- 行内展开：忘记二次确认 ----
                Component {
                    id: forgetComp

                    RowLayout {
                        spacing: Size.spacing.sm

                        Text {
                            Layout.fillWidth: true
                            text: "忘记此设备？"
                            color: Color.textMuted
                            font.pixelSize: Size.fontSize.xsm
                        }
                        QslActionChip {
                            text: "取消"
                            onClicked: root.sharedState.forgetTarget = null
                        }
                        QslActionChip {
                            text: "忘记"
                            accent: Color.error
                            filled: true
                            onClicked: {
                                Bluetooth.forgetDevice(row.device)
                                root.sharedState.forgetTarget = null
                            }
                        }
                    }
                }
            }
        }
    }
}
