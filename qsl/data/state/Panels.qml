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
// 故意做小，这不是「窗口管理器」：rail 合并（bar + 三 rail + 耳 → 单全屏窗）
// 之后所有面板共处一窗，那时这张表就直接是那个窗口的状态，整块搬过去。
// ============================================================
// 对外接口：
//   claim(id, group)   我要开了：先登记，再把同组原来那个挤掉
//   release(id)        我关了（只清自己那条，晚到的 release 不误伤）
//   activeIn(group)    该组当前开着的面板 id（无则空串）
//   evicted(id)        被挤掉的面板收到自己的 id，自行关窗
// ============================================================

import Quickshell

Singleton {
    id: root

    // { 组名: 面板 id }。整体替换而不是原地改键——var 属性原地改不发通知
    property var actives: ({})

    signal evicted(string id)

    function claim(id, group) {
        const me = String(id || "")
        const g = String(group || "")
        // 没给组的面板不参与互斥（迁移中的窗口、独立小窗）
        if (!me || !g)
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

    function release(id) {
        const me = String(id || "")
        if (!me)
            return
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
