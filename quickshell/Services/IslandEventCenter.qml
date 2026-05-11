pragma Singleton

import QtQuick
import Quickshell
import Clavis.Notif
import Clavis.Sysmon 1.0
import qs.config
import qs.Modules.DynamicIsland.OverviewContent

Singleton {
    id: root

    // 用于在消费者处强制加载该单例。
    readonly property bool booted: _booted

    readonly property int _priorityCritical: 100
    readonly property int _priorityHigh: 80
    readonly property int _priorityNormal: 50

    readonly property int _cpuUsageTrigger: 90
    readonly property int _cpuUsageRecover: 75
    readonly property int _memUsageTrigger: 92
    readonly property int _memUsageRecover: 85
    readonly property int _gpuUsageTrigger: 95
    readonly property int _gpuUsageRecover: 80
    readonly property int _batteryLowTrigger: 20
    readonly property int _batteryLowRecover: 25
    readonly property int _diskUsageTrigger: 92
    readonly property int _diskUsageRecover: 85

    property bool _booted: false
    property bool _emitReady: false
    property int _eventSeq: 0
    property var _queue: []
    property var _lastEmitMsByKey: ({})
    property var _recentEmitMs: ([])
    property var _resourceState: ({})
    property var _debugStats: _defaultDebugStats()

    property bool _netReady: false
    property bool _netConnected: false
    property string _netType: ""

    property bool _btReady: false
    property bool _btConnected: false
    property string _btDevice: ""

    property bool _lianReady: false
    property bool _lianConfirmPending: false
    property bool _lianFormPending: false
    property string _lianPhase: ""

    function _nowMs() {
        return Date.now()
    }

    function _log(message) {
        console.log("[IslandEventCenter] " + message)
    }

    function _defaultDebugStats() {
        return {
            enqueued: 0,
            forced_enqueued: 0,
            emitted: 0,
            blocked_disabled: 0,
            blocked_boot: 0,
            blocked_dnd: 0,
            blocked_quiet: 0,
            blocked_cooldown: 0,
            blocked_rate: 0,
            blocked_queue: 0,
            blocked_unknown: 0
        }
    }

    function _bumpDebugStat(name) {
        const key = String(name || "blocked_unknown")
        const next = Object.assign({}, _debugStats)
        next[key] = Number(next[key] || 0) + 1
        _debugStats = next
    }

    function debugResetStats() {
        _debugStats = _defaultDebugStats()
        _recentEmitMs = ([])
        _lastEmitMsByKey = ({})
        _queue = []
        _log("stats reset")
        return true
    }

    function debugStatsJson() {
        const snap = Object.assign({}, _debugStats)
        snap.queueDepth = _queue.length
        snap.booted = _booted
        snap.emitReady = _emitReady
        snap.cooldownSec = Number(DynamicIslandPrefs.duplicateCooldownSec || 90)
        snap.recentEmitInWindow = _recentEmitMs.length
        snap.lastEmitKeyCount = Object.keys(_lastEmitMsByKey).length
        return JSON.stringify(snap)
    }

    function debugDumpStats() {
        const json = debugStatsJson()
        _log("stats " + json)
        return json
    }

    function _inQuietHours() {
        if (!DynamicIslandPrefs.quietHoursEnabled)
            return false

        const start = Math.max(0, Math.min(23, Number(DynamicIslandPrefs.quietStartHour)))
        const end = Math.max(0, Math.min(23, Number(DynamicIslandPrefs.quietEndHour)))
        const hour = new Date().getHours()

        if (start === end)
            return true
        if (start < end)
            return hour >= start && hour < end
        return hour >= start || hour < end
    }

    function _canEmit(key, priority) {
        if (!DynamicIslandPrefs.enabled)
            return { ok: false, reason: "disabled" }

        const critical = priority >= _priorityCritical

        if (!critical && !_emitReady)
            return { ok: false, reason: "boot" }

        if (!critical && ControlBackend.dndEnabled)
            return { ok: false, reason: "dnd" }

        if (!critical && _inQuietHours())
            return { ok: false, reason: "quiet" }

        const now = _nowMs()
        const cooldownMs = Math.max(1, Number(DynamicIslandPrefs.duplicateCooldownSec || 90)) * 1000
        const last = Number(_lastEmitMsByKey[key] || 0)

        if (!critical && now - last < cooldownMs)
            return { ok: false, reason: "cooldown" }

        const recent = []
        for (let i = 0; i < _recentEmitMs.length; ++i) {
            const ts = Number(_recentEmitMs[i] || 0)
            if (now - ts <= 60000)
                recent.push(ts)
        }
        _recentEmitMs = recent

        // 低优先级事件在一分钟内最多 8 条，避免刷屏。
        if (priority < _priorityHigh && _recentEmitMs.length >= 8)
            return { ok: false, reason: "rate" }

        return { ok: true, reason: "ok" }
    }

    function _priorityToSeverity(priority) {
        if (priority >= _priorityCritical)
            return "critical"
        if (priority >= _priorityHigh)
            return "high"
        return "normal"
    }

    function _enqueueEvent(key, priority, summary, body, iconName, category, forceEmit) {
        const force = !!forceEmit
        const gate = force ? ({ ok: true, reason: "forced" }) : _canEmit(key, priority)

        if (!gate.ok) {
            _bumpDebugStat("blocked_" + String(gate.reason || "unknown"))
            return false
        }

        if (!force && _queue.length >= 24 && priority < _priorityHigh) {
            _bumpDebugStat("blocked_queue")
            return false
        }

        const now = _nowMs()
        const severity = _priorityToSeverity(priority)
        const normalizedCategory = String(category || "general")
        const nextLast = Object.assign({}, _lastEmitMsByKey)
        nextLast[key] = now
        _lastEmitMsByKey = nextLast

        const recent = _recentEmitMs.slice()
        recent.push(now)
        _recentEmitMs = recent

        const nextQueue = _queue.slice()
        nextQueue.push({
            key: key,
            priority: priority,
            severity: severity,
            category: normalizedCategory,
            summary: summary,
            body: body,
            iconName: iconName || "dialog-information",
            createdAt: now
        })

        nextQueue.sort((a, b) => {
            if (a.priority !== b.priority)
                return b.priority - a.priority
            return a.createdAt - b.createdAt
        })

        _queue = nextQueue
        _bumpDebugStat(force ? "forced_enqueued" : "enqueued")
        if (!dispatchTimer.running)
            dispatchTimer.start()

        return true
    }

    function _dispatchNext() {
        if (_queue.length === 0)
            return

        const nextQueue = _queue.slice()
        const evt = nextQueue.shift()
        _queue = nextQueue

        _eventSeq += 1
        const notifId = 810000000 + _eventSeq
        const desktopEntry = "quickshell-island-event." + evt.severity + "." + evt.category
        const appName = "IslandEventCenter/" + evt.severity + "/" + evt.category

        NotificationStore.ingest({
            id: notifId,
            appName: appName,
            desktopEntry: desktopEntry,
            summary: evt.summary,
            body: evt.body,
            image: "",
            appIcon: evt.iconName,
            icon: evt.iconName
        }, true)

        _log("emit key=" + evt.key + " p=" + evt.priority + " summary=\"" + evt.summary + "\"")
        _bumpDebugStat("emitted")

        if (_queue.length > 0)
            dispatchTimer.restart()
    }

    function debugEmitPreset(name, mode) {
        const preset = String(name || "resource_cpu")
        const rawMode = String(mode || "force").toLowerCase()
        const normalizedMode = (rawMode === "policy" || rawMode === "policy-unique") ? rawMode : "force"
        const force = normalizedMode === "force"
        const stablePolicyKey = normalizedMode === "policy"
        const debugKey = stablePolicyKey
            ? ("debug_policy_" + preset)
            : ("debug_" + normalizedMode + "_" + preset + "_" + _nowMs() + "_" + Math.floor(Math.random() * 1000))

        if (preset === "lian_confirm") {
            return _enqueueEvent(debugKey, _priorityCritical, "LianClaw 等待确认", "有工具调用需要人工确认", "dialog-warning", "lianclaw", force)
        }
        if (preset === "lian_form") {
            return _enqueueEvent(debugKey, _priorityCritical, "LianClaw 等待表单", "有参数表单需要填写", "dialog-warning", "lianclaw", force)
        }
        if (preset === "lian_done") {
            return _enqueueEvent(debugKey, _priorityNormal, "LianClaw 回复完成", "本轮任务已经完成", "dialog-information", "lianclaw", force)
        }
        if (preset === "lian_error") {
            return _enqueueEvent(debugKey, _priorityHigh, "LianClaw 回复失败", "执行过程中出现错误", "dialog-error", "lianclaw", force)
        }
        if (preset === "network_down") {
            return _enqueueEvent(debugKey, _priorityHigh, "网络已断开", "当前没有可用网络连接", "network-wireless-offline", "connection", force)
        }
        if (preset === "network_up") {
            return _enqueueEvent(debugKey, _priorityNormal, "网络已连接", "Wi-Fi 已连接", "network-wireless", "connection", force)
        }
        if (preset === "bt_up") {
            return _enqueueEvent(debugKey, _priorityNormal, "蓝牙已连接", "设备: WH-1000XM5", "bluetooth-active", "connection", force)
        }
        if (preset === "resource_mem") {
            return _enqueueEvent(debugKey, _priorityHigh, "内存占用过高", "当前内存占用: 94%", "drive-harddisk", "resource", force)
        }
        if (preset === "resource_gpu") {
            return _enqueueEvent(debugKey, _priorityHigh, "GPU 占用过高", "当前 GPU 占用: 97%", "video-display", "resource", force)
        }
        if (preset === "resource_temp") {
            return _enqueueEvent(debugKey, _priorityHigh, "CPU 温度过高", "当前 CPU 温度: 95°C", "temperature-high", "resource", force)
        }
        if (preset === "power_low") {
            return _enqueueEvent(debugKey, _priorityHigh, "电池电量偏低", "当前电量: 15%", "battery-caution", "power", force)
        }
        if (preset === "disk_high") {
            return _enqueueEvent(debugKey, _priorityHigh, "磁盘占用偏高", "当前磁盘占用: 93%", "drive-harddisk", "power", force)
        }

        return _enqueueEvent(debugKey, _priorityHigh, "CPU 占用过高", "当前 CPU 占用: 96%", "utilities-system-monitor", "resource", force)
    }

    function _resourceActive(name) {
        return !!_resourceState[name]
    }

    function _setResourceActive(name, value) {
        if (!!_resourceState[name] === !!value)
            return
        const nextState = Object.assign({}, _resourceState)
        nextState[name] = !!value
        _resourceState = nextState
    }

    function _checkThreshold(name, enabled, value, trigger, recover, summary, body, key, priority, iconName, category) {
        const active = _resourceActive(name)

        if (!enabled) {
            _setResourceActive(name, value >= trigger)
            return
        }

        if (!active && value >= trigger) {
            if (_enqueueEvent(key, priority, summary, body, iconName, category))
                _setResourceActive(name, true)
            return
        }

        if (active && value <= recover)
            _setResourceActive(name, false)
    }

    function _checkNetwork() {
        const connectedNow = !!Network.connected
        const typeNow = String(Network.activeConnectionType || "")

        if (!_netReady) {
            _netReady = true
            _netConnected = connectedNow
            _netType = typeNow
            return
        }

        if (!(DynamicIslandPrefs.connectionEnabled && DynamicIslandPrefs.wifiEventEnabled)) {
            _netConnected = connectedNow
            _netType = typeNow
            return
        }

        if (connectedNow && !_netConnected) {
            _enqueueEvent(
                "network_up",
                _priorityNormal,
                "网络已连接",
                typeNow === "WIFI" ? "Wi-Fi 已连接" : "网络连接已建立",
                "network-wireless",
                "connection"
            )
        } else if (!connectedNow && _netConnected) {
            _enqueueEvent(
                "network_down",
                _priorityHigh,
                "网络已断开",
                "当前没有可用网络连接",
                "network-wireless-offline",
                "connection"
            )
        } else if (connectedNow && _netConnected && typeNow !== _netType) {
            _enqueueEvent(
                "network_switch",
                _priorityNormal,
                "网络类型已切换",
                "当前连接类型: " + (typeNow.length > 0 ? typeNow : "UNKNOWN"),
                "network-transmit-receive",
                "connection"
            )
        }

        _netConnected = connectedNow
        _netType = typeNow
    }

    function _checkBluetooth() {
        const connectedNow = !!Bluetooth.bluetoothConnected
        const deviceNow = String(Bluetooth.connectedDeviceName || "")

        if (!_btReady) {
            _btReady = true
            _btConnected = connectedNow
            _btDevice = deviceNow
            return
        }

        if (!(DynamicIslandPrefs.connectionEnabled && DynamicIslandPrefs.bluetoothEventEnabled)) {
            _btConnected = connectedNow
            _btDevice = deviceNow
            return
        }

        if (connectedNow && !_btConnected) {
            _enqueueEvent(
                "bt_up",
                _priorityNormal,
                "蓝牙已连接",
                deviceNow.length > 0 ? ("设备: " + deviceNow) : "蓝牙设备已连接",
                "bluetooth-active",
                "connection"
            )
        } else if (!connectedNow && _btConnected) {
            _enqueueEvent(
                "bt_down",
                _priorityNormal,
                "蓝牙已断开",
                _btDevice.length > 0 ? ("设备: " + _btDevice) : "蓝牙设备连接已断开",
                "bluetooth-disabled",
                "connection"
            )
        }

        _btConnected = connectedNow
        _btDevice = deviceNow
    }

    function _checkLianClaw() {
        const confirmNow = LianClawState.pendingConfirm !== null
        const formNow = LianClawState.pendingForm !== null
        const phaseNow = String(LianClawState.streamPhase || "")

        if (!_lianReady) {
            _lianReady = true
            _lianConfirmPending = confirmNow
            _lianFormPending = formNow
            _lianPhase = phaseNow
            return
        }

        if (DynamicIslandPrefs.lianclawEnabled && DynamicIslandPrefs.lianclawConfirmEnabled) {
            if (confirmNow && !_lianConfirmPending) {
                _enqueueEvent(
                    "lian_confirm",
                    _priorityCritical,
                    "LianClaw 等待确认",
                    "有工具调用需要人工确认",
                    "dialog-warning",
                    "lianclaw"
                )
            }
        }

        if (DynamicIslandPrefs.lianclawEnabled && DynamicIslandPrefs.lianclawFormEnabled) {
            if (formNow && !_lianFormPending) {
                _enqueueEvent(
                    "lian_form",
                    _priorityCritical,
                    "LianClaw 等待表单",
                    "有参数表单需要填写",
                    "dialog-warning",
                    "lianclaw"
                )
            }
        }

        if (DynamicIslandPrefs.lianclawEnabled && phaseNow !== _lianPhase) {
            const wasWorking = _lianPhase === "accepted"
                || _lianPhase === "processing"
                || _lianPhase === "context_ready"
                || _lianPhase === "llm"

            if (phaseNow === "completed" && wasWorking && DynamicIslandPrefs.lianclawDoneEnabled) {
                _enqueueEvent(
                    "lian_done",
                    _priorityNormal,
                    "LianClaw 回复完成",
                    "本轮任务已经完成",
                    "dialog-information",
                    "lianclaw"
                )
            }

            if (phaseNow === "error" && DynamicIslandPrefs.lianclawFailEnabled) {
                const details = String(LianClawState.lastStreamError || "执行过程中出现错误")
                _enqueueEvent(
                    "lian_error",
                    _priorityHigh,
                    "LianClaw 回复失败",
                    details,
                    "dialog-error",
                    "lianclaw"
                )
            }
        }

        _lianConfirmPending = confirmNow
        _lianFormPending = formNow
        _lianPhase = phaseNow
    }

    function _checkResourcesAndPower() {
        const cpuUsage = Number(SysmonPlugin.cpuUsage || 0)
        const memUsage = Number(SysmonPlugin.ramUsage || 0)
        const gpuUsage = Number(SysmonPlugin.gpuUsage || 0)
        const cpuTemp = Number(SysmonPlugin.coreTemp || 0)
        const gpuTemp = Number(SysmonPlugin.gpuTemp || 0)
        const batteryPercent = Number(SysmonPlugin.batteryPercent || 0)
        const diskUsage = Number(SysmonPlugin.diskUsage || 0)

        if (DynamicIslandPrefs.resourcesEnabled) {
            _checkThreshold(
                "cpuUsageHot",
                DynamicIslandPrefs.cpuUsageEnabled,
                cpuUsage,
                _cpuUsageTrigger,
                _cpuUsageRecover,
                "CPU 占用过高",
                "当前 CPU 占用: " + Math.round(cpuUsage) + "%",
                "cpu_usage_high",
                _priorityHigh,
                "utilities-system-monitor",
                "resource"
            )

            _checkThreshold(
                "memUsageHot",
                DynamicIslandPrefs.memoryUsageEnabled,
                memUsage,
                _memUsageTrigger,
                _memUsageRecover,
                "内存占用过高",
                "当前内存占用: " + Math.round(memUsage) + "%",
                "mem_usage_high",
                _priorityHigh,
                "drive-harddisk",
                "resource"
            )

            _checkThreshold(
                "gpuUsageHot",
                DynamicIslandPrefs.gpuUsageEnabled,
                gpuUsage,
                _gpuUsageTrigger,
                _gpuUsageRecover,
                "GPU 占用过高",
                "当前 GPU 占用: " + Math.round(gpuUsage) + "%",
                "gpu_usage_high",
                _priorityHigh,
                "video-display",
                "resource"
            )

            _checkThreshold(
                "cpuTempHot",
                DynamicIslandPrefs.cpuTempEnabled,
                cpuTemp,
                Number(DynamicIslandPrefs.cpuTempTrigger || 90),
                Number(DynamicIslandPrefs.cpuTempRecover || 84),
                "CPU 温度过高",
                "当前 CPU 温度: " + Math.round(cpuTemp) + "°C",
                "cpu_temp_high",
                _priorityHigh,
                "temperature-high",
                "resource"
            )

            _checkThreshold(
                "gpuTempHot",
                DynamicIslandPrefs.gpuTempEnabled,
                gpuTemp,
                Number(DynamicIslandPrefs.gpuTempTrigger || 88),
                Number(DynamicIslandPrefs.gpuTempRecover || 82),
                "GPU 温度过高",
                "当前 GPU 温度: " + Math.round(gpuTemp) + "°C",
                "gpu_temp_high",
                _priorityHigh,
                "temperature-high",
                "resource"
            )
        }

        if (DynamicIslandPrefs.powerStorageEnabled) {
            const batteryStatus = String(SysmonPlugin.batteryStatus || "").toLowerCase()
            const batteryPresent = batteryStatus !== "" && batteryStatus !== "unknown" && batteryStatus !== "not charging" ? true : (batteryPercent > 0 && batteryPercent <= 100)

            if (batteryPresent) {
                _checkThreshold(
                    "batteryLow",
                    DynamicIslandPrefs.lowBatteryEnabled,
                    100 - batteryPercent,
                    100 - _batteryLowTrigger,
                    100 - _batteryLowRecover,
                    "电池电量偏低",
                    "当前电量: " + Math.round(batteryPercent) + "%",
                    "battery_low",
                    _priorityHigh,
                    "battery-caution",
                    "power"
                )
            }

            _checkThreshold(
                "diskUsageHigh",
                DynamicIslandPrefs.diskUsageEnabled,
                diskUsage,
                _diskUsageTrigger,
                _diskUsageRecover,
                "磁盘占用偏高",
                "当前磁盘占用: " + Math.round(diskUsage) + "%",
                "disk_usage_high",
                _priorityHigh,
                "drive-harddisk",
                "power"
            )
        }
    }

    function _bootstrap() {
        _netReady = false
        _btReady = false
        _lianReady = false
        _resourceState = ({})

        _checkNetwork()
        _checkBluetooth()
        _checkLianClaw()
        _checkResourcesAndPower()

        _booted = true
        _log("booted")
        bootGraceTimer.restart()
    }

    Connections {
        target: Network
        ignoreUnknownSignals: true
        function onConnectedChanged() { root._checkNetwork() }
        function onActiveConnectionTypeChanged() { root._checkNetwork() }
        function onActiveConnectionChanged() { root._checkNetwork() }
    }

    Connections {
        target: Bluetooth
        ignoreUnknownSignals: true
        function onBluetoothConnectedChanged() { root._checkBluetooth() }
        function onConnectedDeviceNameChanged() { root._checkBluetooth() }
    }

    Connections {
        target: LianClawState
        ignoreUnknownSignals: true
        function onPendingConfirmChanged() { root._checkLianClaw() }
        function onPendingFormChanged() { root._checkLianClaw() }
        function onStreamPhaseChanged() { root._checkLianClaw() }
    }

    Timer {
        id: resourcePoll
        interval: 1500
        repeat: true
        running: root._booted
        onTriggered: root._checkResourcesAndPower()
    }

    Timer {
        id: dispatchTimer
        interval: 180
        repeat: false
        running: false
        onTriggered: root._dispatchNext()
    }

    Timer {
        id: bootGraceTimer
        interval: 6000
        repeat: false
        running: false
        onTriggered: {
            root._emitReady = true
            root._log("event emission enabled")
        }
    }

    Component.onCompleted: _bootstrap()
}
