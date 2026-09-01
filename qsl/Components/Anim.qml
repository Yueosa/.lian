// Anim — 全局统一 NumberAnimation 封装
//
// 用法：
//   Behavior on x       { Anim {} }                        // 默认 Spatial
//   Behavior on opacity { Anim { type: Anim.Effects } }
//
// type 自动映射 Size.anim 的曲线+时长，业务代码不再写 duration/曲线。
// spatial 三档共用同一条 curveSpatial（与 hypr/lua/appearance.lua 完全相同），
// 档与档只差时长——窗口和 shell 面板的"手感基因"一致。
// 装饰性循环动画（旋转/滚动等）不要用本组件，见 plan.md 白名单。

import QtQuick
import qs.data.state

NumberAnimation {
    id: root

    enum Type {
        Spatial,        // 位移/尺寸 默认：500ms（hypr 窗口同档）
        SpatialFast,    // 位移/尺寸 快速：350ms（悬停展开/容器 morph）
        SpatialSlow,    // 位移/尺寸 慢速：650ms
        Effects,        // 透明度 默认：200ms，无过冲
        EffectsFast,    // 悬停/按压反馈：150ms，无过冲
        EffectsSlow,    // 慢速效果：300ms，无过冲
        Enter,          // 入场：500ms decel，到位即稳不要过冲
        Exit            // 离场：200ms accel，加速离开不拖沓
    }

    property int type: Anim.Spatial

    duration: {
        switch (root.type) {
        case Anim.SpatialFast:              return Size.anim.durFast;
        case Anim.SpatialSlow:              return Size.anim.durSlow;
        case Anim.EffectsFast:              return Size.anim.durFxFast;
        case Anim.Effects:                  return Size.anim.durFx;
        case Anim.EffectsSlow:              return Size.anim.durFxSlow;
        case Anim.Exit:                     return Size.anim.durFx;
        case Anim.Enter:
        case Anim.Spatial:
        default:                            return Size.anim.durNormal;
        }
    }

    easing.type: Easing.Bezier
    easing.bezierCurve: {
        switch (root.type) {
        case Anim.EffectsFast:              return Size.anim.curveEffects;
        case Anim.Effects:
        case Anim.EffectsSlow:              return Size.anim.curveEffectsSlow;
        case Anim.Enter:                    return Size.anim.curveDecel;
        case Anim.Exit:                     return Size.anim.curveAccel;
        case Anim.SpatialFast:
        case Anim.SpatialSlow:
        case Anim.Spatial:
        default:                            return Size.anim.curveSpatial;
        }
    }
}
