pragma Singleton

// ============================================================
// 电池服务 — Battery
// ============================================================
// 通过 Quickshell.UPower 原生绑定读取硬件电池信息。
// 纯只读数据——电量、充放电状态、剩余时间。
// ============================================================
// 对外接口一览：
//
// 属性（readonly）：
//   percentage      double   电量百分比（0-100；UPower 常为 0..1，已归一化）
//   onBattery       bool     是否在用电池（拔了电源）
//   charging        bool     是否正在充电
//   discharging     bool     是否正在放电
//   fullyCharged    bool     是否已充满
//   timeToEmpty     double   剩余使用时间（秒，0 = 未知）
//   timeToFull      double   充满所需时间（秒，0 = 未知）
//   changeRate      double   充放电速率（W，正=充电，负=放电）
//   energy          double   当前电量（Wh）
//   energyCapacity  double   满电容量（Wh）
//   isPresent       bool     电池是否存在（台式机无电池 = false）
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property var _device: UPower.displayDevice

    // Quickshell/UPower 的 percentage 多为 0..1；少数环境可能已是 0..100
    readonly property double percentage: {
        if (!_device)
            return 0
        const p = Number(_device.percentage) || 0
        if (p <= 0)
            return 0
        return p <= 1.0 ? (p * 100.0) : p
    }
    readonly property bool onBattery: UPower.onBattery
    readonly property bool isPresent: _device ? _device.isPresent : false

    // 充放电状态（changeRate > 0 = 充电, < 0 = 放电, ≈ 0 = 满电/空闲）
    readonly property bool charging: _device ? _device.changeRate > 0.5 : false
    readonly property bool discharging: _device ? _device.changeRate < -0.5 : false
    readonly property bool fullyCharged: percentage >= 99 && !charging && !discharging

    readonly property double timeToEmpty: _device ? _device.timeToEmpty : 0
    readonly property double timeToFull: _device ? _device.timeToFull : 0
    readonly property double changeRate: _device ? _device.changeRate : 0
    readonly property double energy: _device ? _device.energy : 0
    readonly property double energyCapacity: _device ? _device.energyCapacity : 0
}
