// Launcher — A 面板壳（应用启动器 / IPC launcher），从 bottomrail 中段长出来
//
// 第一个**沿行程轴堆叠**的页：左右两条 rail 的容器是沿边并排的（生长方向垂直于
// 排布方向，谁也碰不到谁），底边不是——排布方向就是生长方向。两个容器：
//   容器 1 = 应用列表（上）      容器 2 = 搜索框（下，贴着 rail）
//
// 出场三段，**首尾咬住地连续走完**（见 RailContainer.slotGrows / RailPage.slotLeadMs）：
//   1. 列表贴着 rail 长出来
//   2. 它还没站稳，下面那格的槽位就开始撑，把它顶上去 —— 「脱离」。列表离开
//      rail 的同时耳朵淡出、贴 rail 那两个角圆起来（它现在是悬空的卡片）
//   3. 缝还在开，搜索框已经从 rail 里长进去，带回弹（curveSpatial 的第二控制点
//      y=1.40，过冲本来就在标准开场曲线里，不用另造）
// 收场是逆序且更紧：搜索框缩回 rail、列表随之落回，再收回。
//
// 互斥组 center：跟灵动岛抢屏幕中段（组划分见 Panels）。岛也 claim 这一组，
// 所以互斥是白送的，这里不用接线。
//
// 键位 / 启动动画 / 图标三级回退 / 匹配高亮照搬旧 AppPage（那份连同旧的
// 60% 壁纸预览自由窗一起删了）。列表与搜索框拆成两张卡之后，两边共享的状态
// 收在 appState 里 —— 对齐 N 的 notifState 惯例。

import QtQuick
import Quickshell
import qs.Components
import qs.data.state
import qs.data.launcher

