pragma Singleton

// ============================================================
// 音量服务 — Volume
// ============================================================
// 与 PipeWire 声音服务器通信，提供一手准确数据。
// PwObjectTracker 自动追踪设备变更（拔插耳机/麦克风）。
// 音量范围 0.0 ~ 1.0（QML real），UI 层自行换算为百分比。
// ============================================================
// 对外接口一览：
//
// 属性（readonly，自动跟随 PipeWire 状态变化）：
//   sinkVolume  real     当前输出音量  例：0.50
//   sinkMuted   bool     输出是否静音
//   sinkName    string   输出设备名称  例："Starship Audio"
//   sourceVolume real    当前输入音量
//   sourceMuted bool     输入是否静音
//   sourceName  string   输入设备名称
//   isHeadphone bool     输出设备是否为耳机
//
// 方法：
//   setSinkVolume(real)  设置输出音量，自动解静音
//   volumeUp(step = 0.05) 输出音量 +step
//   volumeDown(step = 0.05) 输出音量 -step
//   toggleSinkMute()     切换输出静音
//   setSourceVolume(real) 设置输入音量，自动解静音
//   toggleSourceMute()   切换输入静音
// ============================================================

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    // ============================================================
    // 设备追踪
    //    自动追踪默认输出和输入设备，拔插时自动切换
    // ============================================================

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    readonly property bool isHeadphone: {
        if (!Pipewire.defaultAudioSink) return false
        const desc = (Pipewire.defaultAudioSink.description || "").toLowerCase()
        return desc.includes("headphone")
    }

    readonly property string sinkName: Pipewire.defaultAudioSink
        ? (Pipewire.defaultAudioSink.description || "") : ""

    readonly property string sourceName: Pipewire.defaultAudioSource
        ? (Pipewire.defaultAudioSource.description || "") : ""


    // ============================================================
    // 扬声器（Sink）— 输出
    // ============================================================

    readonly property bool sinkMuted: Pipewire.defaultAudioSink
        ? Pipewire.defaultAudioSink.audio.muted : false
    readonly property real sinkVolume: Pipewire.defaultAudioSink
        ? Pipewire.defaultAudioSink.audio.volume : 0

    function setSinkVolume(volume) {
        const safe = Math.max(0.0, Math.min(1.0, volume))
        if (Pipewire.defaultAudioSink) {
            Pipewire.defaultAudioSink.audio.volume = safe
            if (Pipewire.defaultAudioSink.audio.muted)
                Pipewire.defaultAudioSink.audio.muted = false
        }
    }

    function volumeUp(step) {
        const s = step === undefined ? 0.05 : step
        if (Pipewire.defaultAudioSink)
            setSinkVolume((Pipewire.defaultAudioSink.audio.volume || 0) + s)
    }

    function volumeDown(step) {
        const s = step === undefined ? 0.05 : step
        if (Pipewire.defaultAudioSink)
            setSinkVolume((Pipewire.defaultAudioSink.audio.volume || 0) - s)
    }

    function toggleSinkMute() {
        if (Pipewire.defaultAudioSink)
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
    }


    // ============================================================
    // 麦克风（Source）— 输入
    // ============================================================

    readonly property bool sourceMuted: Pipewire.defaultAudioSource
        ? Pipewire.defaultAudioSource.audio.muted : false
    readonly property real sourceVolume: Pipewire.defaultAudioSource
        ? Pipewire.defaultAudioSource.audio.volume : 0

    function setSourceVolume(volume) {
        const safe = Math.max(0.0, Math.min(1.0, volume))
        if (Pipewire.defaultAudioSource) {
            Pipewire.defaultAudioSource.audio.volume = safe
            if (Pipewire.defaultAudioSource.audio.muted)
                Pipewire.defaultAudioSource.audio.muted = false
        }
    }

    function toggleSourceMute() {
        if (Pipewire.defaultAudioSource)
            Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
    }
}
