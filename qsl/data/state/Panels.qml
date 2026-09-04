pragma Singleton

// ============================================================
// 面板互斥仲裁 — Panels
// ============================================================
// 每个「区域」同时只留一个面板开着。
//
// 为什么要按区域分组而不是全局互斥：互斥的理由是物理重叠——两个面板占同一块
// 屏幕区域，同时开就互相压着，而且它们都申请独占键盘焦点，后开的那个会吃掉
// Esc/Tab，另一个静默失灵。不重叠的面板（左边的 C 和右边的 V）没有理由互斥。
//
// 组划分（见 plan.md 术语表与锚点分工）：
//   "right"   V=右附栏、N=通知，将来 X=磁贴（若落在 bottomrail 右侧）
//   "left"    C=左附栏、Z=剪贴板（Z 位置定死左边）
//   "center"  island=灵动岛、A=应用启动器
//
// 为什么不从几何自动推：锚点分工是设计决定，不是算出来的（X 落哪一侧还没定）。
// 显式写组名，改起来是一行的事，也一眼能看出谁跟谁抢。
//
// ============================================================
// 焦点栈（合并框窗之后新增的一半职责）
// ============================================================
// 合并前每个面板是一个独立 surface，各自申请 Exclusive 键盘焦点，谁真拿到键盘
// 是合成器裁决的（基本是后 map 的赢）——所以上面那段说的「后开的那个会吃掉
// Esc/Tab，另一个静默失灵」是当时的实情，且不可预测。
//
// 合并成一个窗之后，那个窗只有一个 keyboardFocus、只有一个 activeFocusItem，
// 归属必须由我们显式定。定的规则是栈：开一个压栈，栈顶持键盘。于是
//   Esc     关栈顶那个 → 栈弹出 → 键盘自动落到下一个 → 再按 Esc 关下一个
//   Tab     只在栈顶那个面板内部循环
// 跨区域同时开着 C 和 V 时，行为从「看运气」变成了「后开的那个响应，关掉它
// 键盘就回到前一个」。
//
// keyboardHeld 还有第二个用途：判断框窗是不是**已经**持有焦点。新申请
// Exclusive 要花 ~190ms 主线程停顿，而面板之间切换时框窗根本没松手，这笔钱
// 不用付——RailPage 靠它决定要不要走 focusSettleMs 那条延迟起跑线。
// ============================================================
// 对外接口：
//   claim(id, group)   我要开了：压栈，登记，再把同组原来那个挤掉
//   release(id)        我关了（只清自己那条，晚到的 release 不误伤）
//   activeIn(group)    该组当前开着的面板 id（无则空串）
//   keyboardOwner      当前该响应 Esc/Tab 的面板 id（栈顶，无则空串）
//   keyboardHeld       框窗此刻是否已持有键盘焦点（栈非空）
//   evicted(id)        被挤掉的面板收到自己的 id，自行关窗
// ============================================================

import Quickshell

Singleton {
    id: root

    // { 组名: 面板 id }。整体替换而不是原地改键——var 属性原地改不发通知
    property var actives: ({})

    // 开着的面板 id，按开启先后排；末尾 = 栈顶 = 当前持键盘的那个
    property var stack: []

    readonly property string keyboardOwner: stack.length > 0
        ? stack[stack.length - 1] : ""
    readonly property bool keyboardHeld: stack.length > 0

    signal evicted(string id)

    function claim(id, group) {
        const me = String(id || "")
        if (!me)
            return
        // 压栈在分组仲裁之前，而且不看有没有组：不参与互斥的面板（岛、迁移中
        // 的窗口）照样要排进键盘归属的队里，否则它们的 Esc 抢不到
        _push(me)
        const g = String(group || "")
        // 没给组的面板不参与互斥（迁移中的窗口、独立小窗）
        if (!g)
            return
        const prev = actives[g] || ""
        if (prev === me)
            return
        // 先换登记再发逐客令：被挤的那个关窗时会调 release，
        // 那时登记已经是新面板，它的 release 自然成了空操作
        const next = Object.assign({}, actives)
        next[g] = me
        actives = next
        if (prev !== "")
            evicted(prev)
    }

    // 重复开同一个面板（IPC 指定页再开一次）要把它挪到栈顶：它是最近交互的那个
    function _push(id) {
        const next = stack.filter(x => x !== id)
        next.push(id)
        stack = next
    }

    function release(id) {
        const me = String(id || "")
        if (!me)
            return
        stack = stack.filter(x => x !== me)
        const next = Object.assign({}, actives)
        let changed = false
        for (const g in next) {
            if (next[g] === me) {
                delete next[g]
                changed = true
            }
        }
        if (changed)
            actives = next
    }

    function activeIn(group) {
        return actives[String(group || "")] || ""
    }
}
