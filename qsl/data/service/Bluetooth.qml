pragma Singleton

-- ============================================================
-- 蓝牙服务 — Bluetooth
-- ============================================================
-- 通过 Quickshell.Bluetooth 原生绑定与 BlueZ D-Bus 通信。
-- 提供蓝牙开关、设备扫描、连接/断开、配对/取消配对、设备详情。
-- ============================================================
-- 对外接口一览：
--
-- 属性（readonly）：
--   enabled              bool       蓝牙是否开启
--   discovering          bool       是否正在扫描设备
--   discoverable         bool       是否可被其他设备发现
--   connectedDevices     array      已连接设备列表
--   pairedDevices        array      已配对（未连接）设备列表
--   scannedDevices       array      未配对设备列表
--   lastError            string     最近错误信息（5 秒自动清）
--
-- 属性（可读写）：
--   discoverable         bool       允许被其他设备发现
--
-- 方法：
--   toggle()                        切换蓝牙开关
--   startScan() / stopScan()        控制设备扫描
--   connectDevice(device)           连接设备
--   disconnectDevice(device)        断开设备
--   pairDevice(device)              配对设备
--   forgetDevice(device)            删除设备
--
-- 每个 BluetoothDevice 自带以下属性（无需额外 requestDeviceInfo）：
--   address, name, deviceName, icon, connected, paired, bonded,
--   battery, trusted, blocked, state
-- ============================================================

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter

    // ============================================================
    // 状态
    // ============================================================

    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property bool discovering: adapter ? adapter.discovering : false
    property bool discoverable: adapter ? adapter.discoverable : false
    readonly property string lastError: _lastError

    property string _lastError: ""

    onDiscoverableChanged: {
        if (adapter) adapter.discoverable = discoverable
    }

    // ============================================================
    // 设备列表（按状态分三组，兼容旧 UI）
    // ============================================================

    readonly property var allDevices: {
        if (!adapter || !adapter.devices) return []
        const arr = []
        for (let i = 0; i < adapter.devices.count; i++) {
            const d = adapter.devices.get(i)
            if (d && d.name) arr.push(d)
        }
        return arr
    }

    readonly property var connectedDevices:
        allDevices.filter(d => d.connected)

    readonly property var pairedDevices:
        allDevices.filter(d => d.paired && !d.connected)

    readonly property var scannedDevices:
        allDevices.filter(d => !d.paired)

    // ============================================================
    // 操作
    // ============================================================

    function toggle() {
        if (!adapter) return
        adapter.enabled = !adapter.enabled
    }

    function startScan() {
        if (adapter && enabled)
            adapter.discovering = true
    }

    function stopScan() {
        if (adapter)
            adapter.discovering = false
    }

    function connectDevice(device) {
        if (!device) return
        device.connect()
    }

    function disconnectDevice(device) {
        if (!device) return
        device.disconnect()
    }

    function pairDevice(device) {
        if (!device) return
        device.pair()
    }

    function forgetDevice(device) {
        if (!device) return
        device.forget()
    }

    function _setError(msg) {
        if (!msg) return
        _lastError = msg
        _errorClearTimer.restart()
    }

    Timer {
        id: _errorClearTimer
        interval: 5000
        repeat: false
        onTriggered: _lastError = ""
    }
}
