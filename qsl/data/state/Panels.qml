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
//   "left"    C=左附栏、Z=剪贴板（Z 在 bottomrail **左段**，那块地方压着 C 那
//             一列的下半截，所以跟 C 一组；它和 A 各占底 rail 的一段，不互斥）
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
// 不用付。（RailPage 曾靠它跳过一条 230ms 的延迟起跑线，那条已换成帧闸，见
// RailPage 的 derivGate。）
// ============================================================
// 对外接口：
//   claim(id, group, edge, valign, anchor)
//                      我要开了：压栈，登记，再把同组原来那个挤掉。
//                      贴边的面板还会占一格水波源槽位（见 railSlots）
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

    // ============================================================
    // 水波源槽位
    // ============================================================
    // 固定 6 格的池子，每格 null 或 `{ id, edge, valign, anchor }`。只登记贴边的
    // 面板（left/right/bottom 三条 rail），**不含岛**——岛是独立体系，不参与任何
    // rail 动画。这不是洁癖，是实测：水波开着要多吃约 8 个百分点 CPU，而
    // n=basic 下渲染同步在主线程，这笔开销正好压在岛的 morph/果冻回弹上，
    // 岛就又开始抖了。
    //
    // 为什么按**边**登记不行（第一版就是那样）：一条边容得下不止一个面板。A 在
    // 底 rail 中段、Z 在底 rail 左段，两个不重叠、可以同时开着。按边存的话后开
    // 的会顶掉先开的那一格（先开的 release 又因为 id 不符不敢清），症状是
    // 「关掉后开的那个，还开着的那个就不放波了」。
    // 为什么也不能让水波那边直接 `Repeater` 吃 `Object.keys(表)`：面板一关条目
    // 就没了，发射器**跟着被销毁**，临别那一发（见 RailRipple.onSrcKeyChanged）
    // 就没人放；而且 Repeater 吃 JS 数组是整体重建，别的发射器攒着的 lastOrigin
    // 和定时器相位会一起被重置。
    // 固定池子把两头都躲开：格子永不增删，只是内容在 null 和条目之间切换，
    // 水波那边摆 6 个固定发射器各看自己那一格。
    // 6 格够：贴边的面板一共 C/V/N/A/Z/X/powerbar，同时开着的不会超过这个数。
    //
    // 按互斥组登记也不行，虽然两者大多数时候重合（C 是 left 组、贴 left 边）：
    // A 是 **center 组（跟岛互斥）+ bottom 边**，按组登记它就永远进不了底 rail
    // ——「开 A 不放波」就是这么来的。
    //
    // 放在这里而不是让面板直接找水波：面板是框窗的租户，互相不该知道对方存在，
    // 而这张表本来就是「框窗的状态」。
    //
    // 条目里的三个字段都是给出生点用的：
    //   edge    哪条 rail
    //   valign  贴那条边的哪一头（N 贴底、V 贴顶，同一条右 rail 上出生点差一整条边）
    //   anchor  沿边的锚点像素（底边给屏幕 x）。-1 = 没给，那条边按老规矩取
    //           中点/定比内缩。底 rail 上 A 居中、Z 靠左，非得由面板自己报
    readonly property int railSlotCount: 6
    property var railSlots: [null, null, null, null, null, null]

    readonly property bool railHeld: {
        const s = railSlots
        for (let i = 0; i < s.length; i++) {
            if (s[i])
                return true
        }
        return false
    }

    signal evicted(string id)

    function claim(id, group, edge, valign, anchor) {
        const me = String(id || "")
        if (!me)
            return
        // 压栈在分组仲裁之前，而且不看有没有组：不参与互斥的面板（岛、迁移中
        // 的窗口）照样要排进键盘归属的队里，否则它们的 Esc 抢不到
        _push(me)

        // 贴边的面板同时是水波的波源，占一格槽位。排在分组仲裁之前：波源和互斥组
        // 是两件事（A = center 组 + bottom 边），不参与互斥的贴边面板照样该放波
        const e = String(edge || "")
        if (e === "left" || e === "right" || e === "bottom") {
            _takeRailSlot(me, e, String(valign || "top"),
                (anchor === undefined || anchor === null) ? -1 : Number(anchor))
        }

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

    // 找自己那格；没有就占第一个空格。
    // 先找自己：同一个面板重复 claim（IPC 指定页再开一次、换页）不该占第二格，
    // 而且就地更新意味着 anchor 变了（页宽不同）水波那边会重新放一发
    function _takeRailSlot(id, edge, valign, anchor) {
        const next = railSlots.slice()
        let at = -1
        for (let i = 0; i < next.length; i++) {
            if (next[i] && next[i].id === id) {
                at = i
                break
            }
        }
        if (at < 0) {
            for (let i = 0; i < next.length; i++) {
                if (!next[i]) {
                    at = i
                    break
                }
            }
        }
        // 满了就这一个不放波。宁可少一道波，也不去挤掉别人那格——挤掉的那格
        // 会被误读成「面板关了」，凭空多出一发临别波
        if (at < 0)
            return
        next[at] = {
            "id": id, "edge": edge, "valign": valign, "anchor": anchor
        }
        railSlots = next
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
        const slots = railSlots.slice()
        let changed = false
        let slotChanged = false
        for (const g in next) {
            if (next[g] === me) {
                delete next[g]
                changed = true
            }
        }
        // 只清自己那格（格子里带着 id）：晚到的 release 不会误伤别人的槽位
        for (let i = 0; i < slots.length; i++) {
            if (slots[i] && slots[i].id === me) {
                slots[i] = null
                slotChanged = true
            }
        }
        if (changed)
            actives = next
        if (slotChanged)
            railSlots = slots
    }

    function activeIn(group) {
        return actives[String(group || "")] || ""
    }

    // 用户点到框外面去了（框窗 HyprlandFocusGrab 的 cleared）：把开着的全关掉。
    // 复用 evicted 而不是新开一条通路：被同组挤掉和被用户点掉，对面板来说是
    // 同一件事——「你该自己收场」——而那条路径的关窗动画和记账已经是对的。
    // 倒着关：evicted 触发的 closeWindow 会 release，正着遍历会边改边读
    function dismissAll() {
        const ids = stack.slice().reverse()
        for (let i = 0; i < ids.length; i++)
            evicted(ids[i])
    }
}
