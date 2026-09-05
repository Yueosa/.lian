pragma Singleton

// ============================================================
// 应用启动器数据 — Apps
// ============================================================
// DesktopEntries 提供应用列表；本地 usage 提供排序权重。
// 搜索 / 排序 / 图标规范化在 AppSearch.js。
// ============================================================
// 对外接口一览：
//
// 属性（readonly）：
//   ready       bool     DesktopEntries 是否已有数据
//   catalog     array    已规范化并排序的完整应用目录
//   rows        model    当前 query 的结果，**增量** ListModel（角色 app）
//   revision    int      rows 内容版本（条数没变但内容变了也会加一）
//   usageMap    object   { name: { count, last } }
//   logoDir     string   qsl/asset/app-logo 绝对路径
//
// 属性（可写）：
//   query       string   搜索词，视图直接写；写完 rows 自己增量对齐
//
// 方法：
//   search(query)        → 过滤排序后的应用数组（最多 50）
//   recordLaunch(name)   记录一次启动并异步落盘
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io
// 自带 SVG 的应用识别走 Icons，见那边的注释
import qs.data.service
import "AppSearch.js" as AppSearch
import "../service/rowsync.js" as RowSync

Singleton {
    id: root

    readonly property string usagePath:
        Quickshell.env("HOME") + "/.cache/qsl/app_usage.json"
    readonly property string legacyUsagePath:
        Quickshell.env("HOME") + "/.cache/quickshell/launcher_usage.json"

    readonly property string logoDir:
        Quickshell.shellDir + "/asset/app-logo"

    readonly property bool ready:
        DesktopEntries.applications.values.length > 0

    property var usageMap: ({})
    property var catalog: []

    // ---- 搜索结果：增量模型 ----
    //
    // 视图不直接吃 search() 的返回值：那是每次新建的 JS 数组，ListView 只能整体
    // 重建，add / remove / displaced 过渡压根没机会播——搜索时看到的就是「列表
    // 内容整帧换掉、只有容器高度在动」。改成把差异增量搬进 ListModel（同
    // Network / Volume / Updates，算法见 data/service/rowsync.js），留下来的行
    // 于是会滑动、走掉的行会淡出。
    //
    // 键取应用名：filterCatalog 交回的是 catalog 里的**同一批对象引用**，本可以
    // 按身份比；但 rebuildCatalog 会重造这些字面量对象（装了新应用、usage 变了），
    // 那时按身份就成了「全删全增」。按名字比，重造只会走 setProperty 原地换值
    property string query: ""
    readonly property var rows: _rowsModel
    readonly property int revision: _rev
    property int _rev: 0

    ListModel {
        id: _rowsModel
        dynamicRoles: true
    }

    // ---- 行级过渡：筛掉的时候播，回灌的时候不播 ----
    //
    // 模型永远走增量（RowSync 保住条目身份：幸存的行连 delegate 都不重建，
    // 图标不用重解码），但**动画**分方向：
    //
    // 删——便宜。sync 把连续段并成一次 remove，事务数 = 幸存段数（一般个位
    //     数），每个幸存行只被顶一次，displaced 能一路播完。敲字筛列表因此
    //     整条都是动画的：行往上收、容器高度跟着收，读起来就是「筛掉了」。
    // 增——贵。ListModel 没有批量插入接口，从 2 行回灌到 50 行要插 48 次，每次
    //     都把幸存的那几行往下顶一格、各带一次动画。于是一个本该排在第 30 位的
    //     应用会先出现在第 1 屏、再被一格一格顶出视野——「本该在其他页的应用跑到
    //     第一页然后迅速消失」就是它，48 串动画同时跑就是那阵卡顿。所以回灌那
    //     一拍让位置瞬间落定，由**容器高度**那条动画承担过渡，模型换成便宜的
    //     RowSync.overwrite（那边还记着「为什么不能清空重填」）。
    // 阈值取可见行数
    readonly property int incrementalBudget: 6
    property bool bulkChange: false

    onQueryChanged: syncRows()

    // 键取应用名，不取对象身份：理由见 rows 上面那段
    function rowKey(a) { return a.name }

    function syncRows() {
        const list = search(query)
        const d = RowSync.delta(_rowsModel, list, "app", rowKey)
        bulkChange = d.added > incrementalBudget
        if (bulkChange)
            RowSync.overwrite(_rowsModel, list, "app")
        else
            RowSync.sync(_rowsModel, list, "app", rowKey)
        _rev++
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.rebuildCatalog() }
    }

    Component.onCompleted: rebuildCatalog()

    FileView {
        id: usageFile
        path: root.usagePath
        onLoaded: {
            try {
                const parsed = JSON.parse(text())
                if (parsed && typeof parsed === "object") {
                    root.usageMap = normalizeUsage(parsed)
                    root.rebuildCatalog()
                }
            } catch (e) {}
        }
        onLoadFailed: {
            // 首次无文件：尝试从旧 quickshell usage 迁移 count
            legacyUsageFile.reload()
        }
    }

    FileView {
        id: legacyUsageFile
        path: root.legacyUsagePath
        onLoaded: {
            if (Object.keys(root.usageMap).length > 0)
                return
            try {
                const parsed = JSON.parse(text())
                if (parsed && typeof parsed === "object") {
                    root.usageMap = normalizeUsage(parsed)
                    root.rebuildCatalog()
                    root.persistUsage()
                }
            } catch (e) {}
        }
    }

    function normalizeUsage(raw) {
        const out = {}
        for (const key in raw) {
            const v = raw[key]
            if (typeof v === "number")
                out[key] = { count: v, last: 0 }
            else if (v && typeof v === "object")
                out[key] = { count: v.count || 0, last: v.last || 0 }
        }
        return out
    }

    function rebuildCatalog() {
        // Icons.bundledId 得当参数递进去：AppSearch.js 是 .pragma library，够不着单例
        catalog = ready
            ? AppSearch.buildCatalog(DesktopEntries, usageMap, Icons.bundledId)
            : []
        syncRows()
    }

    function search(query) {
        return AppSearch.filterCatalog(catalog, query || "", 50)
    }

    function recordLaunch(name) {
        if (!name)
            return
        const next = Object.assign({}, root.usageMap)
        const prev = next[name] || { count: 0, last: 0 }
        next[name] = { count: (prev.count || 0) + 1, last: Date.now() }
        root.usageMap = next
        root.rebuildCatalog()
        root.persistUsage()
    }

    function persistUsage() {
        const dir = usagePath.replace(/\/[^/]*$/, "")
        const json = JSON.stringify(root.usageMap)
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p " + JSON.stringify(dir) +
            " && printf '%s' " + JSON.stringify(json) +
            " > " + JSON.stringify(usagePath)])
    }
}
