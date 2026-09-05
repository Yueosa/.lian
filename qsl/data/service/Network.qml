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
import "rowsync.js" as RowSync

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
    // 扫描态得自己记：Quickshell 的 wifi 设备只给了 scannerEnabled 一个开关，
    // 既没有"正在扫描"状态，也没有"扫一次"的方法（实测枚举过它的属性表）。
    // 以前直接把 scannerEnabled 当扫描态，结果是页面开着它就恒为 true——
    // "扫描中…"和转圈图标常驻，永远看不出这一轮扫完了没有
    property bool _scanning: false
    // 这一轮扫描已经补过一次了（空手而归时补一次，不无限补）
    property bool _scanRetried: false
    readonly property bool wifiScanning: _scanning
    readonly property bool hasWifiDevice: !!_wifiDevice
    readonly property string lastError: _lastError

    // 数据版本号（公开面）：NM 的网络/设备对象有不少属性不发通知，服务内部靠
    // _netRev 自增来触发重算。UI 里需要跟着刷新的绑定 void 一下这个就行
    // ——_netRev 是内部的，别从外面碰。SSID 修正表落地时也会带着它一起自增，
    // 所以这一个就覆盖了全部迟到数据
    readonly property int revision: _netRev

    // 当前连接的 Wi‑Fi 名（已过 SSID 修正）。UI 别自己去摸 _activeWifiNetwork
    readonly property string activeWifiName: {
        void _netRev
        const n = _activeWifiNetwork
        return n ? displayName(n) : ""
    }

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

    // ---- 当前连接的接口名与 IPv4 ----
    // NetworkDevice.address 是 MAC（实测），Quickshell.Networking 不给 IP，
    // 只能自己取。不轮询：仅开页和连接态变化时拉一次（fork 在 qs 这种
    // 常驻近 1GiB 的进程里不便宜，见 RailPage 的 derivGate 注释）
    readonly property string activeIface: {
        void _netRev
        if (ethernetConnected && _wiredDevice)
            return String(_wiredDevice.name || "")
        if (wifiConnected && _wifiDevice)
            return String(_wifiDevice.name || "")
        return ""
    }

    property var _ipMap: ({})
    property int _ipRev: 0

    readonly property string activeIp: {
        void _ipRev
        const k = activeIface
        return (k && _ipMap[k]) ? _ipMap[k] : ""
    }

    function refreshIp() {
        if (!detailActive)
            return
        ipProc.running = true
    }

    Process {
        id: ipProc
        command: ["ip", "-j", "-4", "addr", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                try {
                    const arr = JSON.parse(text || "[]")
                    for (let i = 0; i < arr.length; i++) {
                        const d = arr[i]
                        const infos = d.addr_info || []
                        for (let j = 0; j < infos.length; j++) {
                            if (infos[j] && infos[j].local) {
                                map[d.ifname] = String(infos[j].local)
                                break
                            }
                        }
                    }
                } catch (e) {
                    // ip 不在或输出异常：IP 行自己会因为空串隐藏，不报错
                }
                root._ipMap = map
                root._ipRev++
            }
        }
    }

    onActiveIfaceChanged: refreshIp()

    // 开 Wi‑Fi 后自动扫一次。不能在按开关那一拍 callLater 里扫：
    // 置 Networking.wifiEnabled 是异步的，那时 rfkill 还没放开，scanWifi()
    // 只会撞上自己的守卫、报一句「WiFi 已关闭」的假错就退了。
    // 等 wifiEnabled 真的变 true 再扫，顺带覆盖了从 nmtui/托盘那边开的情况
    onWifiEnabledChanged: {
        if (!detailActive)
            return
        if (wifiEnabled)
            scanWifi()
        else
            stopScan()
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
    // 信号格数（0–4）：行尾信号条和排序分档都用它
    function signalBars(network) {
        const s = network ? (network.signalStrength || 0) : 0
        if (s > 0.8)
            return 4
        if (s > 0.6)
            return 3
        if (s > 0.4)
            return 2
        if (s > 0.2)
            return 1
        return 0
    }

    // ---- 稳定行模型：让新 SSID 滑出来，而不是硬冒出来 ----
    //
    // 旧写法是一个扁平 JS 数组（wifiFlatRows），每次扫描 _netRev++ 就整体重算，
    // ListView 拿到新数组只能整体重建，add/displaced 过渡压根没机会触发——
    // 这就是「wifi 的 ssid 列表突然增长」。改成两个 ListModel 增量增删移。
    //
    // 排序按信号「格数」分档而不是原始强度：强度一直在抖，按强度直排会让行
    // 在每次扫描里跳舞。跨档才动，而跨档这一动本身是有信息量的。
    readonly property var wifiRowSource: {
        void _netRev
        if (!detailActive || !wifiEnabled || !_wifiDevice)
            return ({ saved: [], nearby: [] })
        const saved = []
        const nearby = []
        const items = wifiNetworks
        // 同名只留一条（信号最强的那个）。
        //
        // 一个 SSID 在 NM 那儿常常对应好几个接入点（mesh / 双频），全列出来就是
        // 一串一模一样的名字，选哪个都一样、还占满整屏。wifiNetworks 已按信号
        // 降序排过，所以先到的就是最强的那个
        const seen = ({})
        for (let i = 0; i < items.length; i++) {
            const n = items[i]
            if (!n || n.connected)
                continue
            const ssid = String(n.name || "")
            if (ssid.length > 0) {
                if (seen[ssid])
                    continue
                seen[ssid] = true
            }
            if (n.known)
                saved.push(n)
            else
                nearby.push(n)
        }
        const byBars = (a, b) => {
            const d = root.signalBars(b) - root.signalBars(a)
            if (d !== 0)
                return d
            return String(a.name || "").localeCompare(String(b.name || ""))
        }
        saved.sort(byBars)
        nearby.sort(byBars)
        return ({ saved: saved, nearby: nearby })
    }

    ListModel {
        id: _savedModel
        dynamicRoles: true
    }

    ListModel {
        id: _nearbyModel
        dynamicRoles: true
    }

    readonly property var savedRows: _savedModel
    readonly property var nearbyRows: _nearbyModel

    // 键取 **SSID**，不取对象身份。
    //
    // 默认的身份比对在这儿是错的：NM 每次重扫都可能给同一个 SSID 换一个新的
    // WifiNetwork 对象，身份一变 RowSync 就当成「删旧 + 增新」——整张列表每次
    // 扫描都被拆了重搭。轻则白干（delegate 全部重建、图标重算），重则那些
    // add/remove 过渡被下一次扫描打断，删掉的那格永远留在屏幕上，看着就是
    // 「扫描之后多出一条一模一样的 SSID 叠在原来那条上」。
    // 换成 SSID 之后，同一个网络无论对象换几次都是同一行，只走 setProperty
    function wifiRowKey(n) {
        if (!n)
            return ""
        const ssid = String(n.name || "")
        if (ssid.length > 0)
            return ssid
        // 隐藏网络的 SSID 是空的（nmcli 里显示成 "--"）。空串不能当键：附近有两个
        // 隐藏网络就会共用一个键、在模型里互相顶掉。退回对象自身（也就是老的身份
        // 比对：这一支还会每次重扫都重建那一行，但至少不会张冠李戴）
        return String(n)
    }

    onWifiRowSourceChanged: {
        RowSync.sync(_savedModel, wifiRowSource.saved, "network", wifiRowKey)
        RowSync.sync(_nearbyModel, wifiRowSource.nearby, "network", wifiRowKey)
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

    // 是否已保存过（NM 存着这个网络的连接配置）
    function isKnown(network) {
        return !!(network && network.known)
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
        refreshIp()
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
        // 已经在扫了就别再来一遍：结果马上就到。
        //
        // 这里踩过：原来每次调用都无条件先关再开，而"关"会把正在飞的那次扫描掐掉
        // 重来。进页面自动扫 + 随手点一下扫描（或 detailActive 抖一下）就是掐掉重
        // 数 3–5 秒，看着像"这次扫描坏了，拿不到东西 / 很晚才拿到"
        if (_scanning)
            return
        _scanning = true
        _scanRetried = false
        scanWindow.restart()
        _kickScanner()
    }

    // NM 没给"扫一次"的方法，只有 scannerEnabled 这一招：
    //   关着 → 直接开，NM 立刻扫一轮（进页面走的是这条，上次关页已经关掉了）
    //   开着 → 先关再开才算一次新的请求，那一下"关"是必要的
    function _kickScanner() {
        if (!_wifiDevice || !wifiEnabled)
            return
        if (!_wifiDevice.scannerEnabled) {
            _wifiDevice.scannerEnabled = true
            _netRev++
            _scheduleSsidFix()
            return
        }
        _wifiDevice.scannerEnabled = false
        Qt.callLater(() => {
            if (root._wifiDevice && root.wifiEnabled)
                root._wifiDevice.scannerEnabled = true
            root._netRev++
            root._scheduleSsidFix()
        })
    }

    function stopScan() {
        _scanning = false
        scanWindow.stop()
        if (_wifiDevice)
            _wifiDevice.scannerEnabled = false
    }

    // 扫描态的收尾闹钟：NM 扫一轮大约 3–5 秒，且不会告诉我们什么时候扫完
    Timer {
        id: scanWindow
        interval: 5000
        onTriggered: {
            // 空手而归就再补一次（页面还开着的话）。
            //
            // 进页面那一下自动扫时不时会颗粒无收——NM 刚被叫醒、或者网卡正忙。
            // 没有兜底的话页面就停在"附近没有网络"，得自己去点扫描
            if (root.detailActive && root.wifiEnabled && !root._scanRetried
                    && root.wifiNetworks.length === 0) {
                root._scanRetried = true
                scanWindow.restart()
                root._kickScanner()
                return
            }
            root._scanning = false
        }
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
