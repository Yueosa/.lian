import QtQuick
import Qt5Compat.GraphicalEffects 
import Quickshell
import Quickshell.Io  
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.Services
import qs.config

import qs.Modules.DynamicIsland.ClockContent
import qs.Modules.DynamicIsland.MediaContent  
import qs.Modules.DynamicIsland.NotificationContent
import qs.Modules.DynamicIsland.VolumeContent
import qs.Modules.DynamicIsland.LyricsContent 
import qs.Modules.DynamicIsland.Hub
import qs.Modules.DynamicIsland.OverviewContent

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: islandWindow
        required property var modelData
        screen: modelData
        readonly property bool islandEventCenterBooted: IslandEventCenter.booted

        property int earRadius: 16 
        readonly property real islandShadowStrongAlpha: {
            const mode = Colorscheme.effectiveMatugenMode;
            if (mode === "light") return 0.44;
            if (mode === "auto") return 0.68;
            return 0.78;
        }
        readonly property real islandShadowSoftAlpha: {
            const mode = Colorscheme.effectiveMatugenMode;
            if (mode === "light") return 0.28;
            if (mode === "auto") return 0.46;
            return 0.55;
        }

        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Screen.height 
        margins { top: 0 } 
        
        color: "transparent"
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Top

        WlrLayershell.keyboardFocus: root.showHub
            ? WlrKeyboardFocus.Exclusive 
            : WlrKeyboardFocus.None

        // ============================================================
        // 【物理挖孔层 (Mask Region)】 
        // ============================================================
        Item {
            id: hitBoxRegion
            anchors.top: maskContainer.top
            anchors.bottom: maskContainer.bottom
            anchors.right: maskContainer.right
            anchors.left: maskContainer.left
        }

        mask: Region {
            item: hitBoxRegion
        }

        // ============================================================
        // 【阴影源 (Shadow Source)】 
        // ============================================================
        Item {
            id: shadowSource
            anchors.top: maskContainer.top
            anchors.horizontalCenter: maskContainer.horizontalCenter
            width: maskContainer.width
            height: maskContainer.height
            visible: false 

            Canvas {
                id: shadowLeftEar 
                anchors.right: rootShadow.left
                anchors.top: rootShadow.top
                width: islandWindow.earRadius
                height: islandWindow.earRadius
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, islandWindow.islandShadowStrongAlpha);
                    ctx.beginPath(); ctx.moveTo(0, 0);
                    ctx.lineTo(width, 0); ctx.lineTo(width, height);
                    ctx.arc(0, height, width, 0, -Math.PI/2, true); ctx.fill();
                }
                Connections { 
                    target: Colorscheme;
                    function onBackgroundChanged() { shadowLeftEar.requestPaint() }
                }
            }

            Item {
                id: rootShadow
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.width
                height: root.height
                
                Rectangle {
                    id: solidShadowBg
                    anchors.fill: parent
                    radius: root.radius
                    color: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, islandWindow.islandShadowStrongAlpha)

                    // 顶部叠加同色一条，与圆角拼合营造原版描边/边沿
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.radius
                        color: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, islandWindow.islandShadowStrongAlpha)
                    }
                }
            }

            Canvas {
                id: shadowRightEar 
                anchors.left: rootShadow.right
                anchors.top: rootShadow.top
                width: islandWindow.earRadius
                height: islandWindow.earRadius
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, islandWindow.islandShadowStrongAlpha);
                    ctx.beginPath(); ctx.moveTo(width, 0); ctx.lineTo(0, 0); ctx.lineTo(0, height);
                    ctx.arc(width, height, width, Math.PI, Math.PI*1.5, false); ctx.fill();
                }
                Connections { 
                    target: Colorscheme;
                    function onBackgroundChanged() { shadowRightEar.requestPaint() } 
                }
            }
        }



        DropShadow {
            anchors.fill: shadowSource
            source: shadowSource
            horizontalOffset: 0
            verticalOffset: 6
            radius: Sizes.rounding.xxl
            samples: 32
            color: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, islandWindow.islandShadowSoftAlpha)
            // 不能 cached:true：showOverviewHole 切换时 maskSource 已重算，
            // 但 DropShadow 的纹理缓存仍是上次形状（含/不含镂空）→ 灵动岛阴影残留旧形状即"泄漏"。
            cached: false
        }

        // ============================================================
        // 【视觉灵动岛本体】 
        // ============================================================
        Item {
            id: maskContainer
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width + (islandWindow.earRadius * 2)
            height: root.height

            Canvas {
                id: leftEar
                anchors.right: root.left
                anchors.top: root.top
                width: islandWindow.earRadius
                height: islandWindow.earRadius
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Colorscheme.background;
                    ctx.beginPath();
                    ctx.moveTo(0, 0);                 
                    ctx.lineTo(width, 0);             
                    ctx.lineTo(width, height);
                    ctx.arc(0, height, width, 0, -Math.PI/2, true);
                    ctx.fill();
                }
                Connections {
                    target: Colorscheme
                    function onBackgroundChanged() { leftEar.requestPaint() }
                }
            }

            Item {
                id: root
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter

                property bool showLyrics: false  // 手动歌词模式
                property bool autoLyrics: false   // 自动抢占歌词模式（有歌播放时自动激活）
                property bool lyricsHoverRestore: false  // 悬停时临时恢复时钟
                property bool expanded: false
                property bool showVolume: false
                property bool showHub: false

                property int hubTabIndex: 0

                property bool isLyricsMode: showLyrics
                property bool isHubMode: showHub && !isLyricsMode
                property bool isVolumeMode: showVolume && !expanded && !isHubMode && !isLyricsMode
                property bool isNotifMode: NotificationManager.hasNotifs && !expanded && !showVolume && !isHubMode && !isLyricsMode
                // 自动歌词抢占：只在本来会显示时钟的状态下生效（低于 volume/notif 优先级）
                property bool isAutoLyricsMode: autoLyrics && !lyricsHoverRestore && !expanded
                    && !isNotifMode && !isVolumeMode
                    && !isLyricsMode && !isHubMode
                property bool isCollapsedMode: !expanded && !isNotifMode && !isVolumeMode && !isLyricsMode && !isAutoLyricsMode && !isHubMode
                property bool captureActive: false
                property bool capturePaused: false
                property string captureKind: "video"
                property string captureScope: "full"
                property int captureElapsedSec: 0
                property var captureMilestoneSent: ({})
                property bool isCaptureHoverMode: captureActive && isCollapsedMode && islandMouseArea.containsMouse
                
                // showOverviewHole 已废弃：Overview 不再挖洞，SolidGlassCard 用 alpha 营造透明感
                property bool showOverviewHole: false
                property real uiScale: Sizes.islandScale

                property int lyricsW: Math.round(lyricsWidget.implicitWidth * uiScale); property int lyricsH: Math.round(42 * uiScale)
                property int expandedW: Math.round(540 * uiScale); property int expandedH: Math.round(210 * uiScale)
                property int collapsedW: Math.round(220 * uiScale); property int collapsedH: Math.round(48 * uiScale)
                property int notifW: Math.round(380 * uiScale); property int notifH: Math.round((NotificationManager.model.count * 70) + 20)
                property int volW: Math.round(320 * uiScale); property int volH: Math.round(64 * uiScale)
                property int captureHoverW: Math.round(356 * uiScale)
                property int captureHoverH: Math.round(56 * uiScale)
                
                property color color: Colorscheme.background 
                clip: true
                z: 100

                property int targetR: (expanded || isNotifMode || isVolumeMode || 
                      isLyricsMode || isAutoLyricsMode || isHubMode) 
                        ? Math.round(24 * uiScale) : (isCollapsedMode && islandMouseArea.containsMouse ? Math.round(18 * uiScale) : Math.round(16 * uiScale))

                property int targetW: isHubMode ? hub.implicitWidth : 
                    isCaptureHoverMode ? captureHoverW :
                    (isLyricsMode || isAutoLyricsMode) ? lyricsW : 
                    expanded ? expandedW : 
                    isVolumeMode ? volW : 
                    isNotifMode ? notifW : 
                    (collapsedW + (isCollapsedMode && islandMouseArea.containsMouse ? 16 : 0))

                property int targetH: isHubMode ? hub.implicitHeight : 
                        isCaptureHoverMode ? captureHoverH :
                        (isLyricsMode || isAutoLyricsMode) ? lyricsH : 
                        expanded ? expandedH : 
                        isVolumeMode ? volH : 
                        isNotifMode ? notifH : 
                        (collapsedH + (isCollapsedMode && islandMouseArea.containsMouse ? 6 : 0))

                function captureKindLabel() {
                    return captureKind === "gif" ? "GIF" : "Video"
                }

                function captureScopeLabel() {
                    return captureScope === "region" ? "区域" : "全屏"
                }

                function formatCaptureDuration(sec) {
                    let value = Math.max(0, Math.floor(Number(sec) || 0))
                    const h = Math.floor(value / 3600)
                    const m = Math.floor((value % 3600) / 60)
                    const s = value % 60
                    if (h > 0)
                        return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
                    return String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
                }

                function resetCaptureMilestones() {
                    captureMilestoneSent = ({})
                }

                function maybeNotifyCaptureMilestone() {
                    if (!captureActive || capturePaused)
                        return

                    const totalMinutes = Math.floor(Math.max(0, captureElapsedSec) / 60)
                    let milestone = -1
                    if (totalMinutes === 1 || totalMinutes === 10 || totalMinutes === 30)
                        milestone = totalMinutes
                    else if (totalMinutes >= 60 && totalMinutes % 60 === 0)
                        milestone = totalMinutes

                    if (milestone < 0)
                        return

                    const key = String(milestone)
                    if (captureMilestoneSent[key])
                        return

                    const nextSent = Object.assign({}, captureMilestoneSent)
                    nextSent[key] = true
                    captureMilestoneSent = nextSent

                    const extra = milestone >= 60
                        ? ("（" + Math.floor(milestone / 60) + "h）")
                        : ""
                    const title = "录制提醒"
                    const body = "已录制 " + milestone + " 分钟" + extra + "\n类型：" + captureKindLabel() + "  范围：" + captureScopeLabel()
                    Quickshell.execDetached(["notify-send", "-a", "quickshell-capture", "-i", "camera-video", title, body])
                }

                width: targetW
                height: targetH
                property real radius: targetR

                Rectangle {
                    id: solidRootBg
                    anchors.fill: parent
                    radius: root.radius
                    color: Colorscheme.background

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.radius
                        color: parent.color
                    }
                }

                Behavior on width  { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                IpcHandler {
                    target: "island"

                    function _parseSwitchValue(state: string, fallback: bool) {
                        const s = String(state || "").toLowerCase()
                        if (s === "on" || s === "1" || s === "true" || s === "enable" || s === "enabled")
                            return true
                        if (s === "off" || s === "0" || s === "false" || s === "disable" || s === "disabled")
                            return false
                        return fallback
                    }

                    function _captureScriptPath() {
                        return Quickshell.env("HOME") + "/.config/quickshell/scripts/capture.sh"
                    }

                    function captureshot(scope: string) {
                        const target = (scope && scope.length > 0) ? scope : "region"
                        Quickshell.execDetached(["bash", _captureScriptPath(), "shot", target])
                    }

                    function capturerecordtoggle(kind: string, scope: string) {
                        const mode = (kind && kind.length > 0) ? kind : "video"
                        const target = (scope && scope.length > 0) ? scope : "full"
                        Quickshell.execDetached(["bash", _captureScriptPath(), "record-toggle", mode, target])
                    }

                    function capturestatekey() {
                        Quickshell.execDetached(["bash", _captureScriptPath(), "state-key"])
                    }

                    function captureforcestop() {
                        Quickshell.execDetached(["bash", _captureScriptPath(), "force-stop"])
                    }

                    function capturemenu(action: string) {
                        const nextAction = (action && action.length > 0) ? action : "toggle"
                        Quickshell.execDetached(["bash", _captureScriptPath(), "menu", nextAction])
                    }

                    function mediatoggle() {
                        if (root.currentPlayer)
                            root.currentPlayer.togglePlaying()
                    }

                    function mediaprevious() {
                        if (root.currentPlayer)
                            root.currentPlayer.previous()
                    }

                    function medianext() {
                        if (root.currentPlayer)
                            root.currentPlayer.next()
                    }

                    function closeAllOthers() {
                        root.showLyrics = false;
                        root.expanded = false;
                    }

                    function hub() {
                        if (root.showHub) { root.showHub = false; return "HUB_CLOSED" } 
                        else { closeAllOthers(); root.showHub = true; root.hubTabIndex = 0; return "HUB_OPENED" }
                    }

                    function switcher() {
                        if (root.showHub && root.hubTabIndex === 3) { root.showHub = false; return "SWITCHER_CLOSED" }
                        closeAllOthers();
                        root.showHub = true;
                        root.hubTabIndex = 3;
                        return "SWITCHER_OPENED"
                    }

                    function notifytest(preset: string) {
                        const name = (preset && preset.length > 0) ? preset : "resource_cpu"
                        IslandEventCenter.debugEmitPreset(name, "force")
                    }

                    function notifytestmode(preset: string, mode: string) {
                        const name = (preset && preset.length > 0) ? preset : "resource_cpu"
                        const strategy = (mode && mode.length > 0) ? mode : "force"
                        IslandEventCenter.debugEmitPreset(name, strategy)
                    }

                    function notifystats() {
                        IslandEventCenter.debugDumpStats()
                    }

                    function notifyreset() {
                        IslandEventCenter.debugResetStats()
                    }

                    function notifysetdnd(state: string) {
                        const want = _parseSwitchValue(state, ControlBackend.dndEnabled)
                        ControlBackend.dndEnabled = want
                        DynamicIslandPrefs.dndEnabled = want
                    }

                    function notifysetquiet(state: string, startHour: string, endHour: string) {
                        const want = _parseSwitchValue(state, DynamicIslandPrefs.quietHoursEnabled)
                        DynamicIslandPrefs.quietHoursEnabled = want

                        const start = Number(startHour)
                        const end = Number(endHour)
                        if (!isNaN(start))
                            DynamicIslandPrefs.setQuietStartHour(start)
                        if (!isNaN(end))
                            DynamicIslandPrefs.setQuietEndHour(end)
                    }

                }

                PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }
               
                property var audioNode: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

                Timer { 
                    id: volHideTimer
                    interval: 2000
                    onTriggered: {
                        if (volumeWidget.isInteractionActive) { restart() } 
                        else { root.showVolume = false }
                    }
                }
            
                Connections {
                    target: root.audioNode; ignoreUnknownSignals: true
                    function onVolumeChanged() { root.triggerVolumeOSD() } 
                    function onMutedChanged() { root.triggerVolumeOSD() }  
                }
            
                function triggerVolumeOSD() {
                    // autoLyricsMode 不阻止 volume OSD（volume 优先级高于自动歌词）
                    if (root.showHub || root.expanded || root.showLyrics) return
                    root.showVolume = true; volHideTimer.restart()
                }
                
                property var currentPlayer: null

                Process {
                    id: captureStatusProc
                    command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/capture.sh", "status-detail"]
                    stdout: SplitParser {
                        onRead: data => {
                            const line = String(data || "").trim()
                            if (line.length === 0)
                                return

                            const parts = line.split("|")
                            if (parts.length < 4)
                                return

                            const state = String(parts[0] || "idle")
                            const active = (state === "recording" || state === "paused")

                            if (!active) {
                                if (root.captureActive)
                                    root.resetCaptureMilestones()
                                root.captureActive = false
                                root.capturePaused = false
                                root.captureElapsedSec = 0
                                return
                            }

                            root.captureActive = true
                            root.capturePaused = (state === "paused")
                            root.captureKind = String(parts[1] || "video")
                            root.captureScope = String(parts[2] || "full")

                            const sec = Number(parts[3])
                            root.captureElapsedSec = isNaN(sec) ? 0 : Math.max(0, Math.floor(sec))
                            root.maybeNotifyCaptureMilestone()
                        }
                    }
                }

                Timer {
                    id: captureStatusTimer
                    interval: 1000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: {
                        if (!captureStatusProc.running)
                            captureStatusProc.running = true
                    }
                }

                // ============================================================
                // 【自动歌词抢占】：监听 currentPlayer 播放状态
                // ============================================================
                onCurrentPlayerChanged: {
                    autoLyrics = (currentPlayer !== null && currentPlayer.isPlaying)
                    lyricsHoverRestore = false
                    lyricsRestoreTimer.stop()
                }

                Connections {
                    target: root.currentPlayer
                    ignoreUnknownSignals: true
                    function onIsPlayingChanged() {
                        root.autoLyrics = root.currentPlayer ? root.currentPlayer.isPlaying : false
                        if (!root.autoLyrics) {
                            root.lyricsHoverRestore = false
                            lyricsRestoreTimer.stop()
                        }
                    }
                }

                Timer {
                    id: lyricsRestoreTimer
                    interval: 1200
                    onTriggered: { root.lyricsHoverRestore = false }
                }

                Timer {
                    id: stickyTimer
                    interval: 500; repeat: true; triggeredOnStart: true
                    running: Mpris.players.values.length > 0
                    onRunningChanged: { if (!running) root.currentPlayer = null }
                    onTriggered: {
                        var players = Mpris.players.values
                        if (players.length === 0) { root.currentPlayer = null; return }
                        var playingPlayer = null
                        for (let i = 0; i < players.length; i++) { 
                            if (players[i].isPlaying) { playingPlayer = players[i]; break } 
                        }
                        if (playingPlayer) { 
                            if (root.currentPlayer !== playingPlayer) root.currentPlayer = playingPlayer 
                        } else {
                            var currentIsValid = false
                            if (root.currentPlayer) { 
                                for (let i = 0; i < players.length; i++) { 
                                    if (players[i] === root.currentPlayer) { currentIsValid = true; break } 
                                } 
                            }
                            if (!currentIsValid) root.currentPlayer = players[0]
                        }
                    }
                }

                MouseArea {
                    id: islandMouseArea  
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true   
                    enabled: !root.isNotifMode && !root.isVolumeMode 
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                    // 悬停时临时显示时钟，离开后 1.2s 恢复歌词
                    onEntered: {
                        if (root.autoLyrics && !root.showLyrics) {
                            root.lyricsHoverRestore = true
                            lyricsRestoreTimer.stop()
                        }
                    }
                    onExited: {
                        if (root.autoLyrics && !root.showLyrics && root.lyricsHoverRestore) {
                            lyricsRestoreTimer.restart()
                        }
                    }

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            if (root.showHub) root.showHub = false
                            root.showLyrics = !root.showLyrics
                            if (root.showLyrics) root.expanded = false
                        } else {
                            // 左键：只控制 Media 展开/收起，Hub 仅通过 Alt+Tab 快捷键打开
                            if (root.showHub) { root.showHub = false; return }
                            if (root.showLyrics) root.showLyrics = false
                            else root.expanded = !root.expanded
                        }
                    }
                }

                Item {
                    id: staticCanvas
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 1600 
                    height: 1200

                    ClockContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.collapsedW
                        height: root.collapsedH
                        
                        player: root.currentPlayer
                        
                        opacity: (!root.expanded && !root.isNotifMode && !root.isVolumeMode && !root.isLyricsMode && !root.isAutoLyricsMode && !root.isHubMode && !root.isCaptureHoverMode) ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }

                    Item {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.captureHoverW
                        height: root.captureHoverH

                        opacity: root.isCaptureHoverMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 160 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.capturePaused ? Colorscheme.tertiary : Colorscheme.error
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.capturePaused ? "PAUSED" : "REC"
                                color: root.capturePaused ? Colorscheme.tertiary : Colorscheme.error
                                font.family: Sizes.fontFamilyMono
                                font.pixelSize: Sizes.font.sm
                                font.bold: true
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.captureKindLabel() + " · " + root.captureScopeLabel()
                                color: Colorscheme.on_surface
                                font.family: Sizes.fontFamily
                                font.pixelSize: Sizes.font.sm
                                font.bold: true
                            }

                            Item { width: 1; height: 1 }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.formatCaptureDuration(root.captureElapsedSec)
                                color: Colorscheme.primary
                                font.family: Sizes.fontFamilyMono
                                font.pixelSize: Sizes.font.body
                                font.bold: true
                            }
                        }
                    }
                        
                    VolumeContent {
                        id: volumeWidget
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.volW
                        height: root.volH

                        audioNode: root.audioNode
                        opacity: root.isVolumeMode ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                        
                    NotificationContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 10
                        width: root.notifW - 20
                        height: root.notifH - 20

                        manager: NotificationManager
                        
                        opacity: root.isNotifMode ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                        
                    LyricsContent { 
                        id: lyricsWidget 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.lyricsW
                        height: root.lyricsH

                        player: root.currentPlayer
                        active: root.isLyricsMode || root.isAutoLyricsMode
                        opacity: (root.isLyricsMode || root.isAutoLyricsMode) ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                    
                    MediaContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 10
                        width: root.expandedW - 24
                        height: root.expandedH - 20

                        opacity: (root.expanded && !root.isLyricsMode && !root.isHubMode) ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                        
                    HubContent {
                        id: hub
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: implicitWidth
                        height: implicitHeight
                        
                        player: root.currentPlayer
                        currentIndex: root.hubTabIndex
                        onCurrentIndexChanged: root.hubTabIndex = currentIndex
                        onCloseRequested: root.showHub = false

                        opacity: root.isHubMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                }
            }

            Canvas {
                id: rightEar
                anchors.left: root.right
                anchors.top: root.top
                width: islandWindow.earRadius
                height: islandWindow.earRadius
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Colorscheme.background;
                    ctx.beginPath();
                    ctx.moveTo(width, 0);             
                    ctx.lineTo(0, 0);                 
                    ctx.lineTo(0, height);
                    ctx.arc(width, height, width, Math.PI, Math.PI*1.5, false);
                    ctx.fill();
                }
                Connections {
                    target: Colorscheme
                    function onBackgroundChanged() { rightEar.requestPaint() }
                }
            }
        }
    }
}
