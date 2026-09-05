pragma Singleton

// ============================================================
// systemd --user 单元状态与启停 — Systemd
// ============================================================
// 只管**用户**单元：--user 的 start/stop 不过 polkit，不会弹密码框。
// 系统单元要 root，那是另一回事，这里不碰。
//
// 查状态用 `systemctl --user is-active u1 u2 …`：一行一个、顺序和入参一致
// （不存在的单元也占一行，值是 inactive），比 `show -p ActiveState` 好解析。
//
// **不空转轮询**。systemd 不给我们推变化（订阅要走 D-Bus，为三个磁贴不值得），
// 所以只在两个时机查：
//   · 面板开窗（active 置真）
//   · 自己刚 start/stop 完 —— 那一下是个过程（activating/deactivating），
//     所以补几拍：达到目标态就提前收手，否则最多补到 ~2.4 秒
// 关窗即停：面板不开着的时候，谁也不看这些状态。
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // 要盯的单元名（面板把所有服务磁贴的 units 摊平交上来）
    property var units: []
    // 面板开着才查
    property bool active: false

    // 单元名 → ActiveState 字符串（"active" / "inactive" / "failed" / "activating" …）
    property var states: ({})
    // states 是 var，内容改了不发通知，靠这个数推动绑定
    property int revision: 0
    property string lastError: ""

    readonly property bool busy: probe.running || op.running

    function stateOf(unit) {
        const s = states[String(unit || "")]
        return s === undefined ? "" : s
    }

    function isActive(unit) {
        return stateOf(unit) === "active"
    }

    // Repeater 把 JS 数组包成 QVariantList 之后 Array.isArray 是 false。
    // 服务区三个磁贴因此全走空列表 → 永远「已停止」。按 length 抄一份就行
    function _asList(x) {
        if (!x)
            return []
        if (Array.isArray(x))
            return x
        const n = x.length
        if (typeof n !== "number" || n <= 0)
            return []
        const out = []
        for (let i = 0; i < n; i++)
            out.push(x[i])
        return out
    }

    // 一格磁贴可以管好几个单元（剪贴板记录就是两个）：**全开才算开**。
    // 半开半关按"关"算，于是点一下是把整组拉齐到开，符合直觉
    function groupActive(list) {
        const a = _asList(list)
        if (a.length === 0)
            return false
        for (let i = 0; i < a.length; i++) {
            if (!isActive(a[i]))
                return false
        }
        return true
    }

    // 组里有单元正在变（刚点完那一拍）：磁贴据此显示"切换中"
    function groupBusy(list) {
        const a = _asList(list)
        for (let i = 0; i < a.length; i++) {
            const s = stateOf(a[i])
            if (s === "activating" || s === "deactivating")
                return true
        }
        return false
    }

    function toggleGroup(list) {
        setGroup(list, !groupActive(list))
    }

    function setGroup(list, on) {
        const a = _asList(list)
        if (a.length === 0 || op.running)
            return
        _wantList = a
        _wantOn = !!on
        lastError = ""
        _opCmd = ["/usr/bin/systemctl", "--user", on ? "start" : "stop"].concat(a)
        op.running = false
        op.running = true
    }

    function refresh() {
        if (!active)
            return
        const list = _asList(units)
        if (list.length === 0)
            return
        if (probe.running) {
            _probeAgain = true
            return
        }
        _probeUnits = list.slice()
        _probeCmd = ["/usr/bin/systemctl", "--user", "is-active"].concat(_probeUnits)
        // 先关再开：running 已是 true 时再赋 true 不会重跑（Lianwall.refresh 同注释）
        probe.running = false
        probe.running = true
    }

    onActiveChanged: {
        if (active) {
            refresh()
        } else {
            settle.stop()
            _probeAgain = false
        }
    }

    // 单元清单换了（磁贴清单重载）立刻补一次，不然新磁贴一直是未知态
    onUnitsChanged: refresh()

    // ---- 内部 ----

    // 探测时的入参快照：解析靠"输出第 i 行 = 入参第 i 个"，而 units 可能在
    // 进程跑着的时候被换掉（tiles.json 存盘），拿当时那份对齐才不会错位
    property var _probeUnits: []
    property var _probeCmd: ["/usr/bin/systemctl", "--user", "is-active"]
    property var _opCmd: ["/usr/bin/systemctl", "--user", "is-active"]
    property bool _probeAgain: false
    property var _wantList: []
    property bool _wantOn: false

    Process {
        id: probe
        command: root._probeCmd
        stdout: StdioCollector {
            onStreamFinished: root._applyProbe(this.text)
        }
        onExited: {
            // is-active 只要有一个不是 active 就给非零退出码，这不是错误
            if (root._probeAgain) {
                root._probeAgain = false
                root.refresh()
            }
        }
    }

    function _applyProbe(text) {
        const raw = String(text || "").trim()
        const lines = raw.length === 0 ? [] : raw.split("\n")
        const list = root._asList(_probeUnits)
        if (list.length === 0)
            return
        const next = {}
        for (let i = 0; i < list.length; i++)
            next[list[i]] = i < lines.length ? lines[i].trim() : ""
        states = next
        revision++
        if (lines.length !== list.length)
            lastError = "is-active 输出对不上（" + lines.length
                + " 行 / " + list.length + " 个单元）"
        else if (String(lastError).indexOf("is-active 输出对不上") === 0)
            lastError = ""
    }

    Process {
        id: op
        command: root._opCmd
        stderr: StdioCollector {
            onStreamFinished: {
                const t = String(this.text || "").trim()
                if (t.length > 0)
                    root.lastError = t
            }
        }
        onExited: (code) => {
            // 失败也要查一次：真实状态才是唯一的真相，不猜
            settle.left = 6
            settle.restart()
            root.refresh()
        }
    }

    // 启停后的补查：过程态要几百毫秒才落定
    Timer {
        id: settle
        property int left: 0
        interval: 400
        repeat: true
        onTriggered: {
            left--
            root.refresh()
            // 到位就别再敲了
            if (left <= 0 || root.groupActive(root._wantList) === root._wantOn)
                stop()
        }
    }
}
