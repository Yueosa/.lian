pragma Singleton

// ============================================================
// 蓝牙服务 — Bluetooth
// ============================================================
// Quickshell.Bluetooth ↔ BlueZ
// 详情列表仅在 detailActive 时构造；关页停扫描、不保留设备数组
// ObjectModel 用 .values（无 .count / .get）
// ============================================================
// 对外接口：
//   detailActive / setDetailActive(bool)
//   enabled / discovering / hasAdapter / lastError
//   chipLabel / chipConnected     Bar 轻量摘要（不建列表）
//   connectedDevices / pairedDevices / scannedDevices / pairedRows / nearbyRows
//   toggle / startScan / stopScan / toggleScan
//   connectDevice / disconnectDevice / pairDevice / forgetDevice
//   displayName(device) / openBlueman()
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "rowsync.js" as RowSync

Singleton {
    id: root

    property bool detailActive: false
    property string _lastError: ""
    property int _devRev: 0

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: !!adapter
    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property bool discovering: adapter ? adapter.discovering : false
    readonly property string adapterName: adapter ? String(adapter.name || "") : ""
    readonly property bool discoverable: !!(adapter && adapter.discoverable)
    readonly property int connectedCount: connectedDevices.length

    // 数据版本号（公开面），同 Network.revision：BlueZ 的设备对象有属性不发通知，
    // 内部靠 _devRev 自增触发重算，UI 只 void 这个公开面
    readonly property int revision: _devRev
    readonly property string lastError: _lastError

    // 摘要卡（详情页）
    readonly property var primaryConnected: {
        void _devRev
        const list = connectedDevices
        return list.length > 0 ? list[0] : null
    }

    readonly property string summaryTitle: {
        void _devRev
        if (!hasAdapter)
            return "未找到适配器"
        if (!enabled)
            return "蓝牙已关闭"
        const n = connectedDevices.length
        if (n === 1)
            return displayName(primaryConnected)
        if (n > 1)
            return n + " 台已连接"
        return "已开启"
    }

    readonly property string summarySubtitle: {
        void _devRev
        if (!hasAdapter)
            return "检查硬件或驱动"
        if (!enabled)
            return "打开开关以扫描附近设备"
        const n = connectedDevices.length
        if (n === 1 && primaryConnected) {
            if (primaryConnected.batteryAvailable)
                return "已连接 · 电量 "
                    + Math.round((primaryConnected.battery || 0) * 100) + "%"
            return "已连接"
        }
        if (n > 1)
            return "点按下方设备可断开"
        if (discovering)
            return "正在扫描附近设备…"
        return "选择下方设备以配对或连接"
    }

    readonly property string summaryIcon: {
        void _devRev
        if (!enabled)
            return "bluetooth_disabled"
        if (connectedDevices.length > 0)
            return "bluetooth_connected"
        return "bluetooth"
    }

    function _devices() {
        if (!adapter || !adapter.devices)
            return []
        return adapter.devices.values || []
    }

    function displayName(device) {
        if (!device)
            return "未知设备"
        return device.name || device.deviceName || device.address || "未知设备"
    }

    function isConnecting(device) {
        return !!(device && device.state === BluetoothDeviceState.Connecting)
    }

    function isDisconnecting(device) {
        return !!(device && device.state === BluetoothDeviceState.Disconnecting)
    }

    function isConnected(device) {
        return !!(device && device.connected)
    }

    // 设备图标：BlueZ 给的 icon 名归类到 Material Symbols。
    // 和 displayName / statusHint / sectionOf 一族放一起——取值口都在服务层
    function deviceIcon(device) {
        if (!device)
            return "bluetooth"
        const ic = String(device.icon || "").toLowerCase()
        if (ic.indexOf("audio") >= 0 || ic.indexOf("headset") >= 0 || ic.indexOf("headphone") >= 0)
            return "headphones"
        if (ic.indexOf("input") >= 0 || ic.indexOf("keyboard") >= 0)
            return "keyboard"
        if (ic.indexOf("mouse") >= 0)
            return "mouse"
        if (ic.indexOf("phone") >= 0)
            return "smartphone"
        if (ic.indexOf("computer") >= 0 || ic.indexOf("laptop") >= 0)
            return "laptop"
        return "bluetooth"
    }

    function isBusy(device) {
        return isConnecting(device) || isDisconnecting(device) || !!(device && device.pairing)
    }

    function statusHint(device, section) {
        if (!device)
            return ""
        if (isConnecting(device))
            return "连接中…"
        if (isDisconnecting(device))
            return "断开中…"
        if (device.pairing)
            return "配对中…"
        if (section === "connected") {
            if (device.batteryAvailable)
                return "已连接 · 电量 " + Math.round((device.battery || 0) * 100) + "%"
            return "已连接"
        }
        if (section === "paired")
            return "已配对"
        return "附近"
    }

    // Bar 芯片：只扫一遍找首个已连，不建数组；关页也可用
    readonly property bool chipConnected: {
        void _devRev
        if (!adapter || !enabled)
            return false
        void adapter.devices.values
        const list = _devices()
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].connected)
                return true
        }
        return false
    }

    readonly property string chipLabel: {
        void _devRev
        if (!enabled)
            return "已关闭"
        if (!adapter)
            return "已关闭"
        void adapter.devices.values
        const list = _devices()
        for (let i = 0; i < list.length; i++) {
            const d = list[i]
            if (d && d.connected)
                return displayName(d)
        }
        return "已开启"
    }

    // 仅详情页构建；关页 []，避免后台绑定
    readonly property var allDevices: {
        void _devRev
        if (!detailActive || !adapter)
            return []
        void adapter.devices.values
        const list = _devices()
        const arr = []
        for (let i = 0; i < list.length; i++) {
            const d = list[i]
            if (!d)
                continue
            // 无任何标识的跳过，避免空行刷屏
            if (!(d.name || d.deviceName || d.address))
                continue
            arr.push(d)
        }
        return arr
    }

    readonly property var connectedDevices: {
        void _devRev
        return allDevices.filter(d => d.connected)
    }

    readonly property var pairedDevices: {
        void _devRev
        return allDevices.filter(d => d.paired && !d.connected)
    }

    readonly property var scannedDevices: {
        void _devRev
        return allDevices.filter(d => !d.paired)
    }

    // 设备属于哪个分区（行的副标题文案和点击行为都看它）
    function sectionOf(device) {
        if (!device)
            return ""
        if (device.connected)
            return "connected"
        if (device.paired)
            return "paired"
        return "scanned"
    }

    // ---- 稳定行模型：让新扫到的设备滑出来，而不是硬冒出来 ----
    //
    // 旧写法是一个扁平 JS 数组（flatRows），每次 _devRev++ 整体重算，
    // ListView 只能整体重建，add/displaced 过渡播不了。见 rowsync.js。
    //
    // 已配对卡把「已连接」并进来（设计如此：连接态体现在行的副标题和行尾
    // 操作上，不单开一节），已连接的排前面。设备顺序跟适配器给的次序，
    // 不另外按信号排——Quickshell 的 BluetoothDevice 没有 RSSI
    readonly property var deviceRowSource: {
        void _devRev
        if (!detailActive || !enabled)
            return ({ paired: [], nearby: [] })
        return ({
            paired: connectedDevices.concat(pairedDevices),
            nearby: scannedDevices
        })
    }

    ListModel {
        id: _pairedModel
        dynamicRoles: true
    }

    ListModel {
        id: _nearbyModel
        dynamicRoles: true
    }

    readonly property var pairedRows: _pairedModel
    readonly property var nearbyRows: _nearbyModel

    // 键取 MAC，不取对象身份：底层重扫时给同一台设备换个新对象是常事，按身份比
    // 就成了「删旧 + 增新」，整列白重建（wifi 那边踩过，见 Network.wifiRowKey）
    function deviceRowKey(d) {
        if (!d)
            return ""
        return String(d.address || d.name || d.deviceName || "")
    }

    onDeviceRowSourceChanged: {
        RowSync.sync(_pairedModel, deviceRowSource.paired, "device", deviceRowKey)
        RowSync.sync(_nearbyModel, deviceRowSource.nearby, "device", deviceRowKey)
    }

    function setDetailActive(active) {
        detailActive = !!active
        if (!detailActive) {
            stopScan()
            _clearPending()
            _devRev++
            return
        }
        _devRev++
        if (enabled)
            startScan()
    }

    function toggle() {
        if (!adapter) {
            _setError("未找到蓝牙适配器")
            return
        }
        adapter.enabled = !adapter.enabled
        // 开机后的自动扫描交给 onEnabledChanged：这里 callLater 太早，
        // 适配器还没上电
        _devRev++
    }

    // 开蓝牙后自动扫一次。adapter.enabled = true 是 DBus 异步的，紧接着
    // 调 startScan() 会撞上它自己的「蓝牙已关闭」守卫，不但没扫还报个假错。
    // 等 enabled 真的翻过来再扫，顺带覆盖了从 blueman 那边开的情况
    onEnabledChanged: {
        if (!detailActive)
            return
        if (enabled)
            startScan()
        else
            stopScan()
    }

    function startScan() {
        if (!adapter) {
            _setError("未找到蓝牙适配器")
            return
        }
        if (!enabled) {
            _setError("蓝牙已关闭")
            return
        }
        adapter.discovering = true
        // 刚上电那几拍 BlueZ 会把 StartDiscovery 顶回来，补几次重试，见下
        scanRetry.left = 8
        scanRetry.restart()
        _devRev++
    }

    // 开蓝牙后第一次 StartDiscovery 基本一定失败：BlueZ 的 Powered 属性先翻成
    // true，但适配器还没准备好，实测被顶回来并打
    //   quickshell.bluetooth.adapter: Failed to start discovery … "Resource Not Ready"
    // 所以"等 enabled 翻过来再扫"仍然太早，得重试到它肯接。
    // 8 次 × 400ms 都没成就放弃，且不报错——首卡和分区标题上都有扫描钮
    Timer {
        id: scanRetry
        interval: 400
        repeat: true
        property int left: 0
        onTriggered: {
            if (root.discovering || !root.enabled || !root.detailActive || left <= 0) {
                stop()
                return
            }
            left--
            if (root.adapter)
                root.adapter.discovering = true
        }
    }

    function stopScan() {
        scanRetry.stop()
        if (adapter)
            adapter.discovering = false
    }

    function toggleScan() {
        if (discovering)
            stopScan()
        else
            startScan()
    }

    property var _pendingDevice: null
    property int _pendingKind: 0 // 0 none, 1 connect, 2 pair

    function connectDevice(device) {
        if (!device)
            return
        if (device.connected) {
            device.disconnect()
            return
        }
        // 扫描中连设备极易 page-timeout / Resource Not Ready
        stopScan()
        if (!device.trusted)
            device.trusted = true
        _pendingDevice = device
        _pendingKind = 1
        device.connect()
        _devRev++
        _pendingWatch.restart()
    }

    function disconnectDevice(device) {
        if (!device)
            return
        _clearPending()
        device.disconnect()
        _devRev++
    }

    function pairDevice(device) {
        if (!device)
            return
        stopScan()
        _pendingDevice = device
        _pendingKind = 2
        device.pair()
        _devRev++
        _pendingWatch.restart()
    }

    function forgetDevice(device) {
        if (!device)
            return
        _clearPending()
        device.forget()
        _devRev++
    }

    function openBlueman() {
        Quickshell.execDetached(["blueman-manager"])
    }

    function _clearPending() {
        _pendingDevice = null
        _pendingKind = 0
        _pendingWatch.stop()
    }

    function _checkPendingResult() {
        const d = _pendingDevice
        if (!d)
            return
        if (_pendingKind === 1) {
            if (d.connected) {
                _clearPending()
                _devRev++
                return
            }
            if (isConnecting(d))
                return
            // 已离开 Connecting 且仍未连上
            const name = displayName(d)
            _setError("连接失败: " + name + "（可忘记后重配，或开 blueman）")
            _clearPending()
            _devRev++
            return
        }
        if (_pendingKind === 2) {
            if (d.paired) {
                // 配对成功后自动连一次（手机等常见流程）
                if (!d.trusted)
                    d.trusted = true
                _pendingKind = 1
                d.connect()
                _pendingWatch.restart()
                _devRev++
                return
            }
            if (d.pairing)
                return
            _setError("配对失败: " + displayName(d) + "（手机请打开蓝牙设置并确认）")
            _clearPending()
            _devRev++
        }
    }

    function _setError(msg) {
        if (!msg)
            return
        _lastError = msg
        _errorClearTimer.restart()
    }

    function _bumpDev() {
        _devRev++
    }

    Connections {
        target: root.adapter ? root.adapter.devices : null
        ignoreUnknownSignals: true
        function onValuesChanged() { root._bumpDev() }
    }

    Connections {
        target: root.adapter
        ignoreUnknownSignals: true
        function onEnabledChanged() { root._bumpDev() }
        function onDiscoveringChanged() { root._bumpDev() }
    }

    Connections {
        target: root._pendingDevice
        ignoreUnknownSignals: true
        function onConnectedChanged() { root._checkPendingResult() }
        function onStateChanged() { root._checkPendingResult() }
        function onPairedChanged() { root._checkPendingResult() }
        function onPairingChanged() { root._checkPendingResult() }
    }

    // 连接/配对超时兜底（BlueZ 常见 page-timeout ~10–20s）
    Timer {
        id: _pendingWatch
        interval: 18000
        repeat: false
        onTriggered: {
            if (!root._pendingDevice)
                return
            const name = root.displayName(root._pendingDevice)
            if (root._pendingKind === 1 && !root._pendingDevice.connected)
                root._setError("连接超时: " + name + "（确认设备开机且在附近）")
            else if (root._pendingKind === 2 && !root._pendingDevice.paired)
                root._setError("配对超时: " + name + "（请用 blueman）")
            root._clearPending()
            root._devRev++
        }
    }

    // JS filter 读 d.connected 不会订阅 device 的 notify；轻量对账分组归属。
    // 仅详情页开着时跑，2s 一次，关页即停。
    Timer {
        interval: 2000
        running: root.detailActive && root.enabled
        repeat: true
        onTriggered: root._bumpDev()
    }

    // 栏芯片：页关着时慢对账已连态（3s）；开销仅扫 devices 找 connected
    Timer {
        interval: 3000
        running: root.enabled && !root.detailActive
        repeat: true
        onTriggered: root._bumpDev()
    }

    Timer {
        id: _errorClearTimer
        interval: 6000
        repeat: false
        onTriggered: _lastError = ""
    }
}
