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
    // 密码框提示：需要密码 / 密码错误（改密常见）
    property string passwordHint: ""
    property string _lastError: ""
    // 本次 connect 是否走了 connectWithPsk（区分「要密码」与「密码错」）
    property bool _connectWithPsk: false
    property bool _stateWasChanging: false
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

    // Bar 芯片用：不依赖 detailActive / 扫描
    readonly property bool wifiConnected: !!(wifiEnabled && _wifiDevice && _wifiDevice.connected)

    readonly property var _activeWifiNetwork: {
        void Networking.devices.values
        void _netRev
        if (!_wifiDevice || !_wifiDevice.connected)
            return null
        const items = _modelItems(_wifiDevice.networks)
        for (let i = 0; i < items.length; i++) {
            if (items[i] && items[i].connected)
                return items[i]
        }
        return null
    }

    readonly property int wifiSignalStrength: {
        const n = _activeWifiNetwork
        return n ? (n.signalStrength || 0) : 0
    }

    // Bar 悬停文案
    readonly property string chipLabel: {
        if (ethernetConnected)
            return ethernetName || "以太网"
        if (!wifiEnabled)
            return "已关闭"
        if (wifiConnected) {
            const n = _activeWifiNetwork
            return n ? displayName(n) : "已连接"
        }
        return "未连接"
    }

    readonly property string chipIcon: {
        if (ethernetConnected)
            return "settings_ethernet"
        if (!wifiEnabled || !wifiConnected)
            return "wifi_off"
        const s = wifiSignalStrength
        if (s >= 75)
            return "wifi"
        if (s >= 40)
            return "network_wifi_3_bar"
        return "network_wifi_1_bar"
    }

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

    // 连通性（NM connectivity check；未启用时多为 Unknown）
    readonly property bool internetAvailable:
        Networking.connectivity === NetworkConnectivity.Full
    readonly property bool captivePortal:
        Networking.connectivity === NetworkConnectivity.Portal
    readonly property bool limitedConnectivity:
        Networking.connectivity === NetworkConnectivity.Limited

    readonly property string connectivityLabel: {
        const c = Networking.connectivity
        if (c === NetworkConnectivity.Full)
            return "已联网"
        if (c === NetworkConnectivity.Portal)
            return "需门户登录"
        if (c === NetworkConnectivity.Limited)
            return "受限连接"
        if (c === NetworkConnectivity.None)
            return "无网络"
        return ""
    }

    // 摘要卡主标题 / 副标题（详情页用；不建大对象）
    readonly property string summaryTitle: {
        void _netRev
        if (ethernetConnected)
            return ethernetName || "以太网"
        if (!wifiEnabled)
            return "Wi‑Fi 已关闭"
        if (wifiConnected) {
            const n = _activeWifiNetwork
            return n ? displayName(n) : "已连接"
        }
        if (!hasWifiDevice)
            return "未找到 Wi‑Fi 设备"
        return "未连接"
    }

    readonly property string summarySubtitle: {
        void _netRev
        if (ethernetConnected) {
            const parts = []
            if (ethernetLinkSpeed > 0)
                parts.push(ethernetLinkSpeed + " Mbps")
            if (connectivityLabel)
                parts.push(connectivityLabel)
            return parts.length ? parts.join(" · ") : "有线已连接"
        }
        if (!wifiEnabled)
            return "打开开关以扫描附近网络"
        if (wifiConnected) {
            const parts = []
            const s = wifiSignalStrength
            if (s > 0)
                parts.push("信号 " + Math.round(s * 100) + "%")
            if (connectivityLabel)
                parts.push(connectivityLabel)
            return parts.length ? parts.join(" · ") : "无线已连接"
        }
        if (wifiScanning)
            return "正在扫描附近网络…"
        return "选择下方网络以连接"
    }

    // 列表扁平行：已保存 / 附近（当前已连的放摘要卡，列表里排除以免重复）
    // 开销：仅 detailActive 时构数组；条目数 = 扫描结果量级
    readonly property var wifiFlatRows: {
        void _netRev
        if (!detailActive || !wifiEnabled || !_wifiDevice)
            return []
        const items = wifiNetworks
        const saved = []
        const nearby = []
        for (let i = 0; i < items.length; i++) {
            const n = items[i]
            if (!n || n.connected)
                continue
            if (n.known)
                saved.push(n)
            else
                nearby.push(n)
        }
        const out = []
        function pushSection(section, title, list) {
            out.push({ kind: "header", section: section, title: title, count: list.length })
            for (let j = 0; j < list.length; j++)
                out.push({ kind: "network", section: section, network: list[j] })
        }
        pushSection("saved", "已保存", saved)
        pushSection("nearby", "附近网络", nearby)
        return out
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
            _clearConnectOp()
            passwordNetwork = null
            passwordHint = ""
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

    function _clearConnectOp() {
        connectTarget = null
        _connectWithPsk = false
        _stateWasChanging = false
        _opTimeout.stop()
    }

    function _askPassword(network, hint) {
        passwordNetwork = network
        passwordHint = hint || "密码"
        _clearConnectOp()
    }

    function connectToWifi(network) {
        if (!network)
            return
        if (network.connected) {
            network.disconnect()
            cancelPassword()
            _clearConnectOp()
            return
        }
        if (passwordNetwork === network) {
            cancelPassword()
            return
        }
        cancelPassword()

        // 未知安全网：先要密码，少依赖 NoSecrets（NM 有时不发）
        if (!network.known && needsPsk(network)) {
            _askPassword(network, "需要密码")
            return
        }

        connectTarget = network
        _connectWithPsk = false
        _stateWasChanging = false
        _opTimeout.restart()
        network.connect()
    }

    function submitPassword(network, psk) {
        if (!network || !psk)
            return
        passwordNetwork = null
        passwordHint = ""
        connectTarget = network
        _connectWithPsk = true
        _stateWasChanging = false
        _opTimeout.restart()
        network.connectWithPsk(psk)
    }

    function cancelPassword() {
        passwordNetwork = null
        passwordHint = ""
    }

    function forgetNetwork(network) {
        if (!network) {
            _setError("未找到网络")
            return
        }
        if (!network.known) {
            _setError("该网络没有已保存的配置")
            return
        }
        if (passwordNetwork === network)
            cancelPassword()
        if (connectTarget === network)
            _clearConnectOp()
        network.forget()
        _bumpNet()
    }

    function disconnectActiveWifi() {
        const n = _activeWifiNetwork
        if (!n)
            return
        n.disconnect()
        _clearConnectOp()
        cancelPassword()
        _bumpNet()
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

    function _onConnectFailed(reason) {
        if (!connectTarget)
            return
        const authFail = reason === ConnectionFailReason.NoSecrets
            || reason === ConnectionFailReason.WifiAuthTimeout
            || reason === ConnectionFailReason.WifiClientFailed
        if (authFail && needsPsk(connectTarget)) {
            const hint = _connectWithPsk
                ? "密码错误或认证超时"
                : "网络需要密码"
            // 已保存改密：弹框，并可遗忘后重配
            if (connectTarget.known)
                _setError(hint + "（可遗忘后重连）")
            _askPassword(connectTarget, hint)
            return
        }
        const name = connectTarget.name || "网络"
        let msg = "连接失败: " + name
        try {
            const s = ConnectionFailReason.toString(reason)
            if (s && s !== "Unknown")
                msg += "（" + s + "）"
        } catch (e) {
        }
        _setError(msg)
        _clearConnectOp()
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

    // 连接超时兜底：改密后 NM 可能既不 failed 也不成功
    Timer {
        id: _opTimeout
        interval: 45000
        repeat: false
        onTriggered: {
            if (!root.connectTarget)
                return
            const n = root.connectTarget
            if (n.connected) {
                root._clearConnectOp()
                return
            }
            if (root.needsPsk(n)) {
                root._setError("连接超时（可重试密码或遗忘网络）")
                root._askPassword(n, root._connectWithPsk
                    ? "密码错误或认证超时"
                    : "网络需要密码")
                return
            }
            root._setError("连接超时: " + (n.name || "网络"))
            root._clearConnectOp()
        }
    }

    Connections {
        target: root.connectTarget
        ignoreUnknownSignals: true

        function onConnectionFailed(reason) {
            root._onConnectFailed(reason)
        }

        function onConnectedChanged() {
            if (root.connectTarget && root.connectTarget.connected) {
                root.cancelPassword()
                root._clearConnectOp()
                root._bumpNet()
            }
        }

        function onStateChangingChanged() {
            if (root.connectTarget && root.connectTarget.stateChanging)
                root._stateWasChanging = true
        }

        function onStateChanged() {
            if (!root.connectTarget)
                return
            // 曾经进入过 changing，又回到 Disconnected → 当作失败（无 failed 信号时）
            if (root._stateWasChanging
                    && root.connectTarget.state === ConnectionState.Disconnected
                    && !root.connectTarget.connected) {
                if (root.needsPsk(root.connectTarget)) {
                    root._setError(root._connectWithPsk
                        ? "密码错误或认证超时"
                        : "网络需要密码")
                    root._askPassword(root.connectTarget, root._connectWithPsk
                        ? "密码错误或认证超时"
                        : "网络需要密码")
                    return
                }
                root._setError("连接未完成: " + (root.connectTarget.name || "网络"))
                root._clearConnectOp()
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
