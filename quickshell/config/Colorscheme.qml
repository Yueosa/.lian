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

    // 主题是否已就绪。false 期间上层 UI 应该隐藏，避免闪现 dark 占位。
    //   LIGHT / DARK：_modeLoaded 后即就绪
    //   AUTO：必须等到 cache 写入 _mode 才算就绪
    readonly property bool ready: {
        if (!_modeLoaded)
            return false;
        const mode = matugenMode.toLowerCase();
        if (mode === "light" || mode === "dark")
            return true;
        return generatedMode !== "";
    }

    // matugen / 亮度脚本写入的 _mode 字段：cache 色值实际是哪个 variant 生成的。
    // AUTO 模式下该值 == 壁纸亮度判定结果；LIGHT/DARK 模式根本不看 cache。
    readonly property string generatedMode: {
        const v = (generatedColors["_mode"] || "").toString().toLowerCase();
        return (v === "light" || v === "dark") ? v : "";
    }

    // 对外暴露「当前实际呈现的明暗」：
    //   LIGHT → light
    //   DARK  → dark
    //   AUTO  → 跟 cache._mode（壁纸亮度）；cache 未就绪时默认 dark
    readonly property string effectiveMatugenMode: {
        const mode = matugenMode.toLowerCase();
        if (mode === "light" || mode === "dark")
            return mode;
        return generatedMode || "light";
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
        // 三套方案完全解耦：
        //   LIGHT → lightPalette（固定，不跳 cache）
        //   DARK  → darkPalette （固定，不跳 cache）
        //   AUTO  → 以 cache._mode 选一份 light/dark 作为 fallback 基线，
        //           后续 applyTheme 会再用 cache 覆盖（仅 AUTO 模式）。
        let palette = darkPalette;
        if (mode === "light")
            palette = lightPalette;
        else if (mode === "auto")
            palette = (generatedMode === "light") ? lightPalette : darkPalette;
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
        // 未就绪不动 m3colors，让上层 UI 隐藏期间保持默认（透明黑），
        // 避免 AUTO 初始闪现 dark 占位主题。
        if (!ready)
            return;

        const mode = matugenMode.toLowerCase();
        let targetTheme = applyPresetColors(mode);
        // AUTO 独立走 cache：LIGHT/DARK 完全不查 cache，避免三套方案耦合。
        if (mode === "auto" && generatedMode !== "")
            targetTheme = applyGeneratedColors(targetTheme);

        if (animated)
            animateTheme(targetTheme);
        else
            commitTheme(targetTheme);
    }

    // 就绪后自动 apply 一次（首次不动画，干净出现）。
    onReadyChanged: {
        if (ready)
            applyTheme(false);
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
        // 不主动调 applyTheme：ready 跳变时 onReadyChanged 会负责首次提交。
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
        // 默认全透明：ready 之前 applyTheme 不会跑，UI 用透明色渲染等于不可见，
        // 避免 AUTO 启动瞬间闪现 dark 占位色。
        property color m3background: "transparent"
        property color m3error: "transparent"
        property color m3errorContainer: "transparent"
        property color m3inverseOnSurface: "transparent"
        property color m3inversePrimary: "transparent"
        property color m3inverseSurface: "transparent"
        property color m3onBackground: "transparent"
        property color m3onError: "transparent"
        property color m3onErrorContainer: "transparent"
        property color m3onPrimary: "transparent"
        property color m3onPrimaryContainer: "transparent"
        property color m3onPrimaryFixed: "transparent"
        property color m3onPrimaryFixedVariant: "transparent"
        property color m3onSecondary: "transparent"
        property color m3onSecondaryContainer: "transparent"
        property color m3onSecondaryFixed: "transparent"
        property color m3onSecondaryFixedVariant: "transparent"
        property color m3onSurface: "transparent"
        property color m3onSurfaceVariant: "transparent"
        property color m3onTertiary: "transparent"
        property color m3onTertiaryContainer: "transparent"
        property color m3onTertiaryFixed: "transparent"
        property color m3onTertiaryFixedVariant: "transparent"
        property color m3outline: "transparent"
        property color m3outlineVariant: "transparent"
        property color m3primary: "transparent"
        property color m3primaryContainer: "transparent"
        property color m3primaryFixed: "transparent"
        property color m3primaryFixedDim: "transparent"
        property color m3scrim: "transparent"
        property color m3secondary: "transparent"
        property color m3secondaryContainer: "transparent"
        property color m3secondaryFixed: "transparent"
        property color m3secondaryFixedDim: "transparent"
        property color m3shadow: "transparent"
        property color m3sourceColor: "transparent"
        property color m3surface: "transparent"
        property color m3surfaceBright: "transparent"
        property color m3surfaceContainer: "transparent"
        property color m3surfaceContainerHigh: "transparent"
        property color m3surfaceContainerHighest: "transparent"
        property color m3surfaceContainerLow: "transparent"
        property color m3surfaceContainerLowest: "transparent"
        property color m3surfaceDim: "transparent"
        property color m3surfaceTint: "transparent"
        property color m3surfaceVariant: "transparent"
        property color m3tertiary: "transparent"
        property color m3tertiaryContainer: "transparent"
        property color m3tertiaryFixed: "transparent"
        property color m3tertiaryFixedDim: "transparent"
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
