// NetListCard — network 页列表卡：可用网络（section:"nearby"）/ 已保存（section:"saved"）
//
// 照 ~/Documents/qsl-v-designs.html 的行式语言：
//   可用网络                                  ⟳ 扫描
//   [◯ 📶]  2103                        ▂▄▆█  🔒
//   已保存                                     3 个
//   2103                                        忘记
// 可用网络行带圆形图标底 + 信号格 + 锁；已保存行不要图标（设计如此），
// 尾部放「忘记」。点行 = 连接，需要密码就行内展开密码框，破坏性操作
// 行内二次确认——不再有独立对话框。
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
// 模型是 Network 的增量 ListModel，新 SSID 才有 add/displaced 过渡可播

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

    // "nearby"（可用网络）| "saved"（已保存）
    property string section: "nearby"

    // 指向 Rightbar.netState（forgetTarget：与首卡共用）
    property QtObject sharedState

    readonly property bool isSaved: section === "saved"
    readonly property var rowModel: isSaved ? Network.savedRows : Network.nearbyRows

    // 占位规则：Wi‑Fi 关 / 没有 Wi‑Fi 设备时两张卡都不占位——原因首卡的
    // WLAN 行已经讲清楚了，底下再摆两张空卡只是占地方。
    // Wi‑Fi 开着时可用网络卡留着：「正在扫描…」「附近没有网络」是有信息的
    // 空态，让卡晚一步再冒出来反而更晃。已保存卡是没有就收起
    readonly property bool hasContent: Network.wifiEnabled && Network.hasWifiDevice
        && (!isSaved || rowModel.count > 0)

    // 首次填充不播行动画：那一拍容器自己的派生动画正在跑，再叠 N 行滑入
    // 既打架又费帧。一次性，触发完自己停
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

        title: root.isSaved ? "已保存" : "可用网络"
        note: root.isSaved ? (root.rowModel.count + " 个") : ""
        // 扫描态并进动作标签，不再另开一条 note（否则和动作挤在一起）
        action: root.isSaved ? "" : (Network.wifiScanning ? "扫描中…" : "扫描")
        actionIcon: root.isSaved ? "" : "refresh"
        actionBusy: Network.wifiScanning
        actionEnabled: Network.wifiEnabled
        onActionClicked: Network.scanWifi()
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

        // 列表自适应内容：可用网络卡留空态文案的位置，上限后滚动
        implicitHeight: Math.max(root.isSaved ? 0 : 64,
                                 Math.min(360, wifiList.contentHeight))

        ListView {
            id: wifiList
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

            // ---- 空态：只在可用网络卡出现 ----
            Text {
                anchors.centerIn: parent
                visible: !root.isSaved && wifiList.count === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: {
                    if (!Network.wifiEnabled)
                        return "Wi‑Fi 已关闭"
                    if (!Network.hasWifiDevice)
                        return "未找到 Wi‑Fi 设备"
                    return Network.wifiScanning ? "正在扫描…" : "附近没有网络"
                }
                color: Color.textMuted
                font.pixelSize: Size.fontSize.sm
            }

            delegate: QslRow {
                id: row

                required property var network

                width: wifiList.width
                height: implicitHeight

                readonly property bool secure: Network.isSecure(network)
                readonly property bool asking: Network.passwordNetwork === network
                readonly property bool connecting: Network.connectTarget === network
                readonly property bool askingForget:
                    root.sharedState.forgetTarget === network

                // 已保存行不要图标（设计如此），可用网络行要圆形图标底
                icon: root.isSaved ? "" : "wifi"
                title: {
                    void Network.revision
                    return Network.displayName(network)
                }
                subtitle: {
                    if (row.connecting)
                        return "连接中…"
                    if (row.asking)
                        return Network.passwordHint || "输入密码"
                    return ""
                }
                interactive: !row.asking && !row.connecting
                onClicked: {
                    root.sharedState.forgetTarget = null
                    Network.connectToWifi(network)
                }

                expanded: row.asking || row.askingForget
                expandComponent: row.asking ? passComp : forgetComp

                // ---- 尾部：信号格 + 锁（可用网络）/ 忘记（已保存）----
                Row {
                    spacing: 2
                    visible: !root.isSaved
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            width: 3
                            height: 4 + index * 3
                            y: 13 - height
                            radius: 1
                            color: index < Network.signalBars(row.network)
                                ? Color.primary
                                : Color.withAlpha(Color.text, 0.18)
                            Behavior on color { CAnim {} }
                        }
                    }
                }

                Text {
                    visible: row.secure && !root.isSaved
                    text: "lock"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.md
                    color: Color.textMuted
                }

                Text {
                    visible: row.connecting
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
                        running: row.connecting
                    }
                }

                Rectangle {
                    visible: root.isSaved && !row.asking
                    implicitWidth: forgetLbl.implicitWidth + Size.spacing.md
                    implicitHeight: 24
                    radius: Size.rounding.full
                    color: forgetMa.containsMouse
                        ? Color.withAlpha(Color.error, 0.18)
                        : "transparent"
                    Behavior on color { CAnim {} }

                    Text {
                        id: forgetLbl
                        anchors.centerIn: parent
                        text: "忘记"
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.error
                    }
                    MouseArea {
                        id: forgetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.sharedState.forgetTarget =
                                row.askingForget ? null : row.network
                        }
                    }
                }

                // ---- 行内展开：密码框 ----
                Component {
                    id: passComp

                    ColumnLayout {
                        spacing: Size.spacing.sm

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: Size.rounding.md
                            color: Color.withAlpha(Color.surface, 0.9)
                            border.width: passInput.activeFocus ? 2 : 1
                            border.color: passInput.activeFocus
                                ? Color.primary
                                : Color.outlineVariant
                            Behavior on border.color { CAnim {} }

                            TextInput {
                                id: passInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                color: Color.text
                                selectedTextColor: Color.primaryText
                                selectionColor: Color.primary
                                font.pixelSize: Size.fontSize.sm
                                clip: true
                                inputMethodHints: Qt.ImhSensitiveData
                                onAccepted: Network.submitPassword(row.network, text)

                                Component.onCompleted: Qt.callLater(() => passInput.forceActiveFocus())

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: Network.passwordHint || "密码"
                                    color: Color.outline
                                    font.pixelSize: Size.fontSize.sm
                                    visible: !passInput.text && !passInput.activeFocus
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Size.spacing.sm

                            // 改密场景：密码框旁也可遗忘
                            QslActionChip {
                                visible: Network.isKnown(row.network)
                                text: "忘记"
                                accent: Color.error
                                onClicked: {
                                    Network.forgetNetwork(row.network)
                                    root.sharedState.forgetTarget = null
                                }
                            }

                            Item { Layout.fillWidth: true }

                            QslActionChip {
                                text: "取消"
                                onClicked: {
                                    passInput.text = ""
                                    Network.cancelPassword()
                                }
                            }

                            QslActionChip {
                                text: "连接"
                                filled: true
                                onClicked: Network.submitPassword(row.network, passInput.text)
                            }
                        }
                    }
                }

                // ---- 行内展开：忘记二次确认 ----
                Component {
                    id: forgetComp

                    RowLayout {
                        spacing: Size.spacing.sm

                        Text {
                            Layout.fillWidth: true
                            text: "忘记此网络？"
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
                                Network.forgetNetwork(row.network)
                                root.sharedState.forgetTarget = null
                            }
                        }
                    }
                }
            }
        }
    }
}
