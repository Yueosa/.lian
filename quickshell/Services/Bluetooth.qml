pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool bluetoothEnabled: false
    property bool bluetoothToggling: false
    property bool bluetoothToggleTarget: false
    property int bluetoothToggleRetries: 0
    property bool bluetoothConnected: false
    property string connectedDeviceName: ""

    property bool scanActive: false
    property bool scanBusy: false
    property bool scanTargetActive: false

    property var connectedDevices: []
    property var pairedDevices: []
    property var scannedDevices: []
    property var deviceInfoByMac: ({})

    property string lastError: ""
    property string detailTargetMac: ""
    property string deviceActionMac: ""

    property var _connectedBuffer: []
    property var _pairedBuffer: []
    property var _scannedBuffer: []

    function refresh() {
        statusPoller.running = true;
        devicesPoller.running = true;
        if (root.bluetoothEnabled && root.scanActive)
            scannedPoller.running = true;
    }

    function clearTransientState() {
        root.scanActive = false;
        root.scanBusy = false;
        root.scanTargetActive = false;
        root.connectedDevices = [];
        root.pairedDevices = [];
        root.scannedDevices = [];
        root._connectedBuffer = [];
        root._pairedBuffer = [];
        root._scannedBuffer = [];
        scanAutoStopTimer.stop();
        scanTickTimer.stop();
    }

    function setError(message) {
        if (!message || message.length === 0)
            return;
        root.lastError = message;
        errorClearTimer.restart();
    }

    function startScan() {
        if (!root.bluetoothEnabled || root.scanActive || root.scanBusy)
            return;

        root.lastError = "";
        root.scanBusy = true;
        root.scanTargetActive = true;
        scanControlProc.exec(["bash", "-c", 'printf "scan on\\nquit\\n" | bluetoothctl >/dev/null 2>&1']);
    }

    function stopScan() {
        if (!root.scanActive && !root.scanBusy)
            return;

        root.scanBusy = true;
        root.scanTargetActive = false;
        scanControlProc.exec(["bash", "-c", 'printf "scan off\\nquit\\n" | bluetoothctl >/dev/null 2>&1']);
    }

    function toggleBluetooth() {
        if (root.bluetoothToggling)
            return;

        root.lastError = "";
        root.bluetoothToggleTarget = !root.bluetoothEnabled;
        root.bluetoothToggleRetries = 0;
        root.bluetoothToggling = true;
        togglePowerProc.exec(["bash", "-c", root.bluetoothToggleTarget ? "bluetoothctl power on" : "bluetoothctl power off"]);
    }

    function connectDevice(mac) {
        if (!mac)
            return;
        root.deviceActionMac = mac;
        connectProc.exec(["bluetoothctl", "connect", mac]);
    }

    function disconnectDevice(mac) {
        if (!mac)
            return;
        root.deviceActionMac = mac;
        disconnectProc.exec(["bluetoothctl", "disconnect", mac]);
    }

    function requestDeviceInfo(mac) {
        if (!mac)
            return;
        root.detailTargetMac = mac;
        detailProc.exec(["bluetoothctl", "info", mac]);
    }

    function parseBool(value) {
        return value && value.toLowerCase() === "yes";
    }

    function applyDeviceInfo(mac, rawText) {
        if (!mac)
            return;

        const info = root.deviceInfoByMac[mac] ? Object.assign({}, root.deviceInfoByMac[mac]) : {
            mac: mac
        };
        const lines = rawText.split("\n");

        for (const line of lines) {
            const trimmed = line.trim();
            if (trimmed.length === 0 || trimmed.startsWith("Device "))
                continue;

            const separator = trimmed.indexOf(":");
            if (separator <= 0)
                continue;

            const key = trimmed.substring(0, separator).trim();
            const value = trimmed.substring(separator + 1).trim();

            if (key === "Name")
                info.name = value;
            else if (key === "Alias")
                info.alias = value;
            else if (key === "Icon")
                info.icon = value;
            else if (key === "Class")
                info.deviceClass = value;
            else if (key === "Paired")
                info.paired = root.parseBool(value);
            else if (key === "Trusted")
                info.trusted = root.parseBool(value);
            else if (key === "Blocked")
                info.blocked = root.parseBool(value);
            else if (key === "Connected")
                info.connected = root.parseBool(value);
            else if (key === "RSSI")
                info.rssi = value;
            else if (key === "Battery Percentage")
                info.battery = value;
        }

        root.deviceInfoByMac = Object.assign({}, root.deviceInfoByMac, {
            [mac]: info
        });
    }

    Process {
        id: statusPoller
        command: ["bash", "-c", `
            BT_PWR=$(bluetoothctl show 2>/dev/null | grep -c 'Powered: yes' || echo 0)
            if [ "$BT_PWR" -gt 0 ]; then
                BT_CONN_LINE=$(bluetoothctl devices Connected 2>/dev/null | head -1)
                BT_CONN_COUNT=$(bluetoothctl devices Connected 2>/dev/null | wc -l)
                BT_CONN_NAME=$(echo "$BT_CONN_LINE" | cut -d' ' -f3-)
                [ "$BT_CONN_COUNT" -gt 0 ] && echo "BT:connected:$BT_CONN_NAME" || echo "BT:on:"
            else
                echo "BT:off:"
            fi
        `]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let data = line.trim();
                if (!data.startsWith("BT:"))
                    return;

                let rest = data.substring(3);
                let colon = rest.indexOf(":");
                let state = colon !== -1 ? rest.substring(0, colon) : rest;
                let name = colon !== -1 ? rest.substring(colon + 1) : "";
                root.bluetoothEnabled = (state !== "off");
                root.bluetoothConnected = (state === "connected");
                root.connectedDeviceName = name;

                if (!root.bluetoothEnabled)
                    root.clearTransientState();

                if (root.bluetoothToggling) {
                    if (root.bluetoothEnabled === root.bluetoothToggleTarget) {
                        root.bluetoothToggling = false;
                        root.bluetoothToggleRetries = 0;
                    } else if (root.bluetoothToggleRetries < 8) {
                        root.bluetoothToggleRetries += 1;
                        toggleRetryTimer.restart();
                    } else {
                        root.bluetoothToggling = false;
                        root.setError(root.bluetoothToggleTarget ? "无法开启蓝牙" : "无法关闭蓝牙");
                    }
                }
            }
        }
    }

    Process {
        id: togglePowerProc
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.bluetoothToggling = false;
                root.setError(root.bluetoothToggleTarget ? "无法开启蓝牙" : "无法关闭蓝牙");
            }
            root.refresh();
        }
    }

    Process {
        id: devicesPoller
        command: ["bash", "-c", `
            PAIRED=$(bluetoothctl devices Paired 2>/dev/null)
            CONNECTED=$(bluetoothctl devices Connected 2>/dev/null)
            echo "$CONNECTED" | while IFS= read -r line; do
                [ -z "$line" ] && continue
                MAC=$(echo "$line" | awk '{print $2}')
                NAME=$(echo "$line" | cut -d' ' -f3-)
                printf "CONNECTED\\t%s\\t%s\\n" "$MAC" "$NAME"
            done
            echo "$PAIRED" | while IFS= read -r line; do
                [ -z "$line" ] && continue
                MAC=$(echo "$line" | awk '{print $2}')
                NAME=$(echo "$line" | cut -d' ' -f3-)
                echo "$CONNECTED" | grep -q "$MAC" && continue
                printf "PAIRED\\t%s\\t%s\\n" "$MAC" "$NAME"
            done
            echo "DEVICES_END"
        `]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let data = line.trim();
                if (data === "DEVICES_END") {
                    root.connectedDevices = root._connectedBuffer.slice();
                    root.pairedDevices = root._pairedBuffer.slice();
                    root._connectedBuffer = [];
                    root._pairedBuffer = [];
                    return;
                }

                if (!data.startsWith("CONNECTED\t") && !data.startsWith("PAIRED\t"))
                    return;

                const fields = data.split("\t");
                if (fields.length < 3)
                    return;

                const kind = fields[0];
                const mac = fields[1];
                const name = fields.slice(2).join("\t");
                const item = {
                    mac: mac,
                    connected: kind === "CONNECTED",
                    name: name,
                    paired: true
                };

                if (kind === "CONNECTED")
                    root._connectedBuffer.push(item);
                else
                    root._pairedBuffer.push(item);
            }
        }
    }

    Process {
        id: scannedPoller
        command: ["bash", "-c", `
            ALL=$(bluetoothctl devices 2>/dev/null)
            PAIRED=$(bluetoothctl devices Paired 2>/dev/null)
            CONNECTED=$(bluetoothctl devices Connected 2>/dev/null)
            echo "$ALL" | while IFS= read -r line; do
                [ -z "$line" ] && continue
                MAC=$(echo "$line" | awk '{print $2}')
                NAME=$(echo "$line" | cut -d' ' -f3-)
                echo "$PAIRED" | grep -q "$MAC" && continue
                if echo "$CONNECTED" | grep -q "$MAC"; then
                    printf "SCAN\\t%s\\t1\\t%s\\n" "$MAC" "$NAME"
                else
                    printf "SCAN\\t%s\\t0\\t%s\\n" "$MAC" "$NAME"
                fi
            done
            echo "SCAN_END"
        `]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const data = line.trim();
                if (data === "SCAN_END") {
                    root.scannedDevices = root._scannedBuffer.slice();
                    root._scannedBuffer = [];
                    return;
                }

                if (!data.startsWith("SCAN\t"))
                    return;

                const fields = data.split("\t");
                if (fields.length < 4)
                    return;

                const mac = fields[1];
                const connected = fields[2] === "1";
                const name = fields.slice(3).join("\t");
                root._scannedBuffer.push({
                    mac: mac,
                    connected: connected,
                    name: name,
                    paired: false
                });
            }
        }
    }

    Process {
        id: scanControlProc
        onExited: exitCode => {
            root.scanBusy = false;
            if (exitCode !== 0) {
                root.setError(root.scanTargetActive ? "开始扫描失败" : "停止扫描失败");
                return;
            }

            root.scanActive = root.scanTargetActive;
            if (root.scanActive) {
                scanAutoStopTimer.restart();
                scanTickTimer.start();
                scannedPoller.running = true;
            } else {
                scanAutoStopTimer.stop();
                scanTickTimer.stop();
            }
        }
    }

    Process {
        id: connectProc
        onExited: exitCode => {
            if (exitCode !== 0 && root.deviceActionMac)
                root.setError("连接失败: " + root.deviceActionMac);
            root.deviceActionMac = "";
            debounce.start();
        }
    }

    Process {
        id: disconnectProc
        onExited: exitCode => {
            if (exitCode !== 0 && root.deviceActionMac)
                root.setError("断开失败: " + root.deviceActionMac);
            root.deviceActionMac = "";
            debounce.start();
        }
    }

    Process {
        id: detailProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.applyDeviceInfo(root.detailTargetMac, text);
            }
        }
        onExited: {
            root.detailTargetMac = "";
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: debounce
        interval: 1500
        running: false
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: toggleRetryTimer
        interval: 300
        repeat: false
        onTriggered: statusPoller.running = true
    }

    Timer {
        id: scanTickTimer
        interval: 2000
        repeat: true
        onTriggered: {
            if (root.bluetoothEnabled && root.scanActive)
                scannedPoller.running = true;
        }
    }

    Timer {
        id: scanAutoStopTimer
        interval: 12000
        repeat: false
        onTriggered: root.stopScan()
    }

    Timer {
        id: errorClearTimer
        interval: 5000
        repeat: false
        onTriggered: root.lastError = ""
    }

    Component.onCompleted: root.refresh()
}
