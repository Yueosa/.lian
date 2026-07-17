pragma Singleton

// ============================================================
// 音量服务 — Volume
// ============================================================
// PipeWire：默认 sink/source +（详情页）应用流
// 音量 0.0~1.0；应用流仅 detailActive 时追踪，关页减订阅
// ============================================================
// 对外接口：
//   detailActive / setDetailActive(bool)
//   sinkVolume / sinkMuted / sinkName / isHeadphone / hasSink
//   sourceVolume / sourceMuted / sourceName / hasSource
//   appLinkGroups          详情页应用 linkGroups（关页 null）
//   setSinkVolume / volumeUp / volumeDown / toggleSinkMute
//   setSourceVolume / toggleSourceMute
//   setAppVolume(node, v) / toggleAppMute(node)
//   appDisplayName / appIconSource
//   openPavucontrol()
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    property bool detailActive: false

    // 默认设备始终追踪（Bar 芯片等也要用）；应用节点仅详情页
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    PwNodeLinkTracker {
        id: appTracker
        node: root.detailActive ? Pipewire.defaultAudioSink : null
    }

    // 集中绑定应用节点（比只靠 ListView 行内 tracker 更稳；关页 Instantiator 清空）
    Instantiator {
        active: root.detailActive
        model: appTracker.linkGroups
        delegate: PwObjectTracker {
            required property var modelData
            objects: modelData && modelData.source ? [modelData.source] : []
        }
    }

    readonly property bool hasSink: !!Pipewire.defaultAudioSink
    readonly property bool hasSource: !!Pipewire.defaultAudioSource

    readonly property bool isHeadphone: {
        if (!Pipewire.defaultAudioSink)
            return false
        const desc = (Pipewire.defaultAudioSink.description || "").toLowerCase()
        const icon = ((Pipewire.defaultAudioSink.properties
            && Pipewire.defaultAudioSink.properties["device.icon-name"]) || "").toLowerCase()
        return desc.indexOf("headphone") >= 0
            || desc.indexOf("耳机") >= 0
            || icon.indexOf("headphone") >= 0
    }

    readonly property string sinkName: Pipewire.defaultAudioSink
        ? (Pipewire.defaultAudioSink.description || Pipewire.defaultAudioSink.name || "")
        : ""

    readonly property string sourceName: Pipewire.defaultAudioSource
        ? (Pipewire.defaultAudioSource.description || Pipewire.defaultAudioSource.name || "")
        : ""

    readonly property bool sinkMuted: Pipewire.defaultAudioSink
        ? Pipewire.defaultAudioSink.audio.muted
        : false

    readonly property real sinkVolume: Pipewire.defaultAudioSink
        ? Pipewire.defaultAudioSink.audio.volume
        : 0

    readonly property bool sourceMuted: Pipewire.defaultAudioSource
        ? Pipewire.defaultAudioSource.audio.muted
        : false

    readonly property real sourceVolume: Pipewire.defaultAudioSource
        ? Pipewire.defaultAudioSource.audio.volume
        : 0

    // 关页返回 null，避免 ListView 空绑空转
    readonly property var appLinkGroups: detailActive ? appTracker.linkGroups : null

    function setDetailActive(active) {
        detailActive = !!active
    }

    function setSinkVolume(volume) {
        const safe = Math.max(0.0, Math.min(1.0, volume))
        if (!Pipewire.defaultAudioSink)
            return
        Pipewire.defaultAudioSink.audio.volume = safe
        if (Pipewire.defaultAudioSink.audio.muted)
            Pipewire.defaultAudioSink.audio.muted = false
    }

    function volumeUp(step) {
        const s = step === undefined ? 0.05 : step
        setSinkVolume((sinkVolume || 0) + s)
    }

    function volumeDown(step) {
        const s = step === undefined ? 0.05 : step
        setSinkVolume((sinkVolume || 0) - s)
    }

    function toggleSinkMute() {
        if (Pipewire.defaultAudioSink)
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
    }

    function setSourceVolume(volume) {
        const safe = Math.max(0.0, Math.min(1.0, volume))
        if (!Pipewire.defaultAudioSource)
            return
        Pipewire.defaultAudioSource.audio.volume = safe
        if (Pipewire.defaultAudioSource.audio.muted)
            Pipewire.defaultAudioSource.audio.muted = false
    }

    function toggleSourceMute() {
        if (Pipewire.defaultAudioSource)
            Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
    }

    function setAppVolume(node, volume) {
        if (!node || !node.audio || !node.ready)
            return
        const safe = Math.max(0.0, Math.min(1.0, volume))
        node.audio.volume = safe
        if (node.audio.muted)
            node.audio.muted = false
    }

    function toggleAppMute(node) {
        if (!node || !node.audio || !node.ready)
            return
        node.audio.muted = !node.audio.muted
    }

    function appDisplayName(node) {
        if (!node)
            return "未知应用"
        const props = node.properties || {}
        const name = props["application.name"] || ""
        const binary = props["application.process.binary"] || ""
        // Electron/Chromium 壳常把壳名当 application.name
        const shell = name.toLowerCase()
        if (binary && (shell === "chromium" || shell === "electron"
                || shell === "chrome" || shell === "chrome_crashpad_handler"))
            return binary
        return name
            || props["media.name"]
            || node.description
            || node.name
            || binary
            || "未知应用"
    }

    function appIconSource(node) {
        if (!node)
            return "image://icon/audio-card"
        const props = node.properties || {}
        const icon = (props["application.icon-name"] || "").toLowerCase()
        const binary = (props["application.process.binary"] || "").toLowerCase()

        // SPlayer 无标准 icon name，仅此给文件路径（旧页同款）
        if (binary === "splayer")
            return "file:///usr/share/icons/hicolor/512x512/apps/SPlayer.png"

        // Electron 壳常填 chromium-browser；真实应用用 binary 试图标
        const shellIcon = icon === "chromium-browser" || icon === "chromium"
            || icon === "electron" || icon === "google-chrome"
        let name = icon || binary || "audio-card"
        if (shellIcon && binary && binary !== "chromium" && binary !== "chrome"
                && binary !== "electron" && binary !== "google-chrome")
            name = binary
        if (name === "cursor")
            name = "co.anysphere.cursor"

        if (name.startsWith("file://") || name.startsWith("/"))
            return name.startsWith("/") ? ("file://" + name) : name
        return "image://icon/" + name
    }

    function openPavucontrol() {
        Quickshell.execDetached(["pavucontrol"])
    }
}
