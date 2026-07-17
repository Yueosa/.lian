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
//   usageMap    object   { name: { count, last } }
//   logoDir     string   qsl/asset/app-logo 绝对路径
//
// 方法：
//   search(query)        → 过滤排序后的应用数组（最多 50）
//   recordLaunch(name)   记录一次启动并异步落盘
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io
import "AppSearch.js" as AppSearch

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
        catalog = ready ? AppSearch.buildCatalog(DesktopEntries, usageMap) : []
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
