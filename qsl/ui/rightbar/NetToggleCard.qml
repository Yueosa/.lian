// NetToggleCard — network 页首卡：Wi‑Fi 行 + 当前连接行
//
// 照 ~/Documents/qsl-v-designs.html 的行式语言：
//   [◯ 信号]  WLAN                    [nmtui] [⟳] [开关]
//             已连接 · 2103
//   [◯ 🌐]   192.168.1.15             ↓9.7K ↑7.8K   [断开]
//             enp4s0 · 信号 62%
// 门户按钮 / 扫描细条 / 错误条挂在两行下面，按需长出来。
// 「忘记当前网络」不在本卡：已保存卡每行自带忘记（设计的行尾操作规则）
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

    // 指向 Rightbar.netState（forgetTarget：与列表卡共用）
    property QtObject sharedState

    signal requestClose()

    function strengthIcon(strength) {
        const s = strength || 0
        if (s > 0.8)
            return "signal_wifi_4_bar"
        if (s > 0.6)
            return "network_wifi_3_bar"
        if (s > 0.4)
            return "network_wifi_2_bar"
        if (s > 0.2)
            return "network_wifi_1_bar"
        return "signal_wifi_0_bar"
    }

    readonly property bool anyConnected: Network.ethernetConnected || Network.wifiConnected

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

        // ---- Wi‑Fi 行 ----
        QslRow {
            Layout.fillWidth: true

            icon: Network.wifiEnabled
                ? (Network.wifiConnected
                    ? root.strengthIcon(Network.wifiSignalStrength)
                    : "wifi")
                : "wifi_off"
            iconActive: Network.wifiConnected
            title: "WLAN"
            titleAccent: Network.wifiConnected
            subtitle: {
                void Network.revision
                if (!Network.hasWifiDevice)
                    return "未找到 Wi‑Fi 设备"
                if (!Network.wifiEnabled)
                    return "已关闭"
                if (Network.wifiConnected) {
                    const nm = Network.activeWifiName
                    return "已连接" + (nm ? " · " + nm : "")
                }
                return Network.wifiScanning ? "扫描中…" : "未连接"
            }

            QslIconButton {
                buttonSize: 32
                iconSize: Size.iconSize.lg
                icon: "settings"
                onClicked: {
                    Network.openNmtui()
                    root.requestClose()
                }
            }

            QslIconButton {
                buttonSize: 32
                iconSize: Size.iconSize.lg
                icon: "refresh"
                busy: Network.wifiScanning
                enabled: Network.wifiEnabled
                onClicked: Network.scanWifi()
            }

            QslSwitch {
                sizeScale: 0.8
                checked: Network.wifiEnabled
                onToggled: (wantOn) => {
                    if (wantOn === Network.wifiEnabled)
                        return
                    // 开起来后的自动扫描由 Network.onWifiEnabledChanged 管：
                    // 这一拍 rfkill 还没放开，自己扫只会报假错
                    Network.toggleWifi()
                }
            }
        }

        // ---- 当前连接行：IP / 接口 / 速率 ----
        // 速率借 Sysmon 的 snap（顶栏摘要一直在看，所以是免费的）
        QslRow {
            Layout.fillWidth: true
            visible: root.anyConnected

            icon: "language"
            title: Network.activeIp || "获取 IP…"
            titleMono: Network.activeIp !== ""
            subtitle: {
                void Network.revision
                const parts = []
                if (Network.activeIface)
                    parts.push(Network.activeIface)
                if (Network.ethernetConnected) {
                    if (Network.ethernetLinkSpeed > 0)
                        parts.push(Network.ethernetLinkSpeed + " Mbps")
                } else if (Network.wifiSignalStrength > 0) {
                    parts.push("信号 " + Math.round(Network.wifiSignalStrength * 100) + "%")
                }
                if (Network.connectivityLabel)
                    parts.push(Network.connectivityLabel)
                return parts.join(" · ")
            }

            // 下行/上行分色，扫一眼就知道哪个方向在跑；两个色都取自主题
            Row {
                spacing: Size.spacing.sm

                Text {
                    text: "↓" + Sysmon.formatBytes(Sysmon.netDownBps)
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.labelSmall
                    color: Color.primary
                }
                Text {
                    text: "↑" + Sysmon.formatBytes(Sysmon.netUpBps)
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.labelSmall
                    color: Color.tertiary
                }
            }

            QslIconButton {
                buttonSize: 32
                iconSize: Size.iconSize.lg
                icon: "link_off"
                visible: Network.wifiConnected && !Network.ethernetConnected
                onClicked: Network.disconnectActiveWifi()
            }
        }

        // ---- 门户登录：需要时才长出来 ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 34 : 0
            visible: Network.captivePortal
                && Network.wifiConnected
                && !Network.ethernetConnected
            radius: Size.rounding.full
            // 静息就带底色——这条只在需要登录时长出来，本身就是在喊人点它
            color: Color.primaryContainer
            Behavior on color { CAnim {} }

            QslStateLayer {
                source: portalMa
                tint: Color.primaryContainerText
                accent: true
            }

            Text {
                anchors.centerIn: parent
                text: "打开网络门户"
                font.pixelSize: Size.fontSize.labelMedium
                font.bold: true
                color: Color.primaryContainerText
            }
            MouseArea {
                id: portalMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Network.openPublicWifiPortal()
            }
        }

        // ---- 扫描细条 ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Network.wifiScanning ? 3 : 0
            radius: 2
            color: Color.primaryContainer
            clip: true
            opacity: Network.wifiScanning ? 1 : 0
            Behavior on Layout.preferredHeight {
                Anim { type: Anim.SpatialFast }
            }
            Behavior on opacity { Anim { type: Anim.EffectsFast } }

            Rectangle {
                width: parent.width * 0.35
                height: parent.height
                radius: 2
                color: Color.primary
                visible: Network.wifiScanning

                // 装饰性/刷新动画，不走令牌（plan.md 白名单）
                SequentialAnimation on x {
                    running: Network.wifiScanning
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
            visible: Network.lastError !== ""
            Layout.preferredHeight: visible ? 34 : 0
            radius: Size.rounding.sm
            color: Color.errorContainer
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: Size.spacing.sm

                Text {
                    text: "error"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.iconSize.md
                    color: Color.errorContainerText
                }
                Text {
                    Layout.fillWidth: true
                    text: Network.lastError
                    color: Color.errorContainerText
                    font.pixelSize: Size.fontSize.bodySmall
                    elide: Text.ElideRight
                }
            }
        }
    }
}
