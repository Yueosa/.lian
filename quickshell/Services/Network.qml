pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool connected: activeConnectionType != ""
    property string activeConnection: "Disconnected"
    property string activeConnectionType: ""
    property string ethernetConnection: ""
    property int signalStrength: 100

    property bool wifiEnabled: false
    property bool wifiToggling: false
    property bool wifiToggleTarget: false
    property int wifiToggleRetries: 0
    property bool wifiScanning: false
    property bool wifiConnecting: connectProc.running
    property string wifiLastError: ""
    property var wifiConnectTarget: null
    property var wifiNetworks: []
    property var savedWifiConnectionsWithSecrets: []
    readonly property bool passwordPromptActive: wifiNetworks.some(network => network.askingPassword)
    readonly property var activeWifi: wifiNetworks.find(n => n.active) || null
    readonly property var friendlyWifiNetworks: wifiNetworks.slice().sort((a, b) => {
        if (a.active && !b.active)
            return -1;
        if (!a.active && b.active)
            return 1;
        return b.strength - a.strength;
    })

    function refresh() {
        refreshProcess.running = true;
        signalProcess.running = true;
        wifiStatusProcess.running = true;
        savedConnectionsProcess.running = true;
        if (!passwordPromptActive)
            getNetworks.running = true;
    }

    function enableWifi(enabled = true) {
        if (root.wifiToggling)
            return;

        root.wifiLastError = "";
        root.wifiToggleTarget = enabled;
        root.wifiToggleRetries = 0;
        root.wifiToggling = true;
        enableWifiProc.exec(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
    }

    function toggleWifi() {
        enableWifi(!wifiEnabled);
    }

    function rescanWifi() {
        if (!wifiEnabled || passwordPromptActive)
            return;
        wifiScanning = true;
        rescanProcess.running = true;
    }

    function connectToWifiNetwork(accessPoint) {
        if (!accessPoint)
            return;

        if (accessPoint.active) {
            disconnectWifiNetwork();
            return;
        }

        if (accessPoint.isSecure && !hasSavedSecret(accessPoint.ssid)) {
            for (const network of root.wifiNetworks)
                network.askingPassword = network === accessPoint;
            accessPoint.askingPassword = true;
            root.wifiConnectTarget = null;
            return;
        }

        accessPoint.askingPassword = false;
        root.wifiConnectTarget = accessPoint;
        connectProc.exec(["nmcli", "dev", "wifi", "connect", accessPoint.ssid]);
    }

    function hasSavedSecret(ssid) {
        return root.savedWifiConnectionsWithSecrets.indexOf(ssid) !== -1;
    }

    function disconnectWifiNetwork() {
        if (activeWifi)
            disconnectProc.exec(["nmcli", "connection", "down", activeWifi.ssid]);
    }

    function changePassword(network, password) {
        if (!network)
            return;

        network.askingPassword = false;
        root.wifiConnectTarget = network;
        changePasswordProc.exec({
            "environment": {
                "PASSWORD": password,
                "SSID": network.ssid
            },
            "command": ["bash", "-c", 'nmcli dev wifi connect "$SSID" password "$PASSWORD"']
        });
    }

    function setWifiError(message) {
        if (!message || message.length === 0)
            return;
        root.wifiLastError = message;
        wifiErrorClearTimer.restart();
    }

    function openPublicWifiPortal() {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"]);
    }

    Process {
        id: refreshProcess
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "con", "show", "--active"]

        stdout: StdioCollector {
            onStreamFinished: () => {
                if (this.text.trim() === "") {
                    root.activeConnectionType = ""
                    root.activeConnection = "Disconnected"
                    root.ethernetConnection = ""
                    root.signalStrength = 0
                    return
                }

                const interfaces = this.text.split("\n").filter(l => l.trim() !== "");
                let ethConn = "";
                let wifiConn = "";

                for (const iface of interfaces) {
                    const fields = iface.split(":");
                    if (fields.length < 2) continue;
                    const type = refreshProcess.getConnectionType(fields[1]);
                    if (type === "ETHERNET" && !ethConn) ethConn = fields[0];
                    else if (type === "WIFI" && !wifiConn) wifiConn = fields[0];
                }

                root.ethernetConnection = ethConn;

                if (ethConn) {
                    root.activeConnectionType = "ETHERNET";
                    root.activeConnection = ethConn;
                } else if (wifiConn) {
                    root.activeConnectionType = "WIFI";
                    root.activeConnection = wifiConn;
                } else {
                    root.activeConnectionType = "";
                    root.activeConnection = "Disconnected";
                }
            }
        }

        function getConnectionType(nmcliOutput) {
            if (nmcliOutput.includes("ethernet")) return "ETHERNET";
            else if (nmcliOutput.includes("wireless")) return "WIFI";
            return "";
        }
    }

    Process {
        id: signalProcess
        command: ["sh", "-c", "nmcli -t -f IN-USE,SIGNAL dev wifi | grep '^\\*' | cut -d':' -f2"]
        stdout: StdioCollector {
            onStreamFinished: () => {
                const val = parseInt(this.text.trim());
                if (!isNaN(val)) {
                    root.signalStrength = val;
                }
            }
        }
    }

    Process {
        id: enableWifiProc
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.wifiToggling = false;
                root.setWifiError(root.wifiToggleTarget ? "无法开启 Wi-Fi" : "无法关闭 Wi-Fi");
            }
            root.refresh();
        }
    }

    Process {
        id: rescanProcess
        command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiScanning = false;
                if (!root.passwordPromptActive)
                    getNetworks.running = true;
            }
        }
        onExited: {
            root.wifiScanning = false;
            if (!root.passwordPromptActive)
                getNetworks.running = true;
        }
    }

    Process {
        id: connectProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: SplitParser {
            onRead: {
                if (!root.passwordPromptActive)
                    getNetworks.running = true;
            }
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.includes("Secrets were required") && root.wifiConnectTarget) {
                    root.wifiConnectTarget.askingPassword = true;
                    root.wifiLastError = "";
                }
            }
        }
        onExited: exitCode => {
            if (root.wifiConnectTarget)
                root.wifiConnectTarget.askingPassword = exitCode !== 0;
            if (exitCode !== 0 && root.wifiConnectTarget && !root.wifiConnectTarget.askingPassword)
                root.setWifiError("连接失败: " + root.wifiConnectTarget.ssid);
            root.wifiConnectTarget = null;
            root.refresh();
        }
    }

    Process {
        id: disconnectProc
        stdout: SplitParser {
            onRead: {
                if (!root.passwordPromptActive)
                    getNetworks.running = true;
            }
        }
        onExited: root.refresh()
    }

    Process {
        id: changePasswordProc
        onExited: exitCode => {
            if (root.wifiConnectTarget)
                root.wifiConnectTarget.askingPassword = exitCode !== 0;
            if (exitCode !== 0 && root.wifiConnectTarget)
                root.setWifiError("连接失败: " + root.wifiConnectTarget.ssid);
            root.wifiConnectTarget = null;
            root.refresh();
        }
    }

    Process {
        id: wifiStatusProcess
        command: ["nmcli", "radio", "wifi"]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled";

                if (root.wifiToggling) {
                    if (root.wifiEnabled === root.wifiToggleTarget) {
                        root.wifiToggling = false;
                        root.wifiToggleRetries = 0;
                        root.wifiLastError = "";
                        if (root.wifiEnabled && !root.passwordPromptActive)
                            root.rescanWifi();
                    } else if (root.wifiToggleRetries < 8) {
                        root.wifiToggleRetries += 1;
                        wifiToggleRetryTimer.restart();
                    } else {
                        root.wifiToggling = false;
                        root.setWifiError(root.wifiToggleTarget ? "开启 Wi-Fi 超时" : "关闭 Wi-Fi 超时");
                    }
                }

                if (!root.wifiEnabled)
                    root.clearWifiNetworks();
            }
        }
    }

    Timer {
        id: wifiToggleRetryTimer
        interval: 300
        repeat: false
        onTriggered: wifiStatusProcess.running = true
    }

    Timer {
        id: wifiErrorClearTimer
        interval: 5000
        repeat: false
        onTriggered: root.wifiLastError = ""
    }

    Process {
        id: savedConnectionsProcess
        command: ["bash", "-c", 'nmcli -t -f NAME,TYPE connection show | while IFS=: read -r name type; do case "$type" in *wireless*|*wifi*) ssid="$(nmcli -g 802-11-wireless.ssid connection show "$name" 2>/dev/null | head -n1)"; psk="$(nmcli -s -g 802-11-wireless-security.psk connection show "$name" 2>/dev/null | head -n1)"; [ -n "$psk" ] && printf "%s\\n" "${ssid:-$name}";; esac; done']
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.passwordPromptActive)
                    return;

                const rawText = text.trim();
                if (rawText.length === 0) {
                    root.savedWifiConnectionsWithSecrets = [];
                    return;
                }

                const placeholder = "STRINGWHICHHOPEFULLYWONTBEUSED";
                const escapedColon = new RegExp("\\\\:", "g");
                const placeholderColon = new RegExp(placeholder, "g");
                root.savedWifiConnectionsWithSecrets = rawText.split("\n").map(line => line.replace(escapedColon, placeholder).replace(placeholderColon, ":")).filter(ssid => ssid.length > 0);
            }
        }
    }

    Process {
        id: getNetworks
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                const rawText = text.trim();
                if (rawText.length === 0) {
                    root.clearWifiNetworks();
                    return;
                }

                const placeholder = "STRINGWHICHHOPEFULLYWONTBEUSED";
                const escapedColon = new RegExp("\\\\:", "g");
                const placeholderColon = new RegExp(placeholder, "g");
                const allNetworks = rawText.split("\n").map(line => {
                    const fields = line.replace(escapedColon, placeholder).split(":");
                    return {
                        active: fields[0] === "yes",
                        strength: parseInt(fields[1]) || 0,
                        frequency: parseInt(fields[2]) || 0,
                        ssid: fields[3] || "",
                        bssid: fields.length > 4 && fields[4] ? fields[4].replace(placeholderColon, ":") : "",
                        security: fields[5] || ""
                    };
                }).filter(network => network.ssid.length > 0);

                const networkMap = new Map();
                for (const network of allNetworks) {
                    const existing = networkMap.get(network.ssid);
                    if (!existing || (network.active && !existing.active) || (!network.active && !existing.active && network.strength > existing.strength))
                        networkMap.set(network.ssid, network);
                }

                root.syncWifiNetworks(Array.from(networkMap.values()));
            }
        }
    }

    function clearWifiNetworks() {
        const networks = root.wifiNetworks.slice();
        while (networks.length > 0)
            networks.splice(0, 1)[0].destroy();
        root.wifiNetworks = [];
    }

    function syncWifiNetworks(nextNetworks) {
        const networks = root.wifiNetworks.slice();
        const destroyed = networks.filter(existing => !nextNetworks.find(next => next.frequency === existing.frequency && next.ssid === existing.ssid && next.bssid === existing.bssid));
        for (const network of destroyed)
            networks.splice(networks.indexOf(network), 1)[0].destroy();

        for (const nextNetwork of nextNetworks) {
            const match = networks.find(existing => nextNetwork.frequency === existing.frequency && nextNetwork.ssid === existing.ssid && nextNetwork.bssid === existing.bssid);
            if (match)
                match.lastIpcObject = nextNetwork;
            else
                networks.push(wifiAccessPointComponent.createObject(root, {
                    lastIpcObject: nextNetwork
                }));
        }

        root.wifiNetworks = networks;
    }

    Component {
        id: wifiAccessPointComponent

        QtObject {
            required property var lastIpcObject

            readonly property string ssid: lastIpcObject && lastIpcObject.ssid ? lastIpcObject.ssid : ""
            readonly property string bssid: lastIpcObject && lastIpcObject.bssid ? lastIpcObject.bssid : ""
            readonly property int strength: lastIpcObject && lastIpcObject.strength ? lastIpcObject.strength : 0
            readonly property int frequency: lastIpcObject && lastIpcObject.frequency ? lastIpcObject.frequency : 0
            readonly property bool active: lastIpcObject && lastIpcObject.active
            readonly property string security: lastIpcObject && lastIpcObject.security ? lastIpcObject.security : ""
            readonly property bool isSecure: security.length > 0

            property bool askingPassword: false
        }
    }

    Process {
        id: monitorProcess
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: root.refresh()
        }
    }

    Component.onCompleted: root.refresh()
}
