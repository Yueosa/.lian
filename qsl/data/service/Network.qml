pragma Singleton

// ============================================================
// 网络服务 — Network
// ============================================================
// 通过 Quickshell.Networking 原生绑定与 NetworkManager D-Bus 通信。
// 提供 WiFi / 以太网的状态、扫描、连接、密码认证。
// ============================================================
// 对外接口一览：
//
// 属性（readonly）：
//   wifiEnabled          bool       WiFi 是否开启（硬件+软件）
//   wifiHardwareEnabled  bool       硬件开关状态
//   wifiScanning         bool       是否正在扫描网络
//   wifiNetworks         model      可用 WiFi 网络列表（已排序：已连接 > 信号强）
//   ethernetConnected    bool       以太网是否连接
//   ethernetName         string     以太网连接名（空 = 未连接）
//   ethernetLinkSpeed    int        以太网链路速率（Mbps）
//   activeConnection     string     当前连接类型："wifi" / "ethernet" / ""
//   lastError            string     最近错误信息（5 秒自动清）
//
// 方法：
//   toggleWifi()                    切换 WiFi 开关
//   scanWifi()                      重新扫描网络
//   connectToWifi(network)          连接指定 WiFi（已知密码自动连）
//   connectWithPassword(network, psk) 带密码连接
//   disconnectWifi()                断开当前 WiFi
//   openPublicWifiPortal()          打开强制门户网页
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    // ============================================================
    // 设备发现
    //    从 Networking.devices 中找到 WiFi 和以太网设备
    // ============================================================

    readonly property var _wifiDevice: {
        for (let i = 0; i < Networking.devices.count; i++) {
            const d = Networking.devices.get(i)
            if (d && d.type === Networking.WifiDevice) return d
        }
        return null
    }

    readonly property var _wiredDevice: {
        for (let i = 0; i < Networking.devices.count; i++) {
            const d = Networking.devices.get(i)
            if (d && d.type === Networking.WiredDevice) return d
        }
        return null
    }

    // ============================================================
    // WiFi 状态
    // ============================================================

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool wifiScanning: _wifiDevice ? _wifiDevice.scannerEnabled : false
    readonly property string lastError: _lastError

    property string _lastError: ""

    // 已排序的 WiFi 网络列表：已连接优先，然后按信号强度降序
    readonly property var wifiNetworks: {
        if (!_wifiDevice || !_wifiDevice.networks) return []
        const arr = []
        for (let i = 0; i < _wifiDevice.networks.count; i++) {
            arr.push(_wifiDevice.networks.get(i))
        }
        arr.sort((a, b) => {
            if (a.connected && !b.connected) return -1
            if (!a.connected && b.connected) return 1
            return b.signalStrength - a.signalStrength
        })
        return arr
    }

    // ============================================================
    // 以太网状态
    // ============================================================

    readonly property bool ethernetConnected: _wiredDevice ? _wiredDevice.hasLink : false
    readonly property string ethernetName: {
        if (!_wiredDevice || !_wiredDevice.network) return ""
        return _wiredDevice.network.name || ""
    }
    readonly property int ethernetLinkSpeed: _wiredDevice ? _wiredDevice.linkSpeed : 0

    // ============================================================
    // 综合状态
    // ============================================================

    readonly property string activeConnection: {
        if (ethernetConnected && ethernetName) return "ethernet"
        if (wifiEnabled) {
            for (let i = 0; i < wifiNetworks.length; i++) {
                if (wifiNetworks[i].connected) return "wifi"
            }
        }
        return ""
    }

    // ============================================================
    // WiFi 操作
    // ============================================================

    function toggleWifi() {
        if (wifiEnabled)
            Networking.wifiEnabled = false
        else
            Networking.wifiEnabled = true
    }

    function scanWifi() {
        if (_wifiDevice && wifiEnabled)
            _wifiDevice.scannerEnabled = true
    }

    function connectToWifi(network) {
        if (!network) return
        // 已连接 → 断开
        if (network.connected) {
            disconnectWifi()
            return
        }
        // 已知网络 → 尝试直接连接
        if (network.known) {
            network.connectWithPsk("")
            return
        }
        // 开放网络 → 直接连接
        if (network.security === 0) {
            network.connectWithPsk("")
            return
        }
        // 加密网络 → 需要密码，UI 应弹出密码输入框
        // WifiNetwork 有 requestConnectWithPsk 信号可以监听
    }

    function connectWithPassword(network, psk) {
        if (!network) return
        network.connectWithPsk(psk)
    }

    function disconnectWifi() {
        if (!_wifiDevice) return
        const arr = []
        for (let i = 0; i < _wifiDevice.networks.count; i++) {
            arr.push(_wifiDevice.networks.get(i))
        }
        for (const n of arr) {
            if (n.connected && n.known) {
                // NetworkManager 原生断开方式
                n.connectWithPsk("") // 传空 PSK 触发断开
                return
            }
        }
    }

    function openPublicWifiPortal() {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"])
    }

    function _setError(message) {
        if (!message) return
        _lastError = message
        _errorClearTimer.restart()
    }

    Timer {
        id: _errorClearTimer
        interval: 5000
        repeat: false
        onTriggered: _lastError = ""
    }
}
