pragma Singleton

// ============================================================
// 天气服务 — Weather
// ============================================================
// weatherd → ~/.cache/qsl/forecast.json
// 命令 → $XDG_RUNTIME_DIR/qsl/weather_cmd
// 轻量字段常驻（Overview）；hourly/daily 仅 detailActive
// 进页吃缓存；过期软刷新；按钮 / 换城才 force（防 Open-Meteo 429）
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/qsl"
    readonly property string forecastPath: cacheDir + "/forecast.json"
    readonly property string geocodePath: cacheDir + "/geocode_results.json"
    readonly property string daemonBin: Quickshell.shellDir + "/backend/weather/build/weatherd"
    readonly property string iconDir: Quickshell.shellDir + "/asset/icon/weather"
    // 与 weatherd MIN_REFRESH_SECS 对齐
    readonly property int softRefreshAgeSec: 10 * 60

    property bool detailActive: false
    property bool daemonOk: false
    property bool ready: false
    property bool loading: false
    property bool searching: false
    property bool geoWatch: false

    property string status: ""
    property string locationName: ""
    property real latitude: 0
    property real longitude: 0
    property int lastUpdated: 0

    property real tempC: 0
    property real feelsLikeC: 0
    property int weatherCode: 0
    property string weatherText: ""
    property string iconName: ""
    property real windSpeedMs: 0
    property int humidity: 0
    property real pressure: 0

    readonly property string tempText: ready ? (Math.round(tempC) + "°") : "--"
    readonly property string feelsText: ready ? (Math.round(feelsLikeC) + "°C") : "--"
    readonly property string humidityText: ready ? (humidity + "%") : "--"
    readonly property string windText: ready ? ((windSpeedMs * 3.6).toFixed(1) + " km/h") : "--"
    readonly property string pressureText: ready ? (Math.round(pressure) + " hPa") : "--"
    readonly property string iconSource: iconUrl(iconName, weatherCode, true)

    property var hourly: []
    property var daily: []
    property var geocodeResults: []

    function setDetailActive(active) {
        detailActive = !!active
        if (detailActive) {
            ensureDaemon()
            forecastView.reload()
            softRefreshIfStale()
        } else {
            hourly = []
            daily = []
            geocodeResults = []
            searching = false
            geoWatch = false
        }
    }

    function ensureDaemon() {
        ensureProc.running = true
    }

    function softRefreshIfStale() {
        if (!ready || lastUpdated <= 0) {
            refresh(false)
            return
        }
        const age = Math.floor(Date.now() / 1000) - lastUpdated
        if (age >= softRefreshAgeSec)
            refresh(false)
    }

    // force=false：软刷新（daemon 可能跳过）；true：按钮强制拉
    function refresh(force) {
        writeCmd(force ? "refresh force" : "refresh")
        if (force) {
            loading = true
            loadStop.restart()
            forecastPoll.restart()
        } else {
            forecastReloadDelay.restart()
        }
    }

    function geocode(query) {
        const q = String(query || "").trim()
        if (!q.length)
            return
        if (!geoWatch)
            ensureGeoFile.running = true
        writeCmd("geocode " + q)
        geoReload.restart()
    }

    function setLocation(lat, lon, name) {
        const n = String(name || "").replace(/\n/g, " ").trim()
        const la = Number(lat)
        const lo = Number(lon)
        if (n.length)
            locationName = n
        if (!isNaN(la))
            latitude = la
        if (!isNaN(lo))
            longitude = lo
        writeCmd("set_location " + la + " " + lo + " " + n)
        searching = false
        geocodeResults = []
        loading = true
        loadStop.restart()
        forecastPoll.restart()
    }

    function resetLocation() {
        writeCmd("reset_location")
        searching = false
        geocodeResults = []
        loading = true
        loadStop.restart()
        forecastPoll.restart()
    }

    onSearchingChanged: {
        if (searching) {
            ensureGeoFile.running = true
        } else {
            geocodeResults = []
            geoWatch = false
        }
    }

    function writeCmd(line) {
        ensureDaemon()
        cmdProc.command = [
            "bash", "-lc",
            "mkdir -p \"$XDG_RUNTIME_DIR/qsl\" && printf '%s\\n' " + shellQuote(line)
            + " > \"$XDG_RUNTIME_DIR/qsl/weather_cmd\""
        ]
        cmdProc.running = true
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function iconSlug(name, code, isDay) {
        const day = isDay !== false
        const n = String(name || "").replace(/_/g, "-")
        const map = {
            "clear-day": day ? "clear-day" : "clear-night",
            "clear-night": "clear-night",
            "partly-cloudy-day": day ? "partly-cloudy-day" : "partly-cloudy-night",
            "partly-cloudy-night": "partly-cloudy-night",
            "cloudy": "cloudy",
            "fog": day ? "fog-day" : "fog-night",
            "rainy": "rain",
            "rain": "rain",
            "snowy": "snow",
            "snow": "snow",
            "thunderstorm": day ? "thunderstorms-day" : "thunderstorms-night"
        }
        if (map[n])
            return map[n]
        const c = Number(code) || 0
        if (c === 0)
            return day ? "clear-day" : "clear-night"
        if (c === 1 || c === 2)
            return day ? "partly-cloudy-day" : "partly-cloudy-night"
        if (c === 3)
            return "cloudy"
        if (c === 45 || c === 48)
            return day ? "fog-day" : "fog-night"
        if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82))
            return "rain"
        if ((c >= 71 && c <= 77) || c === 85 || c === 86)
            return "snow"
        if (c >= 95)
            return day ? "thunderstorms-day" : "thunderstorms-night"
        return "cloudy"
    }

    function iconUrl(name, code, isDay) {
        return "file://" + iconDir + "/" + iconSlug(name, code, isDay) + ".svg"
    }

    function applyForecast(data) {
        if (!data || typeof data !== "object")
            return
        status = String(data.status || "")
        locationName = String(data.location_name || "")
        latitude = Number(data.latitude) || 0
        longitude = Number(data.longitude) || 0
        lastUpdated = Number(data.last_updated) || 0

        const cur = data.current || {}
        tempC = Number(cur.temperature) || 0
        feelsLikeC = Number(cur.apparent_temperature) || 0
        weatherCode = Number(cur.weather_code) || 0
        weatherText = String(cur.weather_text || "")
        iconName = String(cur.icon_name || "")
        windSpeedMs = Number(cur.wind_speed) || 0
        humidity = Number(cur.humidity) || 0
        pressure = Number(cur.pressure) || 0
        ready = true
        loading = false

        if (!detailActive) {
            hourly = []
            daily = []
            return
        }

        const nowTs = Math.floor(Date.now() / 1000)
        const hs = data.hourly || []
        let start = 0
        for (let i = 0; i < hs.length; i++) {
            if ((Number(hs[i].time) || 0) >= nowTs) {
                start = i
                break
            }
        }
        const hout = []
        for (let h = 0; h < 12 && start + h < hs.length; h++) {
            const row = hs[start + h]
            const t = new Date((Number(row.time) || 0) * 1000)
            const isDay = row.is_day !== undefined ? !!row.is_day
                : (t.getHours() >= 6 && t.getHours() < 18)
            hout.push({
                time: String(t.getHours()).padStart(2, "0") + ":00",
                temp: Math.round(Number(row.temperature) || 0),
                icon: iconUrl(row.icon_name, row.weather_code, isDay),
                code: Number(row.weather_code) || 0
            })
        }
        hourly = hout

        const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        const ds = data.daily || []
        const dout = []
        for (let d = 0; d < 7 && d < ds.length; d++) {
            const row = ds[d]
            const dateObj = new Date((Number(row.date) || 0) * 1000)
            dout.push({
                day: d === 0 ? "Today" : dayNames[dateObj.getDay()],
                icon: iconUrl(row.icon_name, row.weather_code, true),
                maxTemp: Math.round(Number(row.temp_max) || 0) + "°",
                minTemp: Math.round(Number(row.temp_min) || 0) + "°",
                // 数值留给 7 日温差条算比例（避免 UI 再 parse "24°"）
                maxC: Math.round(Number(row.temp_max) || 0),
                minC: Math.round(Number(row.temp_min) || 0)
            })
        }
        daily = dout
    }

    function applyGeocode(raw) {
        try {
            const t = (raw || "").trim()
            if (!t) {
                geocodeResults = []
                return
            }
            const parsed = JSON.parse(t)
            geocodeResults = Array.isArray(parsed) ? parsed : []
        } catch (e) {
            console.warn("Weather: geocode parse failed", e)
            geocodeResults = []
        }
    }

    FileView {
        id: forecastView
        path: root.forecastPath
        watchChanges: true
        onLoaded: {
            try {
                const t = (text() || "").trim()
                if (!t)
                    return
                root.applyForecast(JSON.parse(t))
            } catch (e) {
                console.warn("Weather: forecast parse failed", e)
            }
        }
        onFileChanged: reload()
        onLoadFailed: {}
    }

    FileView {
        id: geoView
        path: (root.detailActive && root.geoWatch) ? root.geocodePath : ""
        watchChanges: root.detailActive && root.geoWatch
        onLoaded: {
            if (root.detailActive && root.geoWatch)
                root.applyGeocode(text())
        }
        onFileChanged: reload()
        onLoadFailed: root.geocodeResults = []
    }

    Process {
        id: ensureGeoFile
        command: [
            "bash", "-lc",
            "mkdir -p \"$HOME/.cache/qsl\"; "
            + "f=\"$HOME/.cache/qsl/geocode_results.json\"; "
            + "[ -f \"$f\" ] || printf '[]\\n' > \"$f\""
        ]
        onExited: (code) => {
            if (code === 0 && root.searching)
                root.geoWatch = true
        }
    }

    Process { id: cmdProc }

    Process {
        id: ensureProc
        // 仅拉起当前用户的 weatherd；遇他人进程则尝试结束（无权限则保持现状）
        command: [
            "bash", "-lc",
            "mkdir -p \"$XDG_RUNTIME_DIR/qsl\" \"$HOME/.cache/qsl\"; "
            + "pid=$(pgrep -x weatherd | head -1); "
            + "if [ -n \"$pid\" ]; then "
            + "  owner=$(ps -o user= -p \"$pid\" | tr -d ' '); "
            + "  if [ \"$owner\" = \"$(id -un)\" ]; then exit 0; fi; "
            + "  kill \"$pid\" 2>/dev/null || true; sleep 0.2; "
            + "fi; "
            + "BIN=\"" + root.daemonBin + "\"; "
            + "if [ -x \"$BIN\" ]; then nohup \"$BIN\" >/dev/null 2>&1 & exit 0; fi; "
            + "exit 1"
        ]
        onExited: (code) => {
            root.daemonOk = (code === 0)
            if (code === 0)
                forecastReloadDelay.start()
        }
    }

    Timer {
        id: forecastReloadDelay
        interval: 400
        repeat: false
        onTriggered: forecastView.reload()
    }

    Timer {
        id: geoReload
        interval: 600
        repeat: false
        onTriggered: {
            if (root.detailActive && root.geoWatch)
                geoView.reload()
        }
    }

    Timer {
        id: loadStop
        interval: 8000
        repeat: false
        onTriggered: root.loading = false
    }

    Timer {
        id: forecastPoll
        interval: 800
        repeat: true
        property int ticks: 0
        onTriggered: {
            forecastView.reload()
            ticks += 1
            if (ticks >= 6 || !root.loading) {
                ticks = 0
                stop()
            }
        }
        onRunningChanged: {
            if (running)
                ticks = 0
        }
    }

    Component.onCompleted: forecastView.reload()
}
