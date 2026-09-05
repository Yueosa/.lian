.pragma library

// App 搜索 / 排序 / 图标规范化 — 从 quickshell/JS/AppManager.js 迁入

function normalizeIconMeta(rawIcon, appName) {
    let iconKey = (rawIcon || "").toLowerCase()
    let nameKey = (appName || "").toLowerCase()

    if (iconKey === "fcitx") {
        return {
            icon: "image://icon/org.fcitx.Fcitx5",
            fallbackIcon: "org.fcitx.Fcitx5",
            forceGlyph: false,
            glyph: "keyboard"
        }
    }

    if (iconKey === "network-wired" || nameKey.indexOf("avahi") === 0) {
        return {
            icon: "image://icon/network-wired-symbolic",
            fallbackIcon: "network-wired-symbolic",
            forceGlyph: false,
            glyph: "lan"
        }
    }

    if (iconKey === "preferences-desktop-theme" || nameKey.indexOf("qt6") === 0) {
        return {
            icon: "image://icon/preferences-system-symbolic",
            fallbackIcon: "preferences-system-symbolic",
            forceGlyph: false,
            glyph: "tune"
        }
    }

    if (iconKey === "hwloc" || nameKey.indexOf("hardware") === 0) {
        return {
            icon: "",
            fallbackIcon: "",
            forceGlyph: true,
            glyph: "memory"
        }
    }

    if (rawIcon && rawIcon.indexOf("/") === -1) {
        return {
            icon: "image://icon/" + rawIcon,
            fallbackIcon: rawIcon,
            forceGlyph: false,
            glyph: "apps"
        }
    }

    return {
        icon: rawIcon || "",
        fallbackIcon: rawIcon || "",
        forceGlyph: false,
        glyph: "apps"
    }
}

function fuzzySearch(inputText, appName) {
    let lowerInput = inputText.toLowerCase()
    let lowerName = appName.toLowerCase()
    let inputIndex = 0

    for (let i = 0; i < lowerName.length; i++) {
        if (lowerName[i] === lowerInput[inputIndex])
            inputIndex++
        if (inputIndex === lowerInput.length)
            return true
    }
    return false
}

// 「这是不是那四个有自带 SVG 的社交应用」由 Icons.bundledId 判，这里只负责把
// desktop entry 的各个标识字段拼成它要的干草堆。
//
// 这个文件是 .pragma library，够不着 QML 单例，所以判定函数由 Apps.qml 传进来
// （见 buildCatalog 的第三个参数）。原先这儿自己写了一份 detectBundledAppId，
// 跟 TrayItem 那份同名不同解，而且用裸 indexOf("tim") 认 TIM——于是 Timeshift、
// OpenJDK Java Run(tim)e 在启动器里全贴了 QQ 的企鹅。
function appHaystack(app, rawIcon) {
    return [
        (app.name || ""),
        (app.id || ""),
        (app.desktopId || ""),
        (app.desktopFile || ""),
        (app.execString || ""),
        (rawIcon || "")
    ].join(" ").toLowerCase()
}

function usageCount(usageMap, name) {
    const entry = usageMap ? usageMap[name] : null
    if (entry == null)
        return 0
    if (typeof entry === "number")
        return entry
    return entry.count || 0
}

// DesktopEntries → 规范化目录。只在 desktop entries / usage 变化时执行。
// bundledId：Icons.bundledId，理由见 appHaystack 上面
function buildCatalog(DesktopEntries, usageMap, bundledId) {
    const apps = DesktopEntries.applications.values
    const result = []

    for (let i = 0; i < apps.length; i++) {
        const app = apps[i]
        if (app.noDisplay)
            continue

        const rawIcon = app.icon || ""
        const normalized = normalizeIconMeta(rawIcon, app.name || "")
        result.push({
            name: app.name || "",
            searchName: (app.name || "").toLowerCase(),
            icon: normalized.icon,
            fallbackIcon: normalized.fallbackIcon,
            forceGlyph: normalized.forceGlyph,
            materialGlyph: normalized.glyph,
            assetAppId: bundledId ? bundledId(appHaystack(app, rawIcon)) : "",
            usageCount: usageCount(usageMap, app.name),
            appObj: app
        })
    }

    result.sort((a, b) => {
        let countA = a.usageCount
        let countB = b.usageCount
        if (countB !== countA)
            return countB - countA
        let nameA = a.searchName
        let nameB = b.searchName
        if (nameA < nameB) return -1
        if (nameA > nameB) return 1
        return 0
    })

    return result
}

// 已规范化目录 → 搜索结果。输入时只做字符串匹配，不再排序/构造图标元数据。
function filterCatalog(catalog, inputText, limit) {
    const query = (inputText || "").toLowerCase()
    const max = limit || 50
    const result = []

    for (let i = 0; i < catalog.length && result.length < max; i++) {
        const app = catalog[i]
        if (query === "" || fuzzySearch(query, app.searchName))
            result.push(app)
    }

    return result
}
