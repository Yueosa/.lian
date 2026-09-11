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
import qs.data.state

RailPage {
    id: root

    edge: "left"
    shellNamespace: "qsl-leftbar"
    // 互斥组：C：leftrail，和 Z=剪贴板同区
    panelGroup: "left"
    order: ["time", "sys", "keys", "todo"]
    page: "time"

    // 旧对外属性名，直通 RailPage.page
    property alias view: root.page

    readonly property var views: ["time", "sys", "keys", "todo"]

    // 宽度按页定（时间窄、系统宽）；keys/todo 置顶布局：tab 条钉顶，内容从下长
    pages: ({
        time: { title: "工具", icon: "\uf017", width: Size.panel.cWidth,
                shownRiseMs: 0, header: toolTabsCard,
                containers: [timeClockCard, timeTimerCard, calcCard, reminderCard] },
        sys:  { title: "系统", icon: "\uf2db", width: Size.panel.cWidth, containers: [sysDialCard, sysPsiCard, sysDiskCard, sysNetCard, sysProcsCard] },
        keys: { title: "键位", icon: "\uf11c", width: Size.panel.cWidth, header: keysTabsCard, containers: [keysListCard] },
        todo: { title: "待办", icon: "\uf0ae", width: Size.panel.cWidth, header: todoTabsCard, containers: [todoListCard, todoDoneCard] }
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
    // 走基类的 detailPage（双边滞后）而不是 open && page：setDetailActive 要
    // fork 三个进程，绑 open 就会砸在派生动画第一帧上
    readonly property bool sysDetailActive: detailPage === "sys"
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

    // tool：工具页分区（芯片条卡点选）。下方容器按 groupId 自报 hasContent，
    // 芯片切换 = 只改这个字符串，换卡动画由占位协议自带（下降沿立刻、上升沿
    // 走页配置的 shownRiseMs: 0），不用 replayContainer
    QtObject {
        id: toolState

        property string groupId: "time"
    }

    // ---- 容器装配（顺序即派生顺序）----
    Component { id: toolTabsCard; ToolTabsCard { sharedState: toolState } }
    Component { id: timeClockCard; TimeClockCard { hasContent: toolState.groupId === "time" } }
    Component { id: timeTimerCard; TimeTimerCard { hasContent: toolState.groupId === "time" } }
    Component { id: calcCard; CalcCard { hasContent: toolState.groupId === "calc" } }
    Component { id: reminderCard; ReminderCard { hasContent: toolState.groupId === "remind" } }
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
