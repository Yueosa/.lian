// PowerBar — 电源（IPC power），从 rightrail 正中滑出一张焊轨卡
//
// 壳/圆角/耳朵全部交给 RailContainer（edge=right：靠轨那侧直角，外侧两角
// 圆角）。HTML 稿把左右圆角画反了，这里不要再手动画壳。
//
// 互斥组 "right"：和 V / N / X 抢右边这一列。
// lock 一下就走；logout / shutdown / reboot 两次确认（变红 = 预备）。
// 预备期间 ↑↓/Esc 只取消预备。头像上的 Enter 等于 Esc。

import QtQuick
import Quickshell
import qs.Components
import qs.data.state

RailPage {
    id: root

    edge: "right"
    valign: "center"
    shellNamespace: "qsl-power"
    panelGroup: "right"
    containerWidth: 88

    order: ["power"]
    page: "power"
    pages: ({
        power: { title: "电源", containers: [powerCard] }
    })

    function openWindow() { openPage("power") }

    function escPressed() {
        if (powerState.armed.length > 0)
            powerState.disarm()
        else
            closeWindow()
    }

    onOpenChanged: {
        if (open)
            powerState.reset()
    }

    QtObject {
        id: powerState

        property int current: 2
        property string armed: ""
        property int focusTick: 0

        readonly property string userName: Quickshell.env("USER") || "user"
        readonly property string avatarLetter: userName.length > 0
            ? userName.charAt(0).toUpperCase() : "?"

        function reset() {
            current = 2
            armed = ""
            focusTick += 1
        }

        function disarm() { armed = "" }

        function move(d) {
            disarm()
            current = (current + d + 5) % 5
        }

        function activate() {
            if (current === 2) {
                if (armed.length > 0) {
                    disarm()
                    return
                }
                root.closeWindow()
                return
            }
            const id = current === 0 ? "logout"
                : (current === 1 ? "lock"
                    : (current === 3 ? "shutdown" : "reboot"))
            if (id === "lock") {
                root.closeWindow()
                Qt.callLater(() =>
                    Quickshell.execDetached(["qs", "ipc", "call", "lock", "lock"]))
                return
            }
            if (armed === id) {
                root.closeWindow()
                Qt.callLater(() => powerState._run(id))
                return
            }
            armed = id
        }

        function _run(id) {
            if (id === "logout") {
                Quickshell.execDetached([
                    "bash", "-lc",
                    "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"
                ])
                return
            }
            if (id === "shutdown") {
                Quickshell.execDetached(["systemctl", "poweroff"])
                return
            }
            if (id === "reboot")
                Quickshell.execDetached(["systemctl", "reboot"])
        }
    }

    Component {
        id: powerCard
        PowerCard { sharedState: powerState }
    }
}
