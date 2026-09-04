// RailRipple — 开面板时沿整个框跑一趟的鼓包波（plan 第 6 轮）
//
// 这个效果在合并之前做不了，不是因为效果本身难，而是因为 bar 和三条 rail 是
// 四个独立 Wayland surface：面板所在的窗没法往 rail 所在的窗里画一个像素，
// 想同步就得跨窗传状态，还要指望两个窗在同一帧提交。合并成一棵场景图之后，
// 波只是一个沿路径推进的数——所以这里没有任何跨窗机制，就是普通 QML。
//
// ============================================================
// 怎么把「鼓包」做成便宜的
// ============================================================
// 鼓包是**厚度**沿路径的隆起，rail 只有 8px 宽，想画出平滑的厚度剖面，正路是
// Shape 或 shader。但这里有个便宜得多的办法：把波包切成 sliceCount 片薄片，
// 每片是一个厚度恒定的小矩形，厚度按 sin 取值。3px 的鼓包切 12 档，档间差
// 0.25px——亚像素，看不出台阶。
//
// 于是代价是固定的 24 个 Rectangle（两个波前 × 12 片），静止时全部
// visible: false，一个像素都不画。没有动态创建，所以起波那一刻不会有建对象
// 的顿挫（这正是我们一路在躲的东西）。
//
// ============================================================
// 路径
// ============================================================
// 框不是闭环：顶边中间是空的（左段、岛、右段之间有豁口）。所以路径是一条
// 开口的линия，两端就是两个豁口，波跑到那儿自然消失：
//
//   左段底边(由内向外) → 左 rail(上→下) → 底 rail(左→右)
//                       → 右 rail(下→上) → 右段底边(由内向外)
//
// 两段的行程都减掉 22：段的下外角是 bottomRightRadius/bottomLeftRadius = 22，
// 圆角之后段的平底边就到那儿为止，再往外画鼓包会悬在空处。
//
// 鼓包朝内长（朝外是屏幕外），所以过波时会盖住应用窗口边缘那 3px。这是
// 设计选择：换来的是「框在呼吸」而不是「框在变色」。

import QtQuick
import qs.Components
import qs.data.state

Item {
    id: root

    required property int railThickness
    required property int barHeight
    // 两段的实际宽度：段宽绑内容宽度，会变
    required property real leftSegWidth
    required property real rightSegWidth

    // 鼓包最厚处（px）。8 → 11
    property int bulge: 3
    // 一个波包沿路径的长度
    property int waveLength: 170
    property int sliceCount: 12
    // 与 rail 同色：鼓包要读成几何，不是读成高光
    property color waveColor: Color.background

    readonly property real sliceLen: waveLength / sliceCount

    // ---- 路径分段的累计里程 ----
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

    // ---- 波的状态 ----
    // 出生点的里程
    property real origin: 0
    // 波前离出生点的距离，0 → 跑完全程
    property real spread: 0
    property bool playing: false

    // 面板贴哪条边，出生点就在那条 rail 的中点
    function originFor(edge) {
        if (edge === "right")
            return s3 + lenVRail / 2
        if (edge === "bottom")
            return s2 + lenBottom / 2
        return s1 + lenVRail / 2
    }

    function trigger(edge) {
        // 两头哪边路远按哪边算，保证两个波前都能跑到豁口
        origin = originFor(edge)
        const reach = Math.max(origin, sEnd - origin) + waveLength
        spreadAnim.stop()
        spread = 0
        playing = true
        spreadAnim.to = reach
        spreadAnim.restart()
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
            // 厚度剖面：sin 的一个拱，两端趋零，中间最厚
            readonly property real thick: root.bulge
                * Math.sin(Math.PI * (i + 0.5) / root.sliceCount)
            readonly property int seg: root.segOf(dist)
            // 跑出豁口就不画了
            readonly property real half: root.sliceLen / 2

            visible: root.playing && dist >= 0 && dist <= root.sEnd
            color: root.waveColor
            antialiasing: true

            // 竖 rail 上鼓包朝内（+x / -x）；横边上朝下 / 朝上
            x: {
                switch (slice.seg) {
                case 0: return root.leftSegWidth - root.segCornerR - slice.dist - slice.half
                case 1: return root.railThickness
                case 2: return root.railThickness + (slice.dist - root.s2) - slice.half
                case 3: return root.width - root.railThickness - slice.thick
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
                case 2: return root.height - root.railThickness - slice.thick
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
