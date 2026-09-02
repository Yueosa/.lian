// Leftbar — C 面板壳（Super+C / IPC sidebar），进入模式容器版
// 页面 = 从 leftrail 派生的一组 RailContainer（RailPage 编排：级联派生/收回、Esc/点空白关闭、Tab 循环）
// 无页面级 Tab 条；对外 API 与旧卡片版一致：
//   toggle() / openWindow(v) / openView(v) / view / next() / prev() / closeWindow()
//
// 共享状态：todo 筛选 / keys 组选中上移到本文件（同页两卡各持一半 UI，经 sharedState 属性共用）
// Sysmon 详情档：原 SystemPage 进/出页开关，现按 open && page==="sys" 驱动

import QtQuick
import qs.Components
import qs.data.service

RailPage {
    id: root

    edge: "left"
    shellNamespace: "qsl-leftbar"
    order: ["time", "sys", "keys", "todo"]
    page: "time"

    // 旧对外属性名，直通 RailPage.page
    property alias view: root.page

    readonly property var views: ["time", "sys", "keys", "todo"]

    // 宽度按页定（时间窄、系统宽）；keys/todo 置顶布局：tab 条钉顶，内容从下长
    pages: ({
        time: { title: "时间", icon: "\uf017", width: 400, containers: [timeClockCard, timeTimerCard] },
        sys:  { title: "系统", icon: "\uf2db", width: 470, containers: [sysDialCard, sysPsiCard, sysDiskCard, sysNetCard, sysProcsCard] },
        keys: { title: "键位", icon: "\uf11c", width: 460, header: keysTabsCard, containers: [keysListCard] },
        todo: { title: "待办", icon: "\uf0ae", width: 460, header: todoTabsCard, containers: [todoListCard, todoDoneCard] }
    })

    // 子 tab 切换 → 列表容器播"收回→派生"回放；tab 条是页首固定件，永远不动
    property Connections _keysReplay: Connections {
        target: keysState
        function onGroupIdChanged() {
            if (root.open && root.page === "keys")
                root.replayContainer(0)
        }
    }
    property Connections _todoReplay: Connections {
        target: todoState
        function onActiveTagChanged() { root._replayTodo() }
        function onStarredOnlyChanged() { root._replayTodo() }
    }
    function _replayTodo() {
        if (root.open && root.page === "todo") {
            root.replayContainer(0)
            root.replayContainer(1)
        }
    }

    function normalizeView(v) {
        if (!v)
            return views[0]
        const key = String(v).toLowerCase()
        if (key === "lianclaw" || key === "clock" || key === "date")
            return "time"
        if (key === "system" || key === "sysmon" || key === "monitor")
            return "sys"
        if (key === "weather" || key === "hotkeys" || key === "shortcuts")
            return "keys"
        if (key === "todos" || key === "task" || key === "tasks")
            return "todo"
        for (let i = 0; i < views.length; i++) {
            if (views[i] === key)
                return views[i]
        }
        return views[0]
    }

    function openWindow(v) {
        const has = v !== undefined && v !== null && String(v).length > 0
        openPage(has ? normalizeView(v) : page)
    }

    // 与旧 IPC 对齐：指定页打开；同页再开则关闭
    // 关窗时不能走 switchTo（目标页 == 当前页会被它跳过，窗开不起来）
    function openView(v) {
        const target = normalizeView(v)
        if (open && page === target) {
            closeWindow()
            return
        }
        if (open)
            switchTo(target)
        else
            openPage(target)
    }

    function next() { cycle(1) }
    function prev() { cycle(-1) }

    // Sysmon 详情档生命周期（原 SystemPage Component.onCompleted/onDestruction）
    readonly property bool sysDetailActive: open && page === "sys"
    onSysDetailActiveChanged: Sysmon.setDetailActive(sysDetailActive)

    // ---- 页内两卡共享状态 ----

    // keys：一级组选中（芯片条卡点选，列表卡跟随）
    QtObject {
        id: keysState

        property string groupId: "hypr"

        function ensureGroup() {
            if (Hotkeys.groupById(groupId))
                return
            const gs = Hotkeys.groups || []
            if (gs.length > 0 && gs[0] && gs[0].id)
                groupId = String(gs[0].id)
        }

        property Connections _conn: Connections {
            target: Hotkeys
            function onGroupsChanged() { keysState.ensureGroup() }
            function onReadyChanged() { keysState.ensureGroup() }
        }

        Component.onCompleted: ensureGroup()
    }

    // todo：筛选（星标与标签正交：可以同时「只看重要」和「只看开发」）
    QtObject {
        id: todoState

        property string activeTag: ""
        property bool starredOnly: false
    }

    // ---- 容器装配（顺序即派生顺序）----
    Component { id: timeClockCard; TimeClockCard {} }
    Component { id: timeTimerCard; TimeTimerCard {} }
    Component { id: sysDialCard; SysDialCard {} }
    Component { id: sysPsiCard; SysPsiCard {} }
    Component { id: sysDiskCard; SysDiskCard {} }
    Component { id: sysNetCard; SysNetCard {} }
    Component { id: sysProcsCard; SysProcsCard {} }
    Component { id: keysTabsCard; KeysTabsCard { sharedState: keysState } }
    Component { id: keysListCard; KeysListCard { sharedState: keysState } }
    Component { id: todoTabsCard; TodoTabsCard { sharedState: todoState } }
    Component { id: todoListCard; TodoListCard { sharedState: todoState } }
    Component { id: todoDoneCard; TodoDoneCard { sharedState: todoState } }
}
