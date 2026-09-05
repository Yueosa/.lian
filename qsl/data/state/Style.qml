pragma Singleton

// ============================================================
// 设计令牌 — Style
// ============================================================
// 与 Size（几何）、Color（色值）分工，此处只放「效果配方」。
//
// 第 9 轮瘦身：原先还有 shadow（12 个成员）和 bg（4 个）两组，全是死的。
// shadow 的唯一消费者是 QslShadow，而 QslShadow 只被 QslCard 引用，QslCard 又
// 零调用方——一条跨三层的死链，三个文件一起删了。bg 那组从来没人读过。
// 全项目的卡片壳早就换成 RailContainer 了。
// ============================================================

import QtQuick
import Quickshell

Singleton {
    id: root

    // 卡片描边。八处活引用全在 ui/leftbar（TodoTabsCard / TodoListCard /
    // SysPsiCard / TimeClockCard），配色走 Color.outlineVariant + 这个 opacity。
    readonly property QtObject border: QtObject {
        readonly property real width: 1
        readonly property real opacity: 0.08
    }
}
