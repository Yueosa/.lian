pragma Singleton

-- 音量服务
--    管理扬声器（Sink）和麦克风（Source）的音量与静音状态
--    依赖 Pipewire，由 PwObjectTracker 自动追踪设备变更
--    音量范围 0.0 ~ 1.0（QML real），UI 层自行换算为百分比

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    -- ============================================================
    -- 设备追踪
    --    自动追踪默认输出和输入设备，拔插耳机/麦克风时自动切换
    -- ============================================================

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    -- 当前输出设备是否为耳机（通过设备描述判断）
    readonly property bool isHeadphone: {
        if (!Pipewire.defaultAudioSink) return false
        const desc = (Pipewire.defaultAudioSink.description || "").toLowerCase()
        return desc.includes("headphone")
    }


    -- ============================================================
    -- 扬声器（Sink）— 输出音量
    -- ============================================================

    readonly property bool sinkMuted: Pipewire.defaultAudioSink
        ? Pipewire.defaultAudioSink.audio.muted : false
    readonly property real sinkVolume: Pipewire.defaultAudioSink
        ? Pipewire.defaultAudioSink.audio.volume : 0

    function toggleSinkMute() {
        if (Pipewire.defaultAudioSink)
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
    }

    function setSinkVolume(volume: real) {
        const safe = Math.max(0.0, Math.min(1.0, volume))
        if (Pipewire.defaultAudioSink) {
            Pipewire.defaultAudioSink.audio.volume = safe
            if (Pipewire.defaultAudioSink.audio.muted)
                Pipewire.defaultAudioSink.audio.muted = false  // 调音量自动解静音
        }
    }


    -- ============================================================
    -- 麦克风（Source）— 输入音量
    -- ============================================================

    readonly property bool sourceMuted: Pipewire.defaultAudioSource
        ? Pipewire.defaultAudioSource.audio.muted : false
    readonly property real sourceVolume: Pipewire.defaultAudioSource
        ? Pipewire.defaultAudioSource.audio.volume : 0

    function toggleSourceMute() {
        if (Pipewire.defaultAudioSource)
            Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
    }

    function setSourceVolume(volume: real) {
        const safe = Math.max(0.0, Math.min(1.0, volume))
        if (Pipewire.defaultAudioSource) {
            Pipewire.defaultAudioSource.audio.volume = safe
            if (Pipewire.defaultAudioSource.audio.muted)
                Pipewire.defaultAudioSource.audio.muted = false
        }
    }
}
