// TilePanel — X 面板壳（磁贴 / IPC tiles），从 bottomrail 右段长出来
//
// 底 rail 上第三段：A 中段、Z 左段、X 右段，三个互不重叠所以彼此**不互斥**。
// 互斥组给的是 "right"：X 那块地方压着 V/N 那一列的下半截（V 的更新页能长到
// 屏幕下半截，两个都开就叠在一起）。这也是它不该和 Z 抢左段的原因。
//
// 一个容器一张卡。卡里分两区，Tab 切：
//   执行区  点一下就跑（开网页 / 执行命令）
//   服务区  点一下 start/stop 一组 systemd --user unit，显示当前状态
//
// 两区在**卡内部**切而不是走 RailPage 的翻页：翻页每次都是整卡退场 + 重新
// 派生（~600ms），三个磁贴的小卡上那一下太重。见 RailPage.tabPressed。
//
// 清单在 asset/tiles.json（改完存盘即生效），动作在 data/service/Tiles.qml，
// 服务状态与启停在 data/service/Systemd.qml。

import QtQuick
import qs.Components
import qs.data.service
import qs.data.state

RailPage {
    id: root

    edge: "bottom"
    halign: "right"
    shellNamespace: "qsl-tiles"
    panelGroup: "right"
    containerWidth: Size.panel.xWidth

    order: ["tiles"]
    page: "tiles"
    pages: ({
        tiles: { title: "磁贴", containers: [tileCard] }
    })

    // 切区换行数 → 卡高度变。这么小的卡上过冲很明显（长过头再缩回来），
    // 换成不过冲的一档，同 A / Z
    elasticType: Anim.EnterFast

    // 条带高度 = inputMask 高度，取内容上界（两行磁贴）而不是跟着卡高度抖
    stripHeight: 16 + tileState.maxCardH + 24

    // Tab / Shift+Tab 切区（默认是翻页，这里只有一页）
    function tabPressed(step) {
        tileState.cycleZone(step)
    }

    onOpenChanged: {
        if (open) {
            tileState.reset()
            // Binding 写 active/units 和这次求值同帧，refresh 太早会看见
            // active 还是 false。隔一拍再查
            Qt.callLater(() => Systemd.refresh())
        }
    }

    // 服务状态只在面板开着的时候查（Systemd 那边不空转轮询）
    Binding {
        target: Systemd
        property: "active"
        value: root.open
    }
    Binding {
        target: Systemd
        property: "units"
        value: Tiles.svcUnits
    }

    // ---- 卡与壳共享的状态 ----
    QtObject {
        id: tileState

        // ---- 分区 ----
        property string zone: "run"
        // 不按 open 门控（关窗时清空）：磁贴只是几行元数据，留着不占内存，而
        // 清空会让退场那一拍格子先凭空消失、卡里空一块。Z 的 release 就是
        // 这么栽的（模型在关窗那帧归零，退场动画还在播）
        readonly property var tiles: zone === "run" ? Tiles.run : Tiles.svc
        readonly property bool isSvc: zone === "svc"

        // ---- 几何 ----
        readonly property int columns: 3
        readonly property int pad: Size.spacing.sm
        readonly property int gap: Size.spacing.sm
        readonly property int tabH: 40
        readonly property int tileH: 88
        readonly property int innerW: root.containerWidth - 2 * pad
        readonly property int tileW: Math.floor(
            (innerW - (columns - 1) * gap) / columns)

        readonly property int rowCount: Math.max(1,
            Math.ceil(tiles.length / columns))
        readonly property int gridH: rowCount * tileH + (rowCount - 1) * gap
        // 上界按两行算（现在每区 3 格 = 1 行，加到 6 格才第二行）
        readonly property int maxCardH: tabH + pad + 2 * tileH + gap + pad

        // ---- 选择 ----
        property int current: 0

        // 焦点请求：卡在 Loader 里，Loader 是 focus scope，光声明 focus 传不
        // 出去（同 Z 的搜索条 / A 的搜索框）。卡里盯着这个数把 activeFocus 抢回来
        property int focusTick: 0

        function reset() {
            zone = "run"
            current = 0
            focusTick += 1
        }

        function cycleZone(step) {
            zone = (zone === "run") ? "svc" : "run"
            current = 0
        }

        // ←→ 线性绕回（到头接另一端），同 A 的列表
        function moveSide(d) {
            const n = tiles.length
            if (n === 0)
                return
            current = (current + d + n) % n
        }

        // ↑↓ 按列走：末行可能不满，所以沿着同一列往上/往下找**存在**的那一格，
        // 一路找到就停，绕回起点则不动
        function move(d) {
            const n = tiles.length
            if (n === 0)
                return
            const c = columns
            const rows = Math.ceil(n / c)
            const col = current % c
            let r = Math.floor(current / c)
            for (let k = 0; k < rows; k++) {
                r = (r + d + rows) % rows
                const idx = r * c + col
                if (idx < n) {
                    current = idx
                    return
                }
            }
        }

        function activate(i) {
            const t = tiles[i]
            if (!t)
                return
            if (isSvc) {
                // 服务区**不关窗**：点下去是为了看状态翻过来
                Systemd.toggleGroup(t.units)
                return
            }
            // 执行区关窗：人要去浏览器/那个程序了，面板留着挡视线
            Tiles.activate(t)
            root.closeWindow()
        }

        function activateCurrent() {
            activate(current)
        }
    }

    // 清单重载（tiles.json 存盘）后把选择夹回范围内
    Connections {
        target: Tiles
        function onReadyChanged() { tileState.current = 0 }
    }

    Component {
        id: tileCard
        TileCard { sharedState: tileState }
    }
}
