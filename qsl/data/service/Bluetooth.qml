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
//   connectedDevices / pairedDevices / scannedDevices / flatRows
//   toggle / startScan / stopScan / toggleScan
//   connectDevice / disconnectDevice / pairDevice / forgetDevice
//   displayName(device) / openBlueman()
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    property bool detailActive: false
    property string _lastError: ""
    property int _devRev: 0

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: !!adapter
    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property bool discovering: adapter ? adapter.discovering : false
    readonly property string lastError: _lastError

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

    // ListView 扁平行：section header + device
    // kind: "header" | "device"
    // section: "connected" | "paired" | "scanned"
    readonly property var flatRows: {
        void _devRev
        if (!detailActive || !enabled)
            return []
        const out = []
        function pushSection(section, title, list) {
            out.push({ kind: "header", section: section, title: title, count: list.length })
            for (let i = 0; i < list.length; i++)
                out.push({ kind: "device", section: section, device: list[i] })
        }
        pushSection("connected", "已连接", connectedDevices)
        pushSection("paired", "已配对", pairedDevices)
        pushSection("scanned", "附近设备", scannedDevices)
        return out
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
        const turningOn = !adapter.enabled
        adapter.enabled = turningOn
        if (turningOn && detailActive)
            Qt.callLater(() => root.startScan())
        else if (!turningOn)
            stopScan()
        _devRev++
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
        _devRev++
    }

    function stopScan() {
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

    Timer {
        id: _errorClearTimer
        interval: 6000
        repeat: false
        onTriggered: _lastError = ""
    }
}
