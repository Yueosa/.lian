pragma Singleton

// ============================================================
// 网络服务 — Network
// ============================================================
// Quickshell.Networking ↔ NetworkManager
// 详情列表仅在 detailActive 时构造；关页停扫描
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: root

    property bool detailActive: false
    property var passwordNetwork: null
    property var connectTarget: null
    property string _lastError: ""
    // 强制列表绑定刷新（ObjectModel 增删时 count 会变；扫描中内容也可能原地更新）
    property int _netRev: 0
    // Quickshell 把 SSID 当 UTF-8；GBK 等会变成 U+FFFD。仅详情页按需修显示名。
    // 开销：偶发短 Process + 很小 JSON map，不常驻扫描。
    property var _ssidFix: ({})
    readonly property string _ssidFixScript:
        Quickshell.shellDir + "/scripts/wifi_ssid_fix.py"

    function _isWifiDev(d) {
        if (!d)
            return false
        // 优先枚举；再兜底用 WifiDevice 特有属性（避免 DeviceType 比较踩坑）
        if (d.type === DeviceType.Wifi || d.type === 1)
            return true
        return typeof d.scannerEnabled === "boolean"
    }

    function _isWiredDev(d) {
        if (!d)
            return false
        if (d.type === DeviceType.Wired || d.type === 2)
            return true
        return typeof d.hasLink === "boolean" || typeof d.linkSpeed === "number"
    }

    // ObjectModel 用 .values，没有 .count / .get()
    function _devices() {
        const m = Networking.devices
        return (m && m.values) ? m.values : []
    }

    function _modelItems(model) {
        if (!model)
            return []
        if (model.values)
            return model.values
        return []
    }

    readonly property var _wifiDevice: {
        void Networking.devices.values
        void _netRev
        const list = _devices()
        for (let i = 0; i < list.length; i++) {
            if (_isWifiDev(list[i]))
                return list[i]
        }
        return null
    }

    readonly property var _wiredDevice: {
        void Networking.devices.values
        void _netRev
        const list = _devices()
        for (let i = 0; i < list.length; i++) {
            if (_isWiredDev(list[i]))
                return list[i]
        }
        return null
    }

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool wifiScanning: _wifiDevice ? _wifiDevice.scannerEnabled : false
    readonly property bool hasWifiDevice: !!_wifiDevice
    readonly property string lastError: _lastError

    // 直接把 ObjectModel 交给 ListView（比每次 new Array 更跟得上 NM 更新）
    readonly property var wifiNetworksModel: {
        void _netRev
        if (!detailActive || !_wifiDevice)
            return null
        return _wifiDevice.networks
    }

    // 仍提供排序数组，供需要排序的 UI 用
    readonly property var wifiNetworks: {
        void _netRev
        const items = _modelItems(wifiNetworksModel)
        const arr = []
        for (let i = 0; i < items.length; i++) {
            if (items[i])
                arr.push(items[i])
        }
        arr.sort((a, b) => {
            if (a.connected && !b.connected)
                return -1
            if (!a.connected && b.connected)
                return 1
            return (b.signalStrength || 0) - (a.signalStrength || 0)
        })
        return arr
    }

    readonly property bool ethernetConnected: _wiredDevice ? _wiredDevice.hasLink : false
    readonly property string ethernetName: {
        if (!_wiredDevice || !_wiredDevice.network)
            return ""
        return _wiredDevice.network.name || ""
    }
    readonly property int ethernetLinkSpeed: _wiredDevice ? _wiredDevice.linkSpeed : 0

    readonly property string activeConnection: {
        if (ethernetConnected && ethernetName)
            return "ethernet"
        if (!wifiEnabled)
            return ""
        if (_wifiDevice && _wifiDevice.connected)
            return "wifi"
        return ""
    }

    function displayName(network) {
        if (!network)
            return "未知网络"
        const n = network.name || ""
        if (!n)
            return "隐藏网络"
        const fixed = _ssidFix[n]
        if (fixed)
            return fixed
        return n
    }

    function isSecure(network) {
        if (!network)
            return false
        return network.security !== WifiSecurityType.Open
            && network.security !== WifiSecurityType.Unknown
    }

    function needsPsk(network) {
        if (!network)
            return false
        const s = network.security
        return s === WifiSecurityType.WpaPsk
            || s === WifiSecurityType.Wpa2Psk
            || s === WifiSecurityType.Sae
    }

    function setDetailActive(active) {
        detailActive = !!active
        if (!detailActive) {
            stopScan()
            passwordNetwork = null
            connectTarget = null
            _ssidFix = ({})
            return
        }
        _netRev++
        if (wifiEnabled)
            scanWifi()
        _scheduleSsidFix()
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    function scanWifi() {
        if (!_wifiDevice) {
            _setError("未找到 WiFi 设备")
            _netRev++
            return
        }
        if (!wifiEnabled) {
            _setError("WiFi 已关闭")
            return
        }
        // 先关再开，强制触发一次扫描刷新
        _wifiDevice.scannerEnabled = false
        Qt.callLater(() => {
            if (root._wifiDevice && root.wifiEnabled)
                root._wifiDevice.scannerEnabled = true
            root._netRev++
            root._scheduleSsidFix()
        })
    }

    function stopScan() {
        if (_wifiDevice)
            _wifiDevice.scannerEnabled = false
    }

    function connectToWifi(network) {
        if (!network)
            return
        if (network.connected) {
            network.disconnect()
            cancelPassword()
            connectTarget = null
            return
        }
        if (passwordNetwork === network) {
            cancelPassword()
            return
        }
        cancelPassword()
        connectTarget = network
        network.connect()
    }

    function submitPassword(network, psk) {
        if (!network || !psk)
            return
        passwordNetwork = null
        connectTarget = network
        network.connectWithPsk(psk)
    }

    function cancelPassword() {
        passwordNetwork = null
    }

    function openPublicWifiPortal() {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"])
    }

    function openNmtui() {
        Quickshell.execDetached(["kitty", "-e", "nmtui"])
    }

    function _setError(message) {
        if (!message)
            return
        _lastError = message
        _errorClearTimer.restart()
    }

    // 只推列表刷新（排序 / 增删）；不牵动 SSID 修复
    function _bumpNet() {
        _netRev++
    }

    // 网络成员变化（增删）时才需要重扫 SSID 名 + 重排
    function _onNetworksChanged() {
        _netRev++
        if (detailActive)
            _scheduleSsidFix()
    }

    function _needsSsidFix() {
        const arr = wifiNetworks
        for (let i = 0; i < arr.length; i++) {
            const n = arr[i] && arr[i].name
            if (!n || n.indexOf("\uFFFD") < 0)
                continue
            if (!_ssidFix[n])
                return true
        }
        return false
    }

    function _scheduleSsidFix() {
        if (!detailActive || !_needsSsidFix())
            return
        _ssidFixDebounce.restart()
    }

    function _runSsidFix() {
        if (!detailActive || !_needsSsidFix())
            return
        if (_ssidFixProc.running)
            return
        _ssidFixProc.running = true
    }

    Timer {
        id: _ssidFixDebounce
        interval: 350
        repeat: false
        onTriggered: root._runSsidFix()
    }

    Process {
        id: _ssidFixProc
        command: ["python3", root._ssidFixScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim()
                if (!raw)
                    return
                try {
                    const map = JSON.parse(raw)
                    if (!map || typeof map !== "object")
                        return
                    // 合并，避免扫描间隙丢掉已修好的项
                    const next = Object.assign({}, root._ssidFix)
                    for (const k of Object.keys(map))
                        next[k] = map[k]
                    root._ssidFix = next
                    root._netRev++
                } catch (e) {
                }
            }
        }
    }

    Connections {
        target: root._wifiDevice
        ignoreUnknownSignals: true
        function onScannerEnabledChanged() { root._bumpNet() }
        function onConnectedChanged() { root._bumpNet() }
    }

    // 网络增删 → 重排 + 按需修 SSID 名（信号强度靠 delegate 绑 net.signalStrength 自更新）
    Connections {
        target: root._wifiDevice ? root._wifiDevice.networks : null
        ignoreUnknownSignals: true
        function onValuesChanged() { root._onNetworksChanged() }
    }

    Connections {
        target: Networking.devices
        ignoreUnknownSignals: true
        function onValuesChanged() { root._onNetworksChanged() }
    }

    // 慢速重排：仅扫描进行中且开着页面时跑；信号强度本身是响应式，
    // 这里只为偶尔按新强度重新排序，5s 一次足够，扫描停即停。
    Timer {
        interval: 5000
        running: root.detailActive && root.wifiScanning
        repeat: true
        onTriggered: root._bumpNet()
    }

    Connections {
        target: root.connectTarget
        ignoreUnknownSignals: true

        function onConnectionFailed(reason) {
            if (!root.connectTarget)
                return
            if (reason === ConnectionFailReason.NoSecrets) {
                root.passwordNetwork = root.connectTarget
                return
            }
            const name = root.connectTarget.name || "网络"
            root._setError("连接失败: " + name)
            root.connectTarget = null
        }

        function onConnectedChanged() {
            if (root.connectTarget && root.connectTarget.connected) {
                root.connectTarget = null
                root.passwordNetwork = null
                root._bumpNet()
            }
        }
    }

    Timer {
        id: _errorClearTimer
        interval: 5000
        repeat: false
        onTriggered: _lastError = ""
    }
}
