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
//   sinks / sources        详情页输出/输入设备（关页空）
//   sinkRows / sourceRows  同上，增量 ListModel（给 ListView 过渡用）
//   defaultSink / defaultSource
//   setDefaultSink(node) / setDefaultSource(node)
//   deviceLabel / deviceHint / deviceIcon
//   setSinkVolume / volumeUp / volumeDown / toggleSinkMute
//   setSourceVolume / toggleSourceMute
//   setAppVolume(node, v) / toggleAppMute(node)
//   appDisplayName / appIconSource
//   openPavucontrol()
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "rowsync.js" as RowSync

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

    // ---- 输出/输入设备：详情页要「点选切默认」----
    //
    // Pipewire.nodes 把输出设备、输入设备、应用流混在一起：isStream 区分
    // 设备和流，isSink 区分方向。只在详情页枚举并追踪——设备的
    // description/properties 要 PwObjectTracker 绑上才有值，常驻订阅白花钱
    readonly property var sinks: detailActive ? _audioDevices(true) : []
    readonly property var sources: detailActive ? _audioDevices(false) : []

    function _audioDevices(wantSink) {
        const out = []
        const items = (Pipewire.nodes && Pipewire.nodes.values) || []
        for (let i = 0; i < items.length; i++) {
            const n = items[i]
            if (!n || n.isStream || !n.audio)
                continue
            if (!!n.isSink !== wantSink)
                continue
            out.push(n)
        }
        return out
    }

    PwObjectTracker {
        objects: root.detailActive ? root.sinks.concat(root.sources) : []
    }

    // 稳定行模型：设备行要能滑进滑出（插耳机、连蓝牙音箱）。
    // 之前设备列表是 Repeater，而 Repeater 压根没有 add/remove 过渡，
    // 新设备只能硬冒出来。节点是稳定的 QObject，所以按身份比对。见 rowsync.js
    ListModel {
        id: _sinkModel
        dynamicRoles: true
    }

    ListModel {
        id: _sourceModel
        dynamicRoles: true
    }

    readonly property var sinkRows: _sinkModel
    readonly property var sourceRows: _sourceModel

    onSinksChanged: RowSync.sync(_sinkModel, sinks, "node")
    onSourcesChanged: RowSync.sync(_sourceModel, sources, "node")

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource

    // 切默认走 preferredDefault*：Pipewire 会把它落到 wireplumber 的
    // 默认节点设置上，重启也记得
    function setDefaultSink(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node
    }

    function setDefaultSource(node) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node
    }

    function deviceLabel(node) {
        if (!node)
            return ""
        return node.nickname || node.description || node.name || ""
    }

    // 设备类型提示：从节点属性猜，猜不到就留空（不编造）
    function deviceHint(node) {
        if (!node)
            return ""
        const props = node.properties || {}
        const api = String(props["device.api"] || "").toLowerCase()
        const bus = String(props["device.bus"] || "").toLowerCase()
        const form = String(props["device.form-factor"] || "").toLowerCase()
        const nm = String(node.name || "").toLowerCase()
        if (api === "bluez5" || bus === "bluetooth")
            return "蓝牙音频"
        if (form === "headphone" || form === "headset")
            return "耳机"
        if (nm.indexOf("hdmi") >= 0)
            return "显示器"
        if (form === "speaker")
            return "扬声器"
        if (bus === "usb")
            return "USB"
        if (bus === "pci")
            return "内置"
        return ""
    }

    function deviceIcon(node) {
        if (!node)
            return "speaker"
        const props = node.properties || {}
        const icon = String(props["device.icon-name"] || "").toLowerCase()
        const form = String(props["device.form-factor"] || "").toLowerCase()
        const api = String(props["device.api"] || "").toLowerCase()
        const nm = String(node.name || "").toLowerCase()
        if (!node.isSink)
            return "mic"
        if (form === "headphone" || form === "headset"
                || icon.indexOf("headphone") >= 0 || icon.indexOf("headset") >= 0)
            return "headphones"
        if (api === "bluez5")
            return "bluetooth_audio"
        if (nm.indexOf("hdmi") >= 0)
            return "tv"
        return "speaker"
    }

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

    // 应用流的取值口：linkGroup 是 Pipewire 的分组对象，音频节点藏在 .source 里，
    // 音量/静音又在 node.audio 下面。UI 只拿着分组和节点、不往里钻，
    // 和 appDisplayName / appIconSource / setAppVolume 一族一致
    function appNode(linkGroup) {
        return linkGroup ? linkGroup.source : null
    }

    function appReady(node) {
        return !!(node && node.ready)
    }

    function appMuted(node) {
        return !!(node && node.ready && node.audio && node.audio.muted)
    }

    function appVolume(node) {
        return (node && node.ready && node.audio) ? node.audio.volume : 0
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
