// QslStagger — 错峰入场节拍器
//
// 页根上挂一份，卡片问 `shown(n)`。步长 36ms ≈ 两帧，曲线不在这里——
// 卡片自己用 Anim.Enter / EffectsSlow 去追 true。
// restart() 给 Hub 切 Tab：旧页卸掉后新页要从第 0 拍再走一遍。

import QtQuick

Item {
    id: root

    width: 0
    height: 0

    property int beat: 0
    property int stepMs: 36
    property int lastOrder: 12

    function shown(order) {
        return beat > order
    }

    function restart() {
        beat = 0
        ticker.restart()
    }

    Timer {
        id: ticker
        interval: root.stepMs
        running: true
        repeat: true
        onTriggered: {
            root.beat += 1
            if (root.beat > root.lastOrder)
                stop()
        }
    }
}
