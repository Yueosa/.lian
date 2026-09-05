// CAnim — 全局统一 ColorAnimation 封装
//
// 用法：
//   Behavior on color { CAnim {} }                       // 默认 Effects
//   Behavior on color { CAnim { type: CAnim.Theme } }    // 主题换色
//
// 颜色/透明度不看过冲（过冲会闪），曲线只用 effects 系。
// Effects 取 150ms 快档：绝大多数用点是悬停/按压/选中反馈，慢了发肉。
// Theme 是 600ms 慢档：主题换色放慢，留出感受过程的时间。

import QtQuick
import qs.data.state

ColorAnimation {
    id: root

    enum Type {
        Effects,        // 交互颜色反馈：150ms
        Theme           // 主题换色：600ms（durTheme）
    }

    property int type: CAnim.Effects

    duration: root.type === CAnim.Theme ? Size.anim.durTheme : Size.anim.durFxFast

    easing.type: Easing.Bezier
    easing.bezierCurve: Size.anim.curveEffectsSlow
}
