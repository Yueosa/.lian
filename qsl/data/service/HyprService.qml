pragma Singleton

// ============================================================
// Hyprland 门面 — HyprService
// ============================================================
// 为什么要有这一层（第 9 轮架构审计的头号结论）：本壳里每个外部系统都有一个
// 服务单例收着——NM→Network、BlueZ→Bluetooth、Pipewire→Volume、MPRIS→Media、
// systemd→Systemd、lianwall→Lianwall。唯独 Hyprland 没有，于是它被 5 个文件
// 跨 3 层直接消费：切换器、工作区指示器、活动窗口药丸各自遍历一遍活对象，而
// 派发焦点的那几个函数寄居在 data/state/Island.qml 里。
//
// 最能说明问题的是启动器：它要拉起一个应用，得去调 `Island.hyprEval()`。启动器
// 和岛没有半点关系，它够到那个函数只是因为没有别的地方能拿到这个能力。
//
// **名字不叫 Hyprland。** 那是 `Quickshell.Hyprland` 导出的单例名，一个文件同时
// import 两边就会撞。后缀沿用 TrayService。
//
// **派发一律走 hyprctl eval + Lua，不用 `Hyprland.dispatch`。** 本机 hypr 配置是
// Lua 的，`dispatch("focuswindow …")` 会被翻成 `hl.dispatch(focuswindow …)`——
// 参数没引号，Lua 当场语法错。这坑踩过两次（Island 一次、Launcher 一次，两处
// 注释互相引用「同病」），收进来之后只留一条路。
//
// **活对象一律当不透明句柄。** 对外给的是 `windowTitle(win)` / `windowIcon(win)`
// 这样的取值函数，不是拍好的快照——快照会死，而标题和图标要跟着窗口实时变。
// UI 只负责把句柄原样传回来。
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // 壳可能跑在别的合成器下（或者裸跑测试）。要派发的调用点先问这个——
    // 启动器就是靠它在 hl.exec_cmd 和 execDetached 之间选路。
    readonly property bool available:
        String(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "").length > 0

    // ============================================================
    // 工作区
    // ============================================================

    // 直接转发 Quickshell 的 ObjectModel。它本来就是增量模型（不是每次求值都
    // 新建的数组），Repeater 绑它不会整树重建，所以没有理由再包一层。
    readonly property var workspaces: Hyprland.workspaces
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property bool multiMonitor: Hyprland.monitors.count > 1

    // id 有三个可能的出处，逐个退。返回 -1 表示问不出来。
    function workspaceId(ws) {
        if (!ws)
            return -1
        if (ws.id !== undefined && ws.id !== null)
            return Number(ws.id)
        if (ws.lastIpcObject && ws.lastIpcObject.id !== undefined
                && ws.lastIpcObject.id !== null)
            return Number(ws.lastIpcObject.id)
        return -1
    }

    readonly property int focusedWorkspaceId: workspaceId(focusedWorkspace)

    // 指示器上显示的短标签。优先取 name 里的数字——具名工作区（"3:web"）要显示
    // 3 而不是整串。
    function workspaceLabel(ws) {
        if (!ws)
            return "-"
        if (ws.name !== undefined && ws.name !== null) {
            const digits = String(ws.name).match(/\d+/)
            if (digits && digits.length > 0)
                return digits[0]
        }
        const id = workspaceId(ws)
        return id >= 0 ? String(id) : "-"
    }

    function workspaceMonitorName(ws) {
        return (ws && ws.monitor && ws.monitor.name) ? String(ws.monitor.name) : ""
    }

    function workspaceFocused(ws) {
        return !!(ws && ws.focused)
    }

    function workspaceWindowCount(ws) {
        return (ws && ws.toplevels) ? ws.toplevels.count : 0
    }

    // 点工作区指示器：对象自己有 activate()，不必绕 hyprctl
    function activateWorkspace(ws) {
        if (ws && ws.activate)
            ws.activate()
    }

    // ============================================================
    // 窗口取值
    // ============================================================

    function windowTitle(win) {
        if (!win)
            return ""
        return win.title || windowAddress(win)
    }

    // address 在窗口刚映射那一拍可能还没同步到顶层属性，退到 IPC 快照里取。
    function windowAddress(win) {
        if (!win)
            return ""
        if (win.address)
            return String(win.address)
        if (win.lastIpcObject && win.lastIpcObject.address)
            return String(win.lastIpcObject.address)
        return ""
    }

    function windowAppId(win) {
        if (!win)
            return ""
        if (win.wayland && win.wayland.appId)
            return String(win.wayland.appId)
        if (win.lastIpcObject && win.lastIpcObject.class)
            return String(win.lastIpcObject.class)
        return ""
    }

    // 少数 app 的 class 和主题图标名对不上，只能点名。加新条目前先确认
    // `image://icon/<class>` 真的取不到——大多数是能取到的。
    readonly property var _iconOverrides: ({
        "splayer": "file:///usr/share/icons/hicolor/512x512/apps/SPlayer.png",
        "cursor": "image://icon/co.anysphere.cursor"
    })

    readonly property string fallbackIcon: "image://icon/application-x-executable"

    function windowIcon(win) {
        const id = windowAppId(win)
        if (!id.length)
            return fallbackIcon
        const override = _iconOverrides[id.toLowerCase()]
        if (override)
            return override
        return "image://icon/" + id
    }

    // 给 ScreencopyView 的 captureSource。是个句柄，UI 原样绑上去就行。
    function windowCaptureSource(win) {
        return win ? win.wayland : null
    }

    // ============================================================
    // 活动窗口
    // ============================================================

    readonly property var activeWindow: Hyprland.activeToplevel

    function _activeWorkspaceId() {
        const w = activeWindow
        if (!w)
            return -1
        const id = workspaceId(w.workspace)
        if (id >= 0)
            return id
        // toplevel 的 workspace 有时是空的，IPC 快照里那份还在
        const ipcWs = w.lastIpcObject && w.lastIpcObject.workspace
        if (ipcWs) {
            if (ipcWs.id !== undefined && ipcWs.id !== null)
                return Number(ipcWs.id)
            if (ipcWs.name !== undefined && ipcWs.name !== null) {
                const m = String(ipcWs.name).match(/\d+/)
                if (m && m.length > 0)
                    return Number(m[0])
            }
        }
        return -1
    }

    // Hyprland 换工作区时不会把 activeToplevel 清空，它还指着上一个工作区那个窗。
    // 所以「有没有活动窗口」得自己判：活动窗不在当前工作区，或者当前工作区根本
    // 是空的，都算没有。问不出 id 时按「有」处理，宁可显示旧标题也别闪成 Desktop。
    readonly property bool hasActiveWindow: {
        const w = activeWindow
        if (!w)
            return false
        const ws = focusedWorkspace
        if (ws && ws.toplevels && ws.toplevels.count <= 0)
            return false
        const fid = focusedWorkspaceId
        const aid = _activeWorkspaceId()
        if (fid < 0 || aid < 0)
            return true
        return aid === fid
    }

    readonly property string activeTitle:
        hasActiveWindow ? (activeWindow.title || "") : ""

    // ============================================================
    // 按工作区分组的窗口清单（切换器用）
    // ============================================================
    //
    // 只含有窗口的工作区；工作区按 id、组内按 address 排序——两者都要稳定，否则
    // Hyprland 每次重排 toplevels 都会让卡片跳位。
    //
    // 这里给的是 JS 数组而不是增量 ListModel：切换器是随 Hub Loader 建了就销毁的
    // 页，不播行级过渡，整体重算没有代价（约定第 4 条允许这种情况用数组）。
    readonly property var windowGroups: {
        const out = []
        const wss = Hyprland.workspaces.values
        if (!wss)
            return out
        const sorted = wss.slice().sort((a, b) => workspaceId(a) - workspaceId(b))
        for (let i = 0; i < sorted.length; ++i) {
            const ws = sorted[i]
            if (!ws || !ws.toplevels)
                continue
            const wins = ws.toplevels.values.slice().sort((a, b) => {
                const aa = windowAddress(a)
                const bb = windowAddress(b)
                return aa < bb ? -1 : (aa > bb ? 1 : 0)
            })
            if (wins.length === 0)
                continue
            out.push({ ws: ws, wins: wins })
        }
        return out
    }

    // 活动窗口落在 windowGroups 的哪一格。先按地址找具体那个窗；找不到就退到
    // 「焦点工作区那一组的第一个」；再找不到就第 0 组。
    function locateActive() {
        const groups = windowGroups
        const addr = windowAddress(activeWindow)
        if (addr.length) {
            for (let i = 0; i < groups.length; ++i) {
                const wins = groups[i].wins
                for (let j = 0; j < wins.length; ++j) {
                    if (windowAddress(wins[j]) === addr)
                        return { group: i, item: j }
                }
            }
        }
        const wsId = focusedWorkspaceId
        for (let i = 0; i < groups.length; ++i) {
            if (workspaceId(groups[i].ws) === wsId)
                return { group: i, item: 0 }
        }
        return { group: 0, item: 0 }
    }

    // ============================================================
    // 派发
    // ============================================================

    // 唯一的出口。见文件头：Lua 配置下 Hyprland.dispatch 会丢引号炸掉，所以这里
    // 一律拼 Lua 表达式交给 hyprctl eval。
    function luaEval(expr) {
        Quickshell.execDetached(["hyprctl", "eval", expr])
    }

    // 让合成器退出。给 Session.logout() 用，它要把这条拼进一整串 shell 回退链
    // （hyprshutdown 优先），所以给的是命令字串而不是函数。
    //
    // 这条不走 luaEval：注销的语义是「合成器自己关掉」，走 CLI 的 dispatch 直达，
    // 而 luaEval 那条路要先让合成器执行一段 Lua 再由 Lua 去 dispatch——正在退出的
    // 东西不该多绕一层。原样保留 PowerBar 里用了很久的写法。
    readonly property string exitCommand: "hyprctl dispatch exit"

    // 地址一律补 0x 前缀：IPC 有时给带前缀的，有时不给，Lua 那头必须一致。
    function _normAddr(addr) {
        const a = String(addr || "")
        if (a.length > 0 && !a.startsWith("0x"))
            return "0x" + a
        return a
    }

    function focusWindow(addr) {
        const a = _normAddr(addr)
        if (!a.length)
            return
        luaEval("hl.dispatch(hl.dsp.focus({window='" + a + "'}))")
    }

    function focusWorkspace(wsId) {
        if (wsId === null || wsId === undefined || isNaN(Number(wsId)))
            return
        luaEval("hl.dispatch(hl.dsp.focus({workspace=" + Number(wsId) + "}))")
    }

    // toplevel 句柄自己能激活的话优先走它——比拼字符串再让 Hyprland 反查地址准。
    function activateToplevel(top) {
        if (!top)
            return false
        try {
            if (top.wayland) {
                top.wayland.activate()
                return true
            }
            if (top.activate) {
                top.activate()
                return true
            }
        } catch (e) {}
        return false
    }

    // 拉起应用。走 hl.exec_cmd 而不是 dispatch exec，同样是 Lua 配置那个坑。
    // 长括号 [=[ ]=] 是为了让命令里的引号原样过去。
    function execCmd(line) {
        const s = String(line || "")
        if (!s.length)
            return
        luaEval("hl.exec_cmd([=[" + s + "]=])")
    }
}
