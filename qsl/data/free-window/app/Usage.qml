pragma Singleton

-- ============================================================
-- 应用服务 — App
-- ============================================================
-- 从 DesktopEntries（系统 .desktop 文件注册表）获取应用列表，
-- 合并本地使用统计（次数 + 最后启动时间）。
-- 搜索和排序由 AppManager.js 处理，本模块只负责原始数据。
-- ============================================================
-- 对外接口一览：
--
-- 属性（readonly）：
--   allApps       array    全部应用 [{name, icon, appObj, ...}]
--   usageMap      object   { name: { count: N, last: timestamp_ms } }
--   ready         bool     DesktopEntries 是否已加载完毕
--
-- 方法：
--   recordLaunch(name)     记录一次启动
-- ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string usagePath:
        Quickshell.env("HOME") + "/.cache/qsl/app_usage.json"

    readonly property bool ready: DesktopEntries.applications.values.length > 0

    property var usageMap: ({})

    // === 使用记录读写 ===
    FileView {
        id: usageFile
        path: root.usagePath
        onLoaded: {
            try {
                let p = JSON.parse(text())
                if (p && typeof p === "object") root.usageMap = p
            } catch (e) {}
        }
    }

    function recordLaunch(name) {
        let m = Object.assign({}, root.usageMap)
        m[name] = { count: (m[name]?.count || 0) + 1, last: Date.now() }
        root.usageMap = m
        // 异步落盘，不阻塞 UI
        let dir = usagePath.replace(/\/[^/]*$/, "")
        let json = JSON.stringify(m)
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p " + JSON.stringify(dir) + " && printf '%s' " + JSON.stringify(json) + " > " + JSON.stringify(usagePath)])
    }
}
