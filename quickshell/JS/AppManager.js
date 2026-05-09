.pragma library

function normalizeIconMeta(rawIcon, appName) {
    let iconKey = (rawIcon || "").toLowerCase();
    let nameKey = (appName || "").toLowerCase();

    if (iconKey === "fcitx") {
        return {
            icon: "image://icon/org.fcitx.Fcitx5",
            fallbackIcon: "org.fcitx.Fcitx5",
            forceGlyph: false,
            glyph: "keyboard"
        };
    }

    if (iconKey === "network-wired" || nameKey.indexOf("avahi") === 0) {
        return {
            icon: "image://icon/network-wired-symbolic",
            fallbackIcon: "network-wired-symbolic",
            forceGlyph: false,
            glyph: "lan"
        };
    }

    if (iconKey === "preferences-desktop-theme" || nameKey.indexOf("qt6") === 0) {
        return {
            icon: "image://icon/preferences-system-symbolic",
            fallbackIcon: "preferences-system-symbolic",
            forceGlyph: false,
            glyph: "tune"
        };
    }

    if (iconKey === "hwloc" || nameKey.indexOf("hardware") === 0) {
        return {
            icon: "",
            fallbackIcon: "",
            forceGlyph: true,
            glyph: "memory"
        };
    }

    if (rawIcon && rawIcon.indexOf("/") === -1) {
        return {
            icon: "image://icon/" + rawIcon,
            fallbackIcon: rawIcon,
            forceGlyph: false,
            glyph: "apps"
        };
    }

    return {
        icon: rawIcon || "",
        fallbackIcon: rawIcon || "",
        forceGlyph: false,
        glyph: "apps"
    };
}

function fuzzySearch(inputText, appName) {
    let lowerInput = inputText.toLowerCase();
    let lowerName = appName.toLowerCase();
    let inputIndex = 0;

    for (let i = 0; i < lowerName.length; i++) {
        if (lowerName[i] === lowerInput[inputIndex]) {
            inputIndex++;
        }
        if (inputIndex === lowerInput.length) {
            return true;
        }
    }
    return false;
}

function updateFilter(inputText, DesktopEntries, usageCounts) {
    let lowerInput = (inputText || "").toLowerCase();
    let counts = usageCounts || {};
    const apps = DesktopEntries.applications.values;
    let filterApps = [];

    if (lowerInput === "") {
        filterApps = apps;
    } else {
        filterApps = apps.filter((app) => fuzzySearch(lowerInput, app.name));
    }

    // 过滤掉不可见的后台挂件
    filterApps = filterApps.filter(app => !app.noDisplay);

    // 强制按首字母 A-Z 排序
    filterApps.sort((a, b) => {
        let countA = counts[a.name] || 0;
        let countB = counts[b.name] || 0;
        if (countB !== countA) return countB - countA;
        let nameA = a.name ? a.name.toLowerCase() : "";
        let nameB = b.name ? b.name.toLowerCase() : "";
        if (nameA < nameB) return -1;
        if (nameA > nameB) return 1;
        return 0;
    });

    let result = [];
    function detectBundledAppId(app, rawIcon) {
        const text = [
            (app.name || ""),
            (app.id || ""),
            (app.desktopId || ""),
            (app.desktopFile || ""),
            (app.execString || ""),
            (rawIcon || "")
        ].join(" ").toLowerCase();

        if (text.indexOf("telegram") >= 0)
            return "telegram";
        if (text.indexOf("wechat") >= 0 || text.indexOf("weixin") >= 0)
            return "wechat";
        if (text.indexOf("discord") >= 0)
            return "discord";
        if (text.indexOf("linuxqq") >= 0 || text.indexOf("tim") >= 0)
            return "qq";

        return "";
    }

    for (let i = 0; i < filterApps.length; i++) {
        let app = filterApps[i];
        
        let rawIcon = app.icon || "";
        let normalized = normalizeIconMeta(rawIcon, app.name || "");
        let assetAppId = detectBundledAppId(app, rawIcon);

        result.push({
            name: app.name,
            icon: normalized.icon,
            fallbackIcon: normalized.fallbackIcon,
            forceGlyph: normalized.forceGlyph,
            materialGlyph: normalized.glyph,
            assetAppId: assetAppId,
            appObj: app 
        });
        
        if (result.length >= 50) break;
    }

    return result;
}
