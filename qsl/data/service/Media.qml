pragma Singleton

// ============================================================
// 媒体服务 — Media
// ============================================================
// 管理所有 MPRIS 播放器，自动选择当前活跃播放器。
// Quickshell 内置的 Mpris/MprisPlayer 已提供足够数据（title/artist/albumArt/position...），
// 本服务只做"选哪个播放器"的决策，不做二次包装。
// ============================================================
// 对外接口一览：
//
// 属性（readonly）：
//   list       list<MprisPlayer>   所有已注册播放器
//   active     MprisPlayer         当前活跃播放器（自动选择）
//   count      int                 播放器数量
//
// 属性（可写）：
//   manualActive  MprisPlayer      用户手动指定播放器（设 null 恢复自动选择）
//
// 方法：
//   nextPlayer()        切换到下一个播放器
//   previousPlayer()    切换到上一个播放器
//
// 活跃播放器选择逻辑：
//   1. manualActive（用户手动指定）
//   2. 第一个正在播放的
//   3. 列表第一个（兜底）
//   4. null（无播放器）
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property int count: list.length

    property var manualActive: null

    // 活跃播放器：手动指定 → 正在播放 → 第一个 → null
    readonly property MprisPlayer active: {
        if (manualActive) return manualActive
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying) return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    function nextPlayer() {
        if (list.length <= 1) return
        const idx = list.indexOf(active)
        manualActive = list[(idx + 1) % list.length]
    }

    function previousPlayer() {
        if (list.length <= 1) return
        const idx = list.indexOf(active)
        manualActive = list[(idx - 1 + list.length) % list.length]
    }

    // 用户手动指定的播放器退出时，自动恢复 auto 模式
    Connections {
        target: Mpris.players
        function onValuesChanged() {
            if (root.manualActive) {
                let stillExists = false
                for (let i = 0; i < list.length; i++) {
                    if (list[i] === root.manualActive) {
                        stillExists = true
                        break
                    }
                }
                if (!stillExists) root.manualActive = null
            }
        }
    }
}
