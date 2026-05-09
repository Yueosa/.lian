pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string colorsPath: Quickshell.env("HOME") + "/.cache/quickshell_colors.json"
    readonly property string modePath: Quickshell.env("HOME") + "/.cache/quickshell_theme_mode"
    readonly property string wallpaperLinkPath: Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current"
    readonly property string wallpaperDisplayPreviewPath: Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current_preview"
    readonly property string localThemeScriptPath: Qt.resolvedUrl("../scripts/update_theme_from_wallpaper.sh").toString().replace("file://", "")
    property string matugenMode: "auto"
    property var generatedColors: ({})
    property QtObject m3colors
    property QtObject colors
    property bool _modeLoaded: false
    property string _lastWallpaperRealPath: ""
    property int wallpaperPreviewVersion: 0
    property var _animFromMap: ({})
    property var _animToMap: ({})
    property int _animStep: 0
    readonly property int _animSteps: 14
    property bool _readingThemeMode: false
    readonly property bool shouldUseGeneratedPalette: matugenMode.toLowerCase() === "auto"
    readonly property bool hasGeneratedSourceColor: {
        const raw = generatedColors["source_color"] || generatedColors["primary"];
        return !!raw;
    }

    // matugen / 亮度脚本写入 _mode 字段：cache 色值实际是哪个 variant 生成的。
    readonly property string generatedMode: {
        const v = (generatedColors["_mode"] || "").toString().toLowerCase();
        return (v === "light" || v === "dark") ? v : "";
    }

    // _mode_auto 是脚本始终独立计算的「壁纸亮度判定」结果，
    // 不受用户当前强制模式干扰。AUTO 模式下用它决定基线 palette。
    readonly property string generatedAutoMode: {
        const v = (generatedColors["_mode_auto"] || "").toString().toLowerCase();
        return (v === "light" || v === "dark") ? v : "";
    }

    // 当前模式下，cache 色值「应该」是哪个 variant：
    //   LIGHT / DARK 强制：不叠加 matugen，留空让覆盖被禁用，基线永远纯净
    //   AUTO：跟壁纸亮度判定（_mode_auto），覆盖只在 cache 已与之一致时才发生
    readonly property string expectedGeneratedMode: {
        const mode = matugenMode.toLowerCase();
        if (mode === "auto")
            return generatedAutoMode;  // 空字符串表示尚未判定，会跳过覆盖
        return "";  // light / dark 不使用 matugen 叠加
    }

    // cache 色值是否与 AUTO 当前期望一致。
    // 不一致时（典型：刚切到 auto，脚本还没异步以新亮度重写 cache）禁止覆盖基线，
    // 等 colorFile.onLoaded 在新 cache 写出后会自动 apply 一次。
    readonly property bool generatedColorsAreCurrent: {
        if (!hasGeneratedSourceColor)
            return false;
        const expect = expectedGeneratedMode;
        if (expect === "")
            return false;
        return generatedMode === expect;
    }

    readonly property string effectiveMatugenMode: {
        const mode = matugenMode.toLowerCase();
        if (mode === "light" || mode === "dark" || mode === "auto")
            return mode;
        return "dark";
    }

    // Light: 粉蓝白；Dark: 黑莓系粉蓝白。
    readonly property var lightPalette: ({
        background: "#f7f8ff",
        error: "#ba1a1a",
        error_container: "#ffdad6",
        inverse_on_surface: "#eff0ff",
        inverse_primary: "#f3b4d6",
        inverse_surface: "#2e3142",
        on_background: "#1b1d2a",
        on_error: "#ffffff",
        on_error_container: "#410002",
        on_primary: "#ffffff",
        on_primary_container: "#5d1042",
        on_primary_fixed: "#3b0025",
        on_primary_fixed_variant: "#7a2c5c",
        on_secondary: "#ffffff",
        on_secondary_container: "#1f2a5b",
        on_secondary_fixed: "#08113b",
        on_secondary_fixed_variant: "#37467e",
        on_surface: "#1b1d2a",
        on_surface_variant: "#44485c",
        on_tertiary: "#ffffff",
        on_tertiary_container: "#5b1e57",
        on_tertiary_fixed: "#3a0038",
        on_tertiary_fixed_variant: "#73386e",
        outline: "#74788d",
        outline_variant: "#c4c7dc",
        primary: "#b53f80",
        primary_container: "#ffd9ea",
        primary_fixed: "#ffd9ea",
        primary_fixed_dim: "#f3b4d6",
        scrim: "#3d1d34",
        secondary: "#4d5ba7",
        secondary_container: "#dfe1ff",
        secondary_fixed: "#dfe1ff",
        secondary_fixed_dim: "#c1c5ff",
        shadow: "#d879b2",
        source_color: "#e79ac8",
        surface: "#fbf8ff",
        surface_bright: "#fbf8ff",
        surface_container: "#efecf7",
        surface_container_high: "#e8e6f2",
        surface_container_highest: "#e2dfec",
        surface_container_low: "#f5f2fd",
        surface_container_lowest: "#ffffff",
        surface_dim: "#dcd9e4",
        surface_tint: "#b53f80",
        surface_variant: "#e1e2f3",
        tertiary: "#8a4d84",
        tertiary_container: "#ffd6f6",
        tertiary_fixed: "#ffd6f6",
        tertiary_fixed_dim: "#f5b1eb"
    })

    readonly property var darkPalette: ({
        background: "#0f1416",
        error: "#ffb4ab",
        error_container: "#93000a",
        inverse_on_surface: "#2c3134",
        inverse_primary: "#09677f",
        inverse_surface: "#dee3e6",
        on_background: "#dee3e6",
        on_error: "#690005",
        on_error_container: "#ffdad6",
        on_primary: "#003544",
        on_primary_container: "#b8eaff",
        on_primary_fixed: "#001f28",
        on_primary_fixed_variant: "#004d61",
        on_secondary: "#1e333c",
        on_secondary_container: "#cfe6f1",
        on_secondary_fixed: "#071e26",
        on_secondary_fixed_variant: "#354a53",
        on_surface: "#dee3e6",
        on_surface_variant: "#bfc8cc",
        on_tertiary: "#2c2d4d",
        on_tertiary_container: "#e1e0ff",
        on_tertiary_fixed: "#171837",
        on_tertiary_fixed_variant: "#434465",
        outline: "#8a9296",
        outline_variant: "#40484c",
        primary: "#88d0ec",
        primary_container: "#004d61",
        primary_fixed: "#b8eaff",
        primary_fixed_dim: "#88d0ec",
        scrim: "#210f1d",
        secondary: "#b3cad5",
        secondary_container: "#354a53",
        secondary_fixed: "#cfe6f1",
        secondary_fixed_dim: "#b3cad5",
        shadow: "#000000",
        source_color: "#669cb1",
        surface: "#0f1416",
        surface_bright: "#353a3d",
        surface_container: "#1b2023",
        surface_container_high: "#252b2d",
        surface_container_highest: "#303638",
        surface_container_low: "#171c1f",
        surface_container_lowest: "#0a0f11",
        surface_dim: "#0f1416",
        surface_tint: "#88d0ec",
        surface_variant: "#40484c",
        tertiary: "#c3c3eb",
        tertiary_container: "#434465",
        tertiary_fixed: "#e1e0ff",
        tertiary_fixed_dim: "#c3c3eb"
    })

    // Auto: 独立基线，不复用 light/dark；壁纸色只在 auto 模式下叠加到这一套。
    readonly property var autoPalette: ({
        background: "#16171f",
        error: "#ffb4ab",
        error_container: "#8f2d31",
        inverse_on_surface: "#2a2936",
        inverse_primary: "#8a6f8f",
        inverse_surface: "#ece6f0",
        on_background: "#ece6f0",
        on_error: "#690005",
        on_error_container: "#ffdad6",
        on_primary: "#1d1122",
        on_primary_container: "#f8d8ff",
        on_primary_fixed: "#140818",
        on_primary_fixed_variant: "#51385a",
        on_secondary: "#1f1b2a",
        on_secondary_container: "#e5def5",
        on_secondary_fixed: "#171320",
        on_secondary_fixed_variant: "#4c475c",
        on_surface: "#ece6f0",
        on_surface_variant: "#c8bfd3",
        on_tertiary: "#291a1e",
        on_tertiary_container: "#ffd9e1",
        on_tertiary_fixed: "#1d0f13",
        on_tertiary_fixed_variant: "#5b3e45",
        outline: "#968ca2",
        outline_variant: "#4a4355",
        primary: "#ddbce4",
        primary_container: "#51385a",
        primary_fixed: "#f8d8ff",
        primary_fixed_dim: "#ddbce4",
        scrim: "#000000",
        secondary: "#c9c2d8",
        secondary_container: "#4c475c",
        secondary_fixed: "#e5def5",
        secondary_fixed_dim: "#c9c2d8",
        shadow: "#000000",
        source_color: "#b79cc1",
        surface: "#16171f",
        surface_bright: "#3d3c49",
        surface_container: "#1f2029",
        surface_container_high: "#2a2a34",
        surface_container_highest: "#34343f",
        surface_container_low: "#1b1b24",
        surface_container_lowest: "#111119",
        surface_dim: "#16171f",
        surface_tint: "#ddbce4",
        surface_variant: "#4a4355",
        tertiary: "#efb8c5",
        tertiary_container: "#5b3e45",
        tertiary_fixed: "#ffd9e1",
        tertiary_fixed_dim: "#efb8c5"
    })

    // 兼容层：保留旧字段，避免一次性修改所有组件。
    readonly property color background: m3colors.m3background
    readonly property color error: m3colors.m3error
    readonly property color error_container: m3colors.m3errorContainer
    readonly property color inverse_on_surface: m3colors.m3inverseOnSurface
    readonly property color inverse_primary: m3colors.m3inversePrimary
    readonly property color inverse_surface: m3colors.m3inverseSurface
    readonly property color on_background: m3colors.m3onBackground
    readonly property color on_error: m3colors.m3onError
    readonly property color on_error_container: m3colors.m3onErrorContainer
    readonly property color on_primary: m3colors.m3onPrimary
    readonly property color on_primary_container: m3colors.m3onPrimaryContainer
    readonly property color on_primary_fixed: m3colors.m3onPrimaryFixed
    readonly property color on_primary_fixed_variant: m3colors.m3onPrimaryFixedVariant
    readonly property color on_secondary: m3colors.m3onSecondary
    readonly property color on_secondary_container: m3colors.m3onSecondaryContainer
    readonly property color on_secondary_fixed: m3colors.m3onSecondaryFixed
    readonly property color on_secondary_fixed_variant: m3colors.m3onSecondaryFixedVariant
    readonly property color on_surface: m3colors.m3onSurface
    readonly property color on_surface_variant: m3colors.m3onSurfaceVariant
    readonly property color on_tertiary: m3colors.m3onTertiary
    readonly property color on_tertiary_container: m3colors.m3onTertiaryContainer
    readonly property color on_tertiary_fixed: m3colors.m3onTertiaryFixed
    readonly property color on_tertiary_fixed_variant: m3colors.m3onTertiaryFixedVariant
    readonly property color outline: m3colors.m3outline
    readonly property color outline_variant: m3colors.m3outlineVariant
    readonly property color primary: m3colors.m3primary
    readonly property color primary_container: m3colors.m3primaryContainer
    readonly property color primary_fixed: m3colors.m3primaryFixed
    readonly property color primary_fixed_dim: m3colors.m3primaryFixedDim
    readonly property color scrim: m3colors.m3scrim
    readonly property color secondary: m3colors.m3secondary
    readonly property color secondary_container: m3colors.m3secondaryContainer
    readonly property color secondary_fixed: m3colors.m3secondaryFixed
    readonly property color secondary_fixed_dim: m3colors.m3secondaryFixedDim
    readonly property color shadow: m3colors.m3shadow
    readonly property color source_color: m3colors.m3sourceColor
    readonly property color surface: m3colors.m3surface
    readonly property color surface_bright: m3colors.m3surfaceBright
    readonly property color surface_container: m3colors.m3surfaceContainer
    readonly property color surface_container_high: m3colors.m3surfaceContainerHigh
    readonly property color surface_container_highest: m3colors.m3surfaceContainerHighest
    readonly property color surface_container_low: m3colors.m3surfaceContainerLow
    readonly property color surface_container_lowest: m3colors.m3surfaceContainerLowest
    readonly property color surface_dim: m3colors.m3surfaceDim
    readonly property color surface_tint: m3colors.m3surfaceTint
    readonly property color surface_variant: m3colors.m3surfaceVariant
    readonly property color tertiary: m3colors.m3tertiary
    readonly property color tertiary_container: m3colors.m3tertiaryContainer
    readonly property color tertiary_fixed: m3colors.m3tertiaryFixed
    readonly property color tertiary_fixed_dim: m3colors.m3tertiaryFixedDim

    property string currentWallpaperPreview: "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current"
    property string currentWallpaperDisplayPreview: "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current_preview"

    function updatePreviewUrls(path) {
        if (path && path.length > 0)
            currentWallpaperPreview = "file://" + path;
        currentWallpaperDisplayPreview = "file://" + wallpaperDisplayPreviewPath;
        wallpaperPreviewVersion += 1;
    }

    function refreshThemeByWallpaperPath(path) {
        if (!path || path.length === 0)
            return;
        Quickshell.execDetached(["bash", localThemeScriptPath, path]);
    }

    function refreshFromWallpaperPath(path) {
        if (!path || path.length === 0)
            return;
        _lastWallpaperRealPath = path;
        updatePreviewUrls(path);
        refreshThemeByWallpaperPath(path);
    }

    function snakeToM3(key) {
        const parts = key.split("_");
        let result = "m3" + parts[0];
        for (let i = 1; i < parts.length; i += 1)
            result += parts[i].charAt(0).toUpperCase() + parts[i].slice(1);
        return result;
    }

    function applyPresetColors(mode) {
        // 三个模式：
        //   LIGHT → lightPalette（固定，不叠加 matugen）
        //   DARK  → darkPalette （固定，不叠加 matugen）
        //   AUTO  → 跟壁纸亮度：浅壁纸用 lightPalette，深壁纸用 autoPalette；
        //           叠加 matugen 由 applyTheme 中的 generatedColorsAreCurrent 守门，
        //           cache 与当前期望 variant 不一致时只显示纯基线，避免串色闪烁。
        let palette = darkPalette;
        if (mode === "light")
            palette = lightPalette;
        else if (mode === "auto")
            palette = (generatedAutoMode === "light") ? lightPalette : autoPalette;
        const target = {};
        for (const key in palette) {
            const m3name = snakeToM3(key);
            if (m3name in m3colors)
                target[m3name] = Qt.color(palette[key]);
        }
        return target;
    }

    function applyGeneratedColors(target) {
        for (const key in generatedColors) {
            const m3name = snakeToM3(key);
            if (m3name in m3colors)
                target[m3name] = Qt.color(generatedColors[key]);
        }
        return target;
    }

    function tintThemeForAutoFallback(target) {
        const raw = generatedColors["source_color"] || generatedColors["primary"];
        if (!raw)
            return target;

        let generatedCount = 0;
        for (const key in generatedColors) {
            const m3name = snakeToM3(key);
            if (m3name in m3colors)
                generatedCount += 1;
        }
        const sparse = generatedCount < 8;

        const src = Qt.color(raw);
        const toned = {};
        for (const key in target) {
            const value = target[key];
            if (!value) continue;

            // 永远不动 on_*/inverseOn 等前景色，避免对比度被破坏。
            if (key.indexOf("m3on") === 0 || key === "m3inverseOnSurface") {
                toned[key] = value;
                continue;
            }

            // matugen 输出完整时，仅给 surface/background 家族补一层壁纸染色——
            // matugen 的 surface 默认偏中性灰，不补染就出现「容器永远不变」的现象。
            const isSurfaceFamily = key.indexOf("surface") >= 0
                || key === "m3background"
                || key === "m3scrim"
                || key === "m3surfaceTint";
            if (!sparse && !isSurfaceFamily) {
                toned[key] = value;
                continue;
            }

            let w;
            if (sparse) {
                // 稀疏 cache：所有角色都需要染色。
                if (key === "m3primary" || key === "m3secondary" || key === "m3tertiary") w = 0.42;
                else if (key.indexOf("Container") >= 0 || key.indexOf("Fixed") >= 0) w = 0.28;
                else if (isSurfaceFamily) w = 0.14;
                else if (key === "m3outline" || key === "m3outlineVariant" || key === "m3shadow") w = 0.20;
                else w = 0.10;
            } else {
                // 完整 cache：只给 surface 家族叠一层柔和染色。
                if (key === "m3background" || key === "m3surface" || key === "m3surfaceDim") w = 0.10;
                else if (key === "m3surfaceContainerLowest" || key === "m3surfaceContainerLow") w = 0.12;
                else if (key === "m3surfaceContainer") w = 0.14;
                else if (key === "m3surfaceContainerHigh") w = 0.17;
                else if (key === "m3surfaceContainerHighest" || key === "m3surfaceBright") w = 0.20;
                else if (key === "m3surfaceVariant") w = 0.18;
                else if (key === "m3surfaceTint") w = 0.50;
                else w = 0.12; // scrim 等
            }

            toned[key] = mixColor(value, src, w);
        }
        return toned;
    }

    function mixColor(a, b, t) {
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            a.a + (b.a - a.a) * t
        );
    }

    function snapshotCurrentTheme(targetTheme) {
        const from = {};
        for (const key in targetTheme) {
            if (key in m3colors)
                from[key] = Qt.color(m3colors[key]);
        }
        return from;
    }

    function commitTheme(theme) {
        for (const key in theme) {
            if (key in m3colors)
                m3colors[key] = theme[key];
        }
    }

    function animateTheme(targetTheme) {
        _animFromMap = snapshotCurrentTheme(targetTheme);
        _animToMap = targetTheme;
        _animStep = 0;
        if (themeTransitionTimer.running)
            themeTransitionTimer.stop();
        themeTransitionTimer.start();
    }

    function applyTheme(animated = true) {
        let targetTheme = applyPresetColors(matugenMode.toLowerCase());
        // 仅当 cache 色值的 _mode 与当前应呈现的 mode 一致时，才用 cache 覆盖基线。
        // 这样避免 dark→auto 浅壁纸时，cache 还是 dark variant 把基线染暗的闪烁；
        // 等异步脚本以新模式重写 cache 后，colorFile.onLoaded 会自动再 apply 一次。
        if (shouldUseGeneratedPalette && generatedColorsAreCurrent) {
            targetTheme = applyGeneratedColors(targetTheme);
            targetTheme = tintThemeForAutoFallback(targetTheme);
        }

        if (animated)
            animateTheme(targetTheme);
        else
            commitTheme(targetTheme);
    }

    function normalizeMode(mode) {
        const value = (mode || "").toLowerCase().trim();
        if (value === "light" || value === "dark" || value === "auto")
            return value;
        return "auto";
    }

    function persistMode() {
        const escapedPath = modePath.replace(/'/g, "'\\''");
        const escapedMode = matugenMode.replace(/'/g, "'\\''");
        Quickshell.execDetached([
            "bash",
            "-lc",
            "mkdir -p \"$(dirname '" + escapedPath + "')\" && printf '%s\\n' '" + escapedMode + "' > '" + escapedPath + "'"
        ]);
    }

    onMatugenModeChanged: {
        const normalized = normalizeMode(matugenMode);
        if (normalized !== matugenMode) {
            matugenMode = normalized;
            return;
        }

        if (_modeLoaded)
            persistMode();

        // 即使 effectiveMatugenMode 不变（例如 auto->light 且都为 light），
        // 也要重算主题，避免保留 auto 染色结果。
        applyTheme(true);

        if (!refreshThemeFromCurrentWallpaper.running)
            refreshThemeFromCurrentWallpaper.running = true;

    }

    onEffectiveMatugenModeChanged: applyTheme(true)

    Component.onCompleted: {
        readThemeMode.running = true;
        refreshThemeFromCurrentWallpaper.running = true;
        pollCurrentWallpaper.running = true;
        applyTheme(false);
    }

    Timer {
        id: themeTransitionTimer
        interval: 16
        repeat: true
        running: false
        onTriggered: {
            root._animStep += 1;
            const t = Math.min(1, root._animStep / root._animSteps);
            for (const key in root._animToMap) {
                const from = root._animFromMap[key];
                const to = root._animToMap[key];
                if (!from || !to)
                    continue;
                if (key in root.m3colors)
                    root.m3colors[key] = root.mixColor(from, to, t);
            }

            if (t >= 1)
                stop();
        }
    }

    Process {
        id: readThemeMode
        command: ["bash", "-lc", "if [ -f \"$HOME/.cache/quickshell_theme_mode\" ]; then cat \"$HOME/.cache/quickshell_theme_mode\"; fi"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const loadedMode = root.normalizeMode(data.trim());
                root.matugenMode = loadedMode;
            }
        }
        onExited: {
            root._readingThemeMode = false;
            const firstLoad = !root._modeLoaded;
            root._modeLoaded = true;
            if (firstLoad)
                root.persistMode();
        }
    }

    function requestThemeModeReload() {
        if (readThemeMode.running || _readingThemeMode)
            return;
        _readingThemeMode = true;
        readThemeMode.running = true;
    }

    m3colors: QtObject {
        property color m3background
        property color m3error
        property color m3errorContainer
        property color m3inverseOnSurface
        property color m3inversePrimary
        property color m3inverseSurface
        property color m3onBackground
        property color m3onError
        property color m3onErrorContainer
        property color m3onPrimary
        property color m3onPrimaryContainer
        property color m3onPrimaryFixed
        property color m3onPrimaryFixedVariant
        property color m3onSecondary
        property color m3onSecondaryContainer
        property color m3onSecondaryFixed
        property color m3onSecondaryFixedVariant
        property color m3onSurface
        property color m3onSurfaceVariant
        property color m3onTertiary
        property color m3onTertiaryContainer
        property color m3onTertiaryFixed
        property color m3onTertiaryFixedVariant
        property color m3outline
        property color m3outlineVariant
        property color m3primary
        property color m3primaryContainer
        property color m3primaryFixed
        property color m3primaryFixedDim
        property color m3scrim
        property color m3secondary
        property color m3secondaryContainer
        property color m3secondaryFixed
        property color m3secondaryFixedDim
        property color m3shadow
        property color m3sourceColor
        property color m3surface
        property color m3surfaceBright
        property color m3surfaceContainer
        property color m3surfaceContainerHigh
        property color m3surfaceContainerHighest
        property color m3surfaceContainerLow
        property color m3surfaceContainerLowest
        property color m3surfaceDim
        property color m3surfaceTint
        property color m3surfaceVariant
        property color m3tertiary
        property color m3tertiaryContainer
        property color m3tertiaryFixed
        property color m3tertiaryFixedDim
    }

    colors: QtObject {
        property color colLayer0: root.m3colors.m3background
        property color colOnLayer0: root.m3colors.m3onBackground
        property color colLayer1: root.m3colors.m3surfaceContainerLow
        property color colOnLayer1: root.m3colors.m3onSurfaceVariant
        property color colLayer2: root.m3colors.m3surfaceContainer
        property color colOnLayer2: root.m3colors.m3onSurface
        property color colLayer3: root.m3colors.m3surfaceContainerHigh
        property color colOnLayer3: root.m3colors.m3onSurface
        property color colLayer4: root.m3colors.m3surfaceContainerHighest
        property color colOnLayer4: root.m3colors.m3onSurface

        property color colPrimary: root.m3colors.m3primary
        property color colOnPrimary: root.m3colors.m3onPrimary
        property color colSecondary: root.m3colors.m3secondary
        property color colOnSecondary: root.m3colors.m3onSecondary
        property color colTertiary: root.m3colors.m3tertiary
        property color colOnTertiary: root.m3colors.m3onTertiary

        property color colError: root.m3colors.m3error
        property color colOnError: root.m3colors.m3onError
        property color colOutline: root.m3colors.m3outline
        property color colOutlineVariant: root.m3colors.m3outlineVariant
    }

    Process {
        id: refreshThemeFromCurrentWallpaper
        command: [
            "bash",
            "-lc",
            "wp=$(readlink -f \"$HOME/.cache/wallpaper_rofi/current\" 2>/dev/null || true); " +
            "if [ -n \"$wp\" ] && [ -f \"$wp\" ]; then " +
            "bash '" + root.localThemeScriptPath.replace(/'/g, "'\\''") + "' \"$wp\" '" + root.matugenMode.replace(/'/g, "'\\''") + "' >/dev/null 2>&1; fi"
        ]
        running: false
    }

    Process {
        id: readCurrentWallpaperPath
        command: ["bash", "-lc", "readlink -f \"$HOME/.cache/wallpaper_rofi/current\" 2>/dev/null || true"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const path = data.trim();
                if (!path)
                    return;
                if (path !== root._lastWallpaperRealPath)
                    root.refreshFromWallpaperPath(path);
            }
        }
    }

    Timer {
        id: pollCurrentWallpaper
        interval: 2500
        repeat: true
        running: false
        onTriggered: {
            if (!readCurrentWallpaperPath.running)
                readCurrentWallpaperPath.running = true;
        }
    }

    FileView {
        id: modeFileWatcher
        path: root.modePath
        watchChanges: true

        onLoaded: root.requestThemeModeReload()
        onFileChanged: root.requestThemeModeReload()
    }

    FileView {
        id: wallpaperLinkWatcher
        path: root.wallpaperLinkPath
        watchChanges: true

        onLoaded: readCurrentWallpaperPath.running = true
        onFileChanged: readCurrentWallpaperPath.running = true
    }

    FileView {
        id: wallpaperDisplayPreviewWatcher
        path: root.wallpaperDisplayPreviewPath
        watchChanges: true

        onLoaded: root.wallpaperPreviewVersion += 1
        onFileChanged: root.wallpaperPreviewVersion += 1
    }

    FileView {
        id: colorFile
        path: root.colorsPath
        watchChanges: true

        onLoaded: {
            try {
                const text = colorFile.text();
                if (!text)
                    return;

                generatedColors = JSON.parse(text);
                applyTheme();
            } catch (e) {
                // 保持静默，避免高频刷日志。
            }
        }

        onFileChanged: colorFile.reload()
    }
}