RailPage {
    id: root

    edge: "bottom"
    shellNamespace: "qsl-launcher"
    panelGroup: "center"
    containerWidth: Size.panel.aWidth

    order: ["apps"]
    page: "apps"
    pages: ({
        apps: { title: "应用", containers: [appListCard, appSearchCard] }
    })

    // 三段**故意重叠**，读成一次连续的舒展，不是「走完一步再走下一步」。
    //
    // 先试过严格顺序（staggerStep 560 / slotLeadMs 360）：列表 0-500 走完、
    // 脱离 200-600、搜索框 560-1060。每一拍都干净，但用户反馈是「卡卡的，
    // 能很明显感到列表和搜索框的边界」——因为每段之间都有一小截「什么都不动」
    // 的空档，眼睛会把它读成停顿，两张卡于是像两件事而不是一件事。
    //
    // 现在：列表 0-500（约 210ms 到位）、脱离 140-540、搜索框 260-760。
    // 任何一个瞬间都有东西在动，交接处互相咬住
    staggerStep: 260
    slotLeadMs: 120
    // 退场**两格一起走**：搜索框缩回 rail 的同时，列表一边被落回一边收。
    // 试过 200 和 140，都能感到「列表在等搜索框」——退场没有叙事，只该一下子收掉。
    // 两格同时动在这里不犯「退场瞬移」那条忌（见 RailContainer.exitStaggerMs）：
    // 那条忌讲的是**跳变**引起的重排，而这里列表是被槽位的收势曲线连续带下去的
    exitStaggerStep: 0
    // 列表高度每敲一个键就换一次目标，过冲会让它长过头再缩回来（多出来的那截
    // 行冒出来又被裁掉）。换成减速不过冲的一档：到位即稳
    elasticType: Anim.EnterFast

    // 条带高度 = inputMask 的高度，取内容上界而不是跟着列表的弹性高度抖
    // （每帧变一次 mask 就是每帧一次合成器往返，见 RailPage.stripHeight）
    stripHeight: 16 + appState.searchH + Size.spacing.md + appState.maxListH + 24

    // 开窗即重置：清搜索、回到完整列表、选中第一项。
    // 挂 onOpenChanged 而不是重写 closeWindow（基类那几行记账抄一遍就会抄漏，
    // N 就抄漏过 Panels.release）
    onOpenChanged: {
        if (open)
            appState.reset()
    }

    Connections {
        target: Apps
        function onRevisionChanged() { appState.clampIndex() }
    }


    // ---- 两卡共享状态 ----
    QtObject {
        id: appState

        // ---- 几何（两张卡都要读）----
        readonly property int itemHeight: 56
        readonly property int iconSize: 36
        readonly property int searchH: 48
        // 列表高度随候选数弹性收缩，上界 6 行：再高就把中段吃满了，
        // 而启动器的候选看前几个就够（真要翻还有 ←→ 翻页）
        readonly property int maxRows: 6
        readonly property int maxListH: maxRows * itemHeight

        // ---- 数据与选择 ----
        // 结果集的真身是 Apps.rows（增量 ListModel，给 ListView 的过渡用），
        // 这里只留搜索词和选中项
        property string query: ""
        property int index: 0
        readonly property int count: Apps.rows.count
        // 列表实际显示几行（= 翻页键的步长）。列表卡的高度也由它算，
        // 两边同一个来源，不用卡片再写回来。
        // 叫 visibleRows 不叫 rows：rows 已经是 Apps.rows（结果集模型）的名字，
        // 一个是「显示几行」一个是「有哪些行」，同名读代码时必踩
        readonly property int visibleRows: Math.max(1, Math.min(maxRows, count))

        // ---- 启动动画 ----
        // 选中项留下放大、其余右滑淡出，播完这一段才真的 exec
        property bool launching: false
        property int launchIndex: -1
        readonly property int exitSlide: 72
        readonly property int launchAnimMs: 180
        // reset 那一拍关掉 Behavior：不然下次开窗会看见上次的回弹
        property bool animEnabled: true

        // ---- 焦点请求 ----
        // 搜索框那张卡盯着这个数，一变就把 activeFocus 抢回来。
        //
        // 为什么要「抢」，光声明 focus: true 不够：容器的内容装在 RailContainer
        // 的 Loader 里，而 **Loader 自己就是一个 focus scope**，里面声明的 focus
        // 只在 Loader 这层内部生效，传不到 keyScope 上去 —— 探针实测
        // keyboardOwner 已经是 qsl-launcher、输入框 activeFocus 却是 false，
        // 键位于是全废。forceActiveFocus() 会把链上每一级 scope 的 focus 都置真，
        // 才穿得过 Loader 这一层（C 的标签框、V 的密码框走的也是这条路）
        property int focusTick: 0

        function reset() {
            animEnabled = false
            launching = false
            launchIndex = -1
            setQuery("")
            focusTick += 1
            Qt.callLater(() => appState.animEnabled = true)
        }

        function setQuery(q) {
            if (launching)
                return
            query = String(q || "")
            index = 0
            Apps.query = query
        }

        // 目录变了（装了新应用 / usage 重排）时把选中项夹回范围内。
        // 结果集本身不用管：Apps 自己会把 rows 增量对齐
        function clampIndex() {
            if (index > count - 1)
                index = Math.max(0, count - 1)
        }

        function appAt(i) {
            return (i >= 0 && i < count) ? Apps.rows.get(i).app : null
        }

        function move(d) {
            if (count <= 0 || launching)
                return
            index = (index + d + count) % count
        }

        // 翻页：先夹到头，**已经在头上**再按同一个方向才绕回另一端。
        // 直接夹死（原来那样）的手感是「←→ 到头就没反应了」，而 ↑↓ 是会绕的，
        // 两套键行为不一致；直接绕又会让「翻到第一页」变成「跳到最后一页」
        function pageBy(d) {
            if (count <= 0 || launching)
                return
            const target = index + d * visibleRows
            if (target < 0)
                index = (index === 0) ? count - 1 : 0
            else if (target > count - 1)
                index = (index === count - 1) ? 0 : count - 1
            else
                index = target
        }

        // 应用名，匹配段加粗加下划线。
        //
        // 旧 AppPage 把名字切成「前 / 匹配 / 后」三个 Text 摆一排，现在改成一个
        // StyledText：切三段就没法 elide（省略号该长在哪个 Text 上？），而居中
        // 布局下名字必须能被截断，不然长名字会把行顶宽。用富文本就一个 Text
        // 一件事，elide 白送。名字来自 .desktop，& < > 都得转义
        function styledName(fullText, q) {
            const text = String(fullText || "")
            const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
            const needle = String(q || "").trim()
            if (needle === "")
                return esc(text)
            const at = text.toLowerCase().indexOf(needle.toLowerCase())
            if (at < 0)
                return esc(text)
            return esc(text.slice(0, at))
                + "<b><u>" + esc(text.slice(at, at + needle.length)) + "</u></b>"
                + esc(text.slice(at + needle.length))
        }

        function run() {
            if (launching || count <= 0 || index < 0)
                return
            const app = appAt(index)
            if (!app || !app.appObj)
                return
            launching = true
            launchIndex = index
            launchDelay.restart()
        }

        // 退场动画播完再真启动：exec 会同步 fork，压在动画里就是掉帧
        property Timer _launchDelay: Timer {
            id: launchDelay
            interval: appState.launchAnimMs
            onTriggered: appState.launchAt(appState.launchIndex)
        }

        function launchAt(i) {
            const app = appAt(i)
            if (!app || !app.appObj)
                return

            const entry = app.appObj
            const argv = appState.cleanCommand(entry.command)
            const desktopId = String(entry.id || "").replace(/\.desktop$/, "")
            const viaHypr = String(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "").length > 0
            let launched = false

            // 用解析后的 command。不要 execute() 假成功，也不要把 Exec
            // 原样丢给 bash（%U 会变成字面参数）。
            // hyprctl dispatch exec 在 Lua 配置里会变成 hl.dispatch(exec …)
            // 直接炸（Island.hyprEval 那段同病）；立即执行走 hl.exec_cmd。
            if (argv.length > 0) {
                if (viaHypr)
                    Island.hyprEval("hl.exec_cmd([=["
                        + appState.shellJoin(argv) + "]=])")
                else
                    Quickshell.execDetached(argv)
                launched = true
                console.info("[launcher]", viaHypr ? "hypr-exec" : "exec",
                    app.name, argv.join(" "))
            } else if (desktopId.length > 0) {
                const line = "gtk-launch " + appState.shellQuote(desktopId)
                if (viaHypr)
                    Island.hyprEval("hl.exec_cmd([=[" + line + "]=])")
                else
                    Quickshell.execDetached(["gtk-launch", desktopId])
                launched = true
                console.info("[launcher] gtk-launch", app.name, desktopId)
            } else if (typeof entry.execute === "function") {
                try {
                    entry.execute()
                    launched = true
                    console.info("[launcher] execute()", app.name)
                } catch (e) {
                    console.warn("[launcher] execute() failed", app.name, e)
                }
            }

            if (launched)
                Apps.recordLaunch(app.name)
            root.closeWindow()
        }

        function cleanCommand(cmd) {
            if (!cmd || cmd.length === undefined)
                return []
            const out = []
            for (let i = 0; i < cmd.length; i++) {
                const a = String(cmd[i] || "").trim()
                if (!a.length)
                    continue
                if (a === "%%") {
                    out.push("%")
                    continue
                }
                if (/^%[a-zA-Z]$/.test(a))
                    continue
                out.push(a)
            }
            return out
        }

        function shellQuote(s) {
            return "'" + String(s).replace(/'/g, "'\\''") + "'"
        }

        function shellJoin(argv) {
            const parts = []
            for (let i = 0; i < argv.length; i++)
                parts.push(appState.shellQuote(argv[i]))
            return parts.join(" ")
        }
    }

    // ---- 容器装配（顺序即出场顺序：列表在上、先出；搜索框在下、后出）----
    Component { id: appListCard; AppListCard { sharedState: appState } }
    Component { id: appSearchCard; AppSearchCard { sharedState: appState } }
}
