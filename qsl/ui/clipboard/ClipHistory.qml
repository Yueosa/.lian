// ClipHistory — Z 面板壳（剪贴板 / IPC clipboard），从 bottomrail 左段长出来
//
// 和 A 的关系：同一条底 rail 上各占一段（A 中段、Z 左段），互不重叠，所以
// **不互斥**、可以同时开着。互斥组给的是 "left"：Z 那块地方压着 C 那一列的
// 下半截（C 的系统页能长到屏幕下半截，两个都开就叠在一起）。
//
// 只有一个容器，所以没有 A 那套三拍：一张卡从 rail 里长出来就完了。卡里是
// 列表 + 贴下沿的搜索条 —— 搜索条在下沿而不是上沿，为的是和 A 的搜索框同高，
// 两个面板背下来的手感一致。
//
// 行的形状是这个面板唯一的特殊之处：文本一条一行，连续的图片打包成一行多列，
// 于是键位是**二维**的（↑↓ 跨行、←→ 在图片行内挪并在尽头换行）。打包在数据层
// （Clipboard.rows 是增量模型），这里只把"一行摆几张"算给它，再管选择态。

import QtQuick
import Quickshell
import qs.Components
import qs.data.clipboard
import qs.data.state

RailPage {
    id: root

    edge: "bottom"
    halign: "left"
    shellNamespace: "qsl-clipboard"
    panelGroup: "left"
    containerWidth: Size.panel.zWidth

    order: ["clips"]
    page: "clips"
    pages: ({
        clips: { title: "剪贴板", containers: [clipCard] }
    })

    // 列表高度每敲一个键就换一次目标（搜索），过冲会让它长过头再缩回来——
    // 多出来那截行冒出来又被裁掉，读成「回弹太猛」。同 A
    elasticType: Anim.EnterFast

    // 条带高度 = inputMask 的高度，取内容上界而不是跟着列表的弹性高度抖
    stripHeight: 16 + clipState.searchH + Size.spacing.md
        + clipState.maxListH + 24

    // 开窗：先灌磁盘缓存（秒开），再后台跑一次 list。关窗清内存——列表里那些
    // 缩略图 Image 是这个面板的内存大头
    //
    // 清内存要**等退场播完**。就地清的话模型在关窗那一帧就归零，而卡片还在
    // 往下收：列表瞬间空掉、contentY 弹回顶部，看着是「焦点先跳回顶部，然后
    // 窗口赖着不走」（探针实测：model=0 的同时还有 5 行在屏幕上淡出）
    onOpenChanged: {
        if (open) {
            releaseDelay.stop()
            Clipboard.hydrate()
            Clipboard.refresh()
            clipState.reset()
        } else {
            releaseDelay.restart()
        }
    }

    Timer {
        id: releaseDelay
        interval: root.exitAllMs
        onTriggered: Clipboard.release()
    }

    // ---- 卡与壳共享的状态 ----
    QtObject {
        id: clipState

        // ---- 几何 ----
        readonly property int pad: Size.spacing.sm
        readonly property int textRowH: 46
        readonly property int imageCellW: 156
        readonly property int imageCellH: 112
        readonly property int cellSpacing: Size.spacing.sm
        readonly property int rowSpacing: Size.spacing.sm
        readonly property int searchH: 48
        readonly property int maxListH: Size.panel.zListHeight

        // 列表可用宽度（卡片内减两边内边距）→ 一行摆几张图。算完写给数据层，
        // 打包在那边做（Clipboard.columns / rows）
        readonly property int innerW: root.containerWidth - 2 * pad
        readonly property int perRow: Math.max(1,
            Math.floor((innerW + cellSpacing) / (imageCellW + cellSpacing)))

        // ---- 选择（二维）----
        property int currentRow: 0
        property int currentCol: 0

        // ---- 粘贴动画 ----
        // 选中项留下、其余右滑淡出，播完这一段才关窗（同 A 的启动动画）
        property bool pasting: false
        property int pasteRow: -1
        property int pasteCol: -1
        readonly property int exitSlide: 72
        readonly property int pasteAnimMs: 180
        // reset 那一拍关掉 Behavior：不然下次开窗会看见上次的回弹
        property bool animEnabled: true

        // ---- 焦点请求 ----
        // 搜索条盯着这个数，一变就把 activeFocus 抢回来（Loader 是 focus scope，
        // 光声明 focus 传不出去，见 AppSearchCard 那段注释）
        property int focusTick: 0

        // ---- 搜索 ----
        property string query: ""

        function reset() {
            animEnabled = false
            pasting = false
            pasteRow = -1
            pasteCol = -1
            currentRow = 0
            currentCol = 0
            setQuery("")
            focusTick += 1
            Qt.callLater(() => clipState.animEnabled = true)
        }

        function setQuery(q) {
            if (pasting)
                return
            query = String(q || "")
            currentRow = 0
            currentCol = 0
            Clipboard.query = query
        }

        readonly property int rowCount: Clipboard.rowCount

        function clampSelection() {
            if (rowCount === 0) {
                currentRow = 0
                currentCol = 0
                return
            }
            currentRow = Math.max(0, Math.min(rowCount - 1, currentRow))
            const row = Clipboard.rowAt(currentRow)
            const maxCol = row ? row.entries.length - 1 : 0
            currentCol = Math.max(0, Math.min(maxCol, currentCol))
        }

        function selectedEntry() {
            const row = Clipboard.rowAt(currentRow)
            if (!row || row.entries.length === 0)
                return null
            const col = row.type === "images"
                ? Math.min(currentCol, row.entries.length - 1) : 0
            return row.entries[col]
        }

        // ---- 键位 ----
        // ↑↓ 跨行；图片行之间尽量保持列（从一张图往上/往下走，落在同一列上）
        function move(d) {
            if (rowCount === 0 || pasting)
                return
            const target = currentRow + d
            // 到头绕回另一端（同 A 的 ↑↓）
            currentRow = target < 0 ? rowCount - 1
                : (target > rowCount - 1 ? 0 : target)
            const row = Clipboard.rowAt(currentRow)
            currentCol = (row && row.type === "images")
                ? Math.min(currentCol, row.entries.length - 1) : 0
        }

        // ←→ 在图片行内挪，到尽头换到上一行末 / 下一行首（文本行视为单格）
        function moveSide(d) {
            if (rowCount === 0 || pasting)
                return
            const row = Clipboard.rowAt(currentRow)
            if (row && row.type === "images") {
                const next = currentCol + d
                if (next >= 0 && next <= row.entries.length - 1) {
                    currentCol = next
                    return
                }
            }
            const targetRow = currentRow + d
            if (targetRow < 0 || targetRow > rowCount - 1) {
                // 列表两头：绕回另一端，落在那一行的对应尽头
                currentRow = targetRow < 0 ? rowCount - 1 : 0
            } else {
                currentRow = targetRow
            }
            const landed = Clipboard.rowAt(currentRow)
            const lastCol = (landed && landed.type === "images")
                ? landed.entries.length - 1 : 0
            currentCol = d < 0 ? lastCol : 0
        }

        function paste() {
            if (pasting)
                return
            const e = selectedEntry()
            if (!e)
                return
            Clipboard.paste(e.id, e.mime)
            pasting = true
            pasteRow = currentRow
            const row = Clipboard.rowAt(currentRow)
            pasteCol = (row && row.type === "images")
                ? Math.min(currentCol, row.entries.length - 1) : 0
            exitDelay.restart()
        }

        function pasteAt(r, c) {
            currentRow = r
            currentCol = c
            paste()
        }

        // 删一条。选择留在原处（下面那条顶上来），不动 currentRow：删一串的时候
        // 手不用重新找位置
        function removeSelected() {
            if (pasting)
                return
            const e = selectedEntry()
            if (e)
                Clipboard.remove(e.id)
        }
    }

    Timer {
        id: exitDelay
        interval: clipState.pasteAnimMs
        onTriggered: root.closeWindow()
    }

    // 视图算出来的分组参数交给数据层，行由那边打包
    Binding {
        target: Clipboard
        property: "columns"
        value: clipState.perRow
    }

    // 行变了（搜索、删除、后台 list 回来）把选择夹回范围内
    Connections {
        target: Clipboard
        function onRevisionChanged() { clipState.clampSelection() }
    }

    Component {
        id: clipCard
        ClipCard { sharedState: clipState }
    }
}
