// RailRipple — 框边的水波（plan 第 6 轮）
//
// 这个效果在合并之前做不了，不是因为效果本身难，而是因为 bar 和三条 rail 是
// 四个独立 Wayland surface：面板所在的窗没法往 rail 所在的窗里画一个像素，
// 想同步就得跨窗传状态，还要指望两个窗在同一帧提交。合并成一棵场景图之后，
// 波只是一个沿路径推进的数——所以这里没有任何跨窗机制，就是普通 QML。
//
// ============================================================
// 两层，职责不同
// ============================================================
//   常驻起伏（drift）  有面板开着时，三条 rail 的内沿一直在波动。厚度在
//                      waveMin ~ waveMin+2*waveAmp 之间摆，均值正好等于静止时
//                      的 rail 厚度——所以"框变胖了"不是它给人的印象，"框在
//                      呼吸"才是。
//   周期行波（pulse）  每 pulseEveryMs 放一发，从面板贴的那条边出发绕框跑一趟，
//                      峰值比起伏的波峰再高 pulseExtra，所以能从起伏里认出来。
//                      开面板那一刻也放一发。
//
// 全关之后两层都停：Shape 不可见、动画 running 转假、一个像素都不画。渲染循环
// 是 n=basic（渲染同步在主线程），永久动画等于主线程永远不休息，所以"空闲真的
// 静止"是硬要求，不是省一点的问题。
//
// ============================================================
// 为什么起伏用 Shape 而不是切片
// ============================================================
// 一眼看去最直接的做法是把整条 rail 切成几百个小矩形，每片厚度按 sin 取值，
// 然后每帧推进相位。别这么干：那是每帧上千次 JS 绑定求值 + 上千个临时对象，
// 而这个壳最大的卡顿源恰恰是 QML 的 JS 垃圾回收（实测一次回收停 ~160ms，
// 见 FrameWindow 里的说明）。给自己造垃圾去做一个装饰动画是本末倒置。
//
// 所以反过来：波形烘成一条**静态** SVG 路径（Shape + PathSvg，正弦用二次贝塞
// 尔逼近，控制点取 2 倍幅度，见 stripPath 的注释），路径只在几何变化时重算一次；
// 每帧变的只有这条路径的位移。位移是一个 NumberAnimation 打在 x/y 上，走 C++
// 动画系统，JS 一行都不跑。条带比 rail 长出两个波长，位移走满一个波长就回零——
// 波形本身周期就是一个波长，所以接缝处像素级重合，看不出跳。
//
// 周期行波仍然是切片：它要拐过框的四个角，一个平移的 Shape 跟不了带角的路径。
// 但它只有 24 片、且只在放波的两三秒里活着，代价可以忽略。
//
// ============================================================
// 路径（行波用）
// ============================================================
// 框不是闭环：顶边中间是空的（左段、岛、右段之间有豁口）。所以路径是一条
// 开口的线，两端就是两个豁口，波跑到那儿自然消失：
//
//   左段底边(由内向外) → 左 rail(上→下) → 底 rail(左→右)
//                       → 右 rail(下→上) → 右段底边(由内向外)
//
// 两段的行程都减掉 22：段的下外角是 bottomRightRadius/bottomLeftRadius = 22，
// 圆角之后段的平底边就到那儿为止，再往外画鼓包会悬在空处。
//
// 常驻起伏只跑三条 rail，不上顶栏两段：段有 barHeight 那么高，让它的底边跟着
// 起伏就等于在段上啃出一排缺口。行波可以上段，因为它只加厚不减厚。

import QtQuick
import QtQuick.Shapes
import qs.Components
import qs.data.state

