pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string prefsFile: Quickshell.env("HOME") + "/.cache/quickshell/dynamicisland_prefs.json"

    // === 全局与分类开关 ===
    property bool enabled: true
    property bool connectionEnabled: true
    property bool lianclawEnabled: true
    property bool resourcesEnabled: true
    property bool powerStorageEnabled: false

    // === 子项开关（Phase B 完整）===
    property bool wifiEventEnabled: true
    property bool bluetoothEventEnabled: true
    property bool lianclawConfirmEnabled: true
    property bool lianclawFormEnabled: true
    property bool lianclawDoneEnabled: true
    property bool lianclawFailEnabled: true
    property bool cpuUsageEnabled: true
    property bool memoryUsageEnabled: true
    property bool gpuUsageEnabled: true
    property bool cpuTempEnabled: true
    property bool gpuTempEnabled: true
    property bool lowBatteryEnabled: true
    property bool diskUsageEnabled: true

    // === 防打扰 ===
    property bool quietHoursEnabled: false
    property int quietStartHour: 0
    property int quietEndHour: 8
    property int duplicateCooldownSec: 90

    // === 温度阈值（Phase B 首批）===
    property int cpuTempTrigger: 90
    property int cpuTempRecover: 84
    property int gpuTempTrigger: 88
    property int gpuTempRecover: 82

    property bool _loading: false
    property bool _ready: false

    function clampInt(value, minValue, maxValue, fallback) {
        const n = Number(value)
        if (isNaN(n))
            return fallback
        return Math.max(minValue, Math.min(maxValue, Math.round(n)))
    }

    function enforceTempHysteresis() {
        if (cpuTempRecover >= cpuTempTrigger)
            cpuTempRecover = Math.max(40, cpuTempTrigger - 2)
        if (gpuTempRecover >= gpuTempTrigger)
            gpuTempRecover = Math.max(40, gpuTempTrigger - 2)
    }

    function setCpuTempTrigger(value) {
        cpuTempTrigger = clampInt(value, 60, 110, cpuTempTrigger)
        enforceTempHysteresis()
    }

    function setGpuTempTrigger(value) {
        gpuTempTrigger = clampInt(value, 60, 110, gpuTempTrigger)
        enforceTempHysteresis()
    }

    function setQuietStartHour(value) {
        quietStartHour = clampInt(value, 0, 23, quietStartHour)
    }

    function setQuietEndHour(value) {
        quietEndHour = clampInt(value, 0, 23, quietEndHour)
    }

    function setDuplicateCooldownSec(value) {
        duplicateCooldownSec = clampInt(value, 5, 3600, duplicateCooldownSec)
    }

    function toMap() {
        return {
            enabled: enabled,
            connectionEnabled: connectionEnabled,
            lianclawEnabled: lianclawEnabled,
            resourcesEnabled: resourcesEnabled,
            powerStorageEnabled: powerStorageEnabled,
            wifiEventEnabled: wifiEventEnabled,
            bluetoothEventEnabled: bluetoothEventEnabled,
            lianclawConfirmEnabled: lianclawConfirmEnabled,
            lianclawFormEnabled: lianclawFormEnabled,
            lianclawDoneEnabled: lianclawDoneEnabled,
            lianclawFailEnabled: lianclawFailEnabled,
            cpuUsageEnabled: cpuUsageEnabled,
            memoryUsageEnabled: memoryUsageEnabled,
            gpuUsageEnabled: gpuUsageEnabled,
            cpuTempEnabled: cpuTempEnabled,
            gpuTempEnabled: gpuTempEnabled,
            lowBatteryEnabled: lowBatteryEnabled,
            diskUsageEnabled: diskUsageEnabled,
            quietHoursEnabled: quietHoursEnabled,
            quietStartHour: quietStartHour,
            quietEndHour: quietEndHour,
            duplicateCooldownSec: duplicateCooldownSec,
            cpuTempTrigger: cpuTempTrigger,
            cpuTempRecover: cpuTempRecover,
            gpuTempTrigger: gpuTempTrigger,
            gpuTempRecover: gpuTempRecover
        }
    }

    function applyMap(map) {
        const src = (map && typeof map === "object") ? map : ({})

        _loading = true

        if (typeof src.enabled === "boolean")
            enabled = src.enabled
        if (typeof src.connectionEnabled === "boolean")
            connectionEnabled = src.connectionEnabled
        if (typeof src.lianclawEnabled === "boolean")
            lianclawEnabled = src.lianclawEnabled
        if (typeof src.resourcesEnabled === "boolean")
            resourcesEnabled = src.resourcesEnabled
        if (typeof src.powerStorageEnabled === "boolean")
            powerStorageEnabled = src.powerStorageEnabled
        if (typeof src.wifiEventEnabled === "boolean")
            wifiEventEnabled = src.wifiEventEnabled
        if (typeof src.bluetoothEventEnabled === "boolean")
            bluetoothEventEnabled = src.bluetoothEventEnabled
        if (typeof src.lianclawConfirmEnabled === "boolean")
            lianclawConfirmEnabled = src.lianclawConfirmEnabled
        if (typeof src.lianclawFormEnabled === "boolean")
            lianclawFormEnabled = src.lianclawFormEnabled
        if (typeof src.lianclawDoneEnabled === "boolean")
            lianclawDoneEnabled = src.lianclawDoneEnabled
        if (typeof src.lianclawFailEnabled === "boolean")
            lianclawFailEnabled = src.lianclawFailEnabled
        if (typeof src.cpuUsageEnabled === "boolean")
            cpuUsageEnabled = src.cpuUsageEnabled
        if (typeof src.memoryUsageEnabled === "boolean")
            memoryUsageEnabled = src.memoryUsageEnabled
        if (typeof src.gpuUsageEnabled === "boolean")
            gpuUsageEnabled = src.gpuUsageEnabled
        if (typeof src.cpuTempEnabled === "boolean")
            cpuTempEnabled = src.cpuTempEnabled
        if (typeof src.gpuTempEnabled === "boolean")
            gpuTempEnabled = src.gpuTempEnabled
        if (typeof src.lowBatteryEnabled === "boolean")
            lowBatteryEnabled = src.lowBatteryEnabled
        if (typeof src.diskUsageEnabled === "boolean")
            diskUsageEnabled = src.diskUsageEnabled

        if (typeof src.quietHoursEnabled === "boolean")
            quietHoursEnabled = src.quietHoursEnabled

        quietStartHour = clampInt(src.quietStartHour, 0, 23, quietStartHour)
        quietEndHour = clampInt(src.quietEndHour, 0, 23, quietEndHour)
        duplicateCooldownSec = clampInt(src.duplicateCooldownSec, 5, 3600, duplicateCooldownSec)

        cpuTempTrigger = clampInt(src.cpuTempTrigger, 60, 110, cpuTempTrigger)
        cpuTempRecover = clampInt(src.cpuTempRecover, 40, 108, cpuTempRecover)
        gpuTempTrigger = clampInt(src.gpuTempTrigger, 60, 110, gpuTempTrigger)
        gpuTempRecover = clampInt(src.gpuTempRecover, 40, 108, gpuTempRecover)

        enforceTempHysteresis()

        _loading = false
        _ready = true
    }

    function requestPersist() {
        if (!_ready || _loading)
            return
        persistDebounce.restart()
    }

    function persistNow() {
        const json = JSON.stringify(toMap())
        const dir = prefsFile.replace(/\/[^/]*$/, "")
        saveProcess.command = ["bash", "-c",
            "mkdir -p " + JSON.stringify(dir) +
            " && printf '%s' " + JSON.stringify(json) +
            " > " + JSON.stringify(prefsFile)]
        saveProcess.running = true
    }

    function resetDefaults() {
        _loading = true

        enabled = true
        connectionEnabled = true
        lianclawEnabled = true
        resourcesEnabled = true
        powerStorageEnabled = false
        wifiEventEnabled = true
        bluetoothEventEnabled = true
        lianclawConfirmEnabled = true
        lianclawFormEnabled = true
        lianclawDoneEnabled = true
        lianclawFailEnabled = true
        cpuUsageEnabled = true
        memoryUsageEnabled = true
        gpuUsageEnabled = true
        cpuTempEnabled = true
        gpuTempEnabled = true
        lowBatteryEnabled = true
        diskUsageEnabled = true
        quietHoursEnabled = false
        quietStartHour = 0
        quietEndHour = 8
        duplicateCooldownSec = 90
        cpuTempTrigger = 90
        cpuTempRecover = 84
        gpuTempTrigger = 88
        gpuTempRecover = 82

        _loading = false
        _ready = true
        requestPersist()
    }

    onEnabledChanged: requestPersist()
    onConnectionEnabledChanged: requestPersist()
    onLianclawEnabledChanged: requestPersist()
    onResourcesEnabledChanged: requestPersist()
    onPowerStorageEnabledChanged: requestPersist()
    onWifiEventEnabledChanged: requestPersist()
    onBluetoothEventEnabledChanged: requestPersist()
    onLianclawConfirmEnabledChanged: requestPersist()
    onLianclawFormEnabledChanged: requestPersist()
    onLianclawDoneEnabledChanged: requestPersist()
    onLianclawFailEnabledChanged: requestPersist()
    onCpuUsageEnabledChanged: requestPersist()
    onMemoryUsageEnabledChanged: requestPersist()
    onGpuUsageEnabledChanged: requestPersist()
    onCpuTempEnabledChanged: requestPersist()
    onGpuTempEnabledChanged: requestPersist()
    onLowBatteryEnabledChanged: requestPersist()
    onDiskUsageEnabledChanged: requestPersist()
    onQuietHoursEnabledChanged: requestPersist()
    onQuietStartHourChanged: requestPersist()
    onQuietEndHourChanged: requestPersist()
    onDuplicateCooldownSecChanged: requestPersist()
    onCpuTempTriggerChanged: requestPersist()
    onCpuTempRecoverChanged: requestPersist()
    onGpuTempTriggerChanged: requestPersist()
    onGpuTempRecoverChanged: requestPersist()

    FileView {
        id: prefsFileView
        path: root.prefsFile

        onLoaded: {
            try {
                const raw = prefsFileView.text()
                if (!raw || raw.trim().length === 0) {
                    root._ready = true
                    root.requestPersist()
                    return
                }
                const parsed = JSON.parse(raw)
                root.applyMap(parsed)
                // 回填新增字段，确保旧配置升级后补全。
                root.requestPersist()
            } catch (e) {
                root._ready = true
                root.requestPersist()
            }
        }

        onLoadFailed: {
            root._ready = true
            root.requestPersist()
        }
    }

    Timer {
        id: persistDebounce
        interval: 220
        repeat: false
        onTriggered: root.persistNow()
    }

    Process {
        id: saveProcess
        running: false
    }
}