Item {
    id: root


    required property int railThickness
    required property int barHeight
    // 两段的实际宽度：段宽绑内容宽度，会变
    required property real leftSegWidth
    required property real rightSegWidth

    // 有面板开着才动。岛的 Hub 也算——它一样进 Panels 的栈
    readonly property bool active: Panels.keyboardHeld

    // ---- 起伏的厚度预算 ----
    // waveMin 实心底 + 2*waveAmp 的起伏带。4 + 8 → 厚度在 4~12 之间摆，均值 8，
    // 正好是静止时的 rail 厚度。波峰会盖住应用窗口边缘 4px，这是设计选择：
    // 开着 rail 面板的时候本来就不在看窗口。
    // rail 自己要同步缩到 waveMin，否则它那 8px 会把波谷填掉（见 FrameWindow）
    property int waveMin: 4
    property int waveAmp: 4
    property int waveLength: 220
    // 起伏走完一个波长的时间。这是"慢"的那个旋钮
    property int driftMs: Size.anim.durWaveDrift
    property color waveColor: Color.background

    // 起伏的幅度是渐进的：面板开合那一下让它长出来/收回去，别啪一下出现。
    // 这条会让路径在过渡的十几帧里重算——十几帧的字符串拼接无所谓，别把它
    // 挂到每帧上就行
    property real ampNow: 0
    Behavior on ampNow {
        Anim { type: Anim.Spatial }
    }
    onActiveChanged: ampNow = active ? waveAmp : 0

    readonly property int maxThick: waveMin + 2 * waveAmp

    // ---- 行波 ----
    property int pulseExtra: 4
    property int pulseEveryMs: 6000
    property int sliceCount: 12
    property int pulseLength: 260
    readonly property real pulseMax: maxThick + pulseExtra
    readonly property real sliceLen: pulseLength / sliceCount

    // ---- 行波路径的累计里程 ----
    // 段的圆角半径，和 Bar.qml 的 bottomRightRadius/bottomLeftRadius 对齐
    readonly property int segCornerR: 22

    // 两段的行程还要再减掉 rail 厚度：段的平底边虽然一直画到 x=0，但 x∈[0,8]
    // 那一截是框的**内部**（上面是段、下面是竖 rail），不是内边界。内边界在
    // (railThickness, barHeight) 这个点上转弯——路径必须在那儿接上竖 rail，
    // 少减这一截波就会跑进框里再跳出来
    readonly property real lenLeftSeg: Math.max(0, leftSegWidth - segCornerR - railThickness)
    readonly property real lenVRail: Math.max(0, height - railThickness - barHeight)
    readonly property real lenBottom: Math.max(0, width - railThickness * 2)
    readonly property real lenRightSeg: Math.max(0, rightSegWidth - segCornerR - railThickness)

    readonly property real s1: lenLeftSeg                // 左 rail 起点
    readonly property real s2: s1 + lenVRail             // 底 rail 起点
    readonly property real s3: s2 + lenBottom            // 右 rail 起点
    readonly property real s4: s3 + lenVRail             // 右段起点
    readonly property real sEnd: s4 + lenRightSeg

    // ============================================================
    // 常驻起伏
    // ============================================================
    // 生成"一条波浪内沿的实心条带"的 SVG 路径，只在几何变化时跑。
    //
    // along   条带延伸长度（已含两头各一个波长的余量）
    // span    条带的横向占位 = maxThick，实心边贴 0 侧或 span 侧
    // phase0  这条带在整个框上的起始里程，用来让三条 rail 的波看起来是连着的
    // axis    "left"   沿 +y 延伸，厚度朝 +x（贴屏幕左沿，实心边在 0 侧）
    //         "right"  沿 +y 延伸，厚度朝 -x（贴屏幕右沿，实心边在 span 侧）
    //         "bottom" 沿 +x 延伸，厚度朝 -y（贴屏幕下沿，实心边在 span 侧）
    //
    // 正弦用两段二次贝塞尔逼近：控制点取 ±amp 的**两倍**偏移，因为二次曲线的
    // 中点只走到控制点的一半（B(0.5)=0.25P0+0.5P1+0.25P2）。于是内沿在
    // waveMin 和 waveMin+2*amp 之间摆，两段接缝处正好落在中线 waveMin+amp
    function stripPath(along, span, phase0, axis) {
        const wl = root.waveLength
        const amp = root.ampNow
        const mid = root.waveMin + amp
        const lo = root.waveMin + amp - 2 * amp   // 控制点：波峰侧（厚度小）
        const hi = root.waveMin + amp + 2 * amp   // 控制点：波谷侧（厚度大）
        const half = wl / 2
        const q = half / 2
        const vertical = axis !== "bottom"
        const mirror = axis !== "left"
        // 厚度 → 横向坐标
        const c = t => mirror ? (span - t) : t
        // (厚度, 沿程) → "x,y"
        const P = (t, u) => vertical
            ? `${c(t).toFixed(2)},${u.toFixed(2)}`
            : `${u.toFixed(2)},${c(t).toFixed(2)}`

        // 起始相位：把波形整体挪 -(phase0 mod wl)，于是三条带接起来是同一列波
        const shift = -(((phase0 % wl) + wl) % wl)
        let u = shift
        let d = `M ${P(mid, u)} `
        while (u < along) {
            d += `Q ${P(lo, u + q)} ${P(mid, u + half)} `
            d += `Q ${P(hi, u + half + q)} ${P(mid, u + wl)} `
            u += wl
        }
        // 收边：沿实心边回到起点
        d += `L ${P(0, u)} L ${P(0, shift)} Z`
        return d
    }

    component Strip: Item {
        id: strip

        required property string axis
        required property real along     // rail 的可见长度
        required property real phase0
        // 波往里程增大的方向跑（左 rail 向下、底 rail 向右）；右 rail 反着，
        // 这样波在框上是顺着一个方向绕的，不是两边各自乱走
        property bool reverse: false

        visible: root.ampNow > 0.01
        clip: true

        readonly property real wl: root.waveLength

        Shape {
            id: shape
            preferredRendererType: Shape.CurveRenderer
            // 同步构建：这条路径在开合过渡的十几帧里会重算，异步会撕
            asynchronous: false

            // 条带比 rail 长出两个波长：一个给起始相位挪，一个给位移跑
            width: strip.axis === "bottom" ? strip.along + 2 * strip.wl : root.maxThick
            height: strip.axis === "bottom" ? root.maxThick : strip.along + 2 * strip.wl

            // 位移：只有这一条属性每帧在变，走 C++ 动画系统
            property real drift: 0
            x: strip.axis === "bottom" ? -strip.wl + drift : 0
            y: strip.axis === "bottom" ? 0 : -strip.wl + drift

            NumberAnimation on drift {
                running: strip.visible
                loops: Animation.Infinite
                from: strip.reverse ? strip.wl : 0
                to: strip.reverse ? 0 : strip.wl
                duration: root.driftMs
                // 匀速：水面起伏没有加减速，用 easing 反而像在抽
                easing.type: Easing.Linear
            }

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: root.waveColor
                PathSvg {
                    path: root.stripPath(strip.along + 2 * strip.wl,
                                         root.maxThick, strip.phase0, strip.axis)
                }
            }
        }
    }

    // 三条带的 phase0 按框上的累计里程给，于是波看起来是一路绕过来的
    Strip {
        x: 0
        y: root.barHeight
        width: root.maxThick
        height: root.lenVRail
        axis: "left"
        along: root.lenVRail
        phase0: 0
    }

    Strip {
        // 横向不留内缩：竖 rail 缩到 waveMin 时角上不能有豁口，同色叠着最省事
        x: 0
        y: root.height - root.maxThick
        width: root.width
        height: root.maxThick
        axis: "bottom"
        along: root.width
        phase0: root.lenVRail
    }

    Strip {
        x: root.width - root.maxThick
        y: root.barHeight
        width: root.maxThick
        height: root.lenVRail
        axis: "right"
        along: root.lenVRail
        phase0: root.lenVRail + root.width
        reverse: true
    }

    // ============================================================
    // 周期行波
    // ============================================================
    // 出生点的里程
    property real origin: 0
    // 波前离出生点的距离，0 → 跑完全程
    property real spread: 0
    property bool playing: false
    // 上一次开面板贴的边，周期发射时沿用
    property string lastEdge: "left"

    // 面板贴哪条边，出生点就在那条 rail 的中点
    function originFor(edge) {
        if (edge === "right")
            return s3 + lenVRail / 2
        if (edge === "bottom")
            return s2 + lenBottom / 2
        return s1 + lenVRail / 2
    }

    function trigger(edge) {
        if (edge !== undefined && String(edge).length > 0)
            lastEdge = String(edge)
        // 两头哪边路远按哪边算，保证两个波前都能跑到豁口
        origin = originFor(lastEdge)
        const reach = Math.max(origin, sEnd - origin) + pulseLength
        spreadAnim.stop()
        spread = 0
        playing = true
        spreadAnim.to = reach
        spreadAnim.restart()
        pulseTimer.restart()
    }

    // 面板全关了就别再发；开着的时候每 pulseEveryMs 来一发
    Timer {
        id: pulseTimer
        interval: root.pulseEveryMs
        repeat: true
        running: root.active
        onTriggered: root.trigger("")
    }

    NumberAnimation {
        id: spreadAnim
        target: root
        property: "spread"
        duration: Size.anim.durRipple
        // 减速：出闸快，靠近远端收势，像真的在扩散
        easing.type: Easing.Bezier
        easing.bezierCurve: Size.anim.curveDecel
        onFinished: root.playing = false
    }

    // 里程 → 落在第几段
    function segOf(d) {
        if (d < s1) return 0
        if (d < s2) return 1
        if (d < s3) return 2
        if (d < s4) return 3
        return 4
    }

    Repeater {
        model: root.sliceCount * 2

        Rectangle {
            id: slice

            required property int index

            // 前半批往里程增大的方向跑，后半批反向
            readonly property int dir: index < root.sliceCount ? 1 : -1
            readonly property int i: index % root.sliceCount
            // 本片在波包里的位置，波包中心对齐波前
            readonly property real offset: (i + 0.5 - root.sliceCount / 2) * root.sliceLen
            readonly property real dist: root.origin + dir * (root.spread + offset)
            // 厚度剖面：sin 的一个拱，两端趋零，中间最厚。
            // 从框的外沿量起（不是从 rail 内沿），所以它是"叠上去"的：波包两头
            // 薄到被起伏盖住看不见，只有中间那一段冒出起伏的波峰，读成一记涌浪
            readonly property real thick: root.pulseMax
                * Math.sin(Math.PI * (slice.i + 0.5) / root.sliceCount)
            readonly property int seg: root.segOf(slice.dist)
            readonly property real half: root.sliceLen / 2

            visible: root.playing && slice.dist >= 0 && slice.dist <= root.sEnd
            color: root.waveColor
            antialiasing: true

            // 竖 rail 上鼓包朝内（+x / -x）；横边上朝下 / 朝上
            x: {
                switch (slice.seg) {
                case 0: return root.leftSegWidth - root.segCornerR - slice.dist - slice.half
                case 1: return 0
                case 2: return root.railThickness + (slice.dist - root.s2) - slice.half
                case 3: return root.width - slice.thick
                // 右段是由内向外走：路径从右 rail 顶端 (width-railThickness, barHeight)
                // 接过来，所以 x 递减
                default: return root.width - root.railThickness
                    - (slice.dist - root.s4) - slice.half
                }
            }

            y: {
                switch (slice.seg) {
                case 0: return root.barHeight
                case 1: return root.barHeight + (slice.dist - root.s1) - slice.half
                case 2: return root.height - slice.thick
                case 3: return root.height - root.railThickness
                    - (slice.dist - root.s3) - slice.half
                default: return root.barHeight
                }
            }

            width: (slice.seg === 1 || slice.seg === 3) ? slice.thick : root.sliceLen
            height: (slice.seg === 1 || slice.seg === 3) ? root.sliceLen : slice.thick
        }
    }
}
