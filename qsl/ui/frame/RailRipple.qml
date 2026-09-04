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
    // 顶栏两段的实际宽度：段宽绑内容宽度，会变
    required property real leftSegWidth
    required property real rightSegWidth

    // 贴边 rail 上有面板开着才动。**岛不算**——它是独立体系，理由见 Panels.railHeld
    readonly property bool active: Panels.railHeld

    // ---- 起伏的厚度预算 ----
    // waveMin 实心底 + 2*waveAmp 的起伏带 = 厚度在 8~16 之间摆。
    //
    // 这里踩过一次，记下来：一开始按"从 8px 里拿出 4px"做成 4~12（均值仍是 8），
    // 结果是 rail 自己得缩到 4px 才能露出波谷，而框的**接缝全是按 8px 配的**——
    // 四颗凹角耳是 14×14、顶栏两段的下外角是 r=22，都照 8px 的 rail 对齐。
    // rail 一缩，这些圆角当场露馅，起伏那条带也从"rail 在呼吸"变成"rail 旁边
    // 多了一条会动的东西"（用户原话："彻底和 railbar 分离开…圆角也直接露馅了"）。
    //
    // 所以改成只朝内鼓、绝不变薄：实心底就是 rail 那 8px 本身，接缝一个都不动，
    // 波峰盖住应用窗口边缘 8px——用户明确说没关系（开 railbar 时本来不看窗口），
    // Hyprland 那边还留着外边距
    property int waveMin: 8
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
    // 涌浪高出 rail 外沿多少。要明显高过起伏的波峰（maxThick=16）才能从起伏里
    // 认出来，所以给 12 → rail 上总厚 20
    property int pulseHeight: 12
    // 涌浪沿路径的长度。长一点读成"一记缓慢的涌浪"，短了读成"一个疙瘩在跑"
    property int pulseLength: 420
    // 两发之间的间隔。必须大于 durRipple（一趟的时长 4700），否则前一发还没跑完
    // 后一发就出闸，两个包叠在一起
    property int pulseEveryMs: 6000

    // ---- 框内沿的累计里程 ----
    // 沿框的内边界走一圈（顺时针）：左段底边（岛的豁口 → 左上角）→ 左 rail
    // （自上而下）→ 底 rail（自左而右）→ 右 rail（自下而上）→ 右段底边
    // （右上角 → 岛的豁口）。两端收在岛的豁口两侧，那是框上唯一的开口。
    //
    // 顶栏进出过一次，教训值得记：第一版把顶栏铺进来但**只铺了行波**，常驻起伏
    // 还是只在三条 rail 上。于是一个孤零零的鼓包爬过一条笔直静止的边——用户截图
    // 逐列量出来顶栏下沿鼓出 7~8px，读成"水波超出 Rightbar 的范围"。
    // 于是砍成三段（只走 rail）；但砍掉之后波拍到顶栏就摊平，框成了个开口的槽。
    // 现在顶栏的下沿也上常驻起伏，行波经过时只是"已经在起伏的边上涌起一记更大
    // 的"——和 rail 上读起来一样，这才对。
    //
    // 顶栏段的行程要减掉 rail 厚度和圆角：段的平底边虽然画到 x=0，但 x∈[0,8]
    // 那截是框的**内部**（上面是段、下面是竖 rail），内边界在 (8, barHeight)
    // 转弯；另一头 r=22 的下外角处底边开始上翘，波不能画到那儿去
    readonly property int segCornerR: 22
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
    // span    条带的横向占位，实心边贴 0 侧或 span 侧
    // phase0  这条带在整个框上的起始里程，用来让五条带的波看起来是连着的
    // axis    "left"   沿 +y 延伸，厚度朝 +x（贴屏幕左沿，实心边在 0 侧）
    //         "right"  沿 +y 延伸，厚度朝 -x（贴屏幕右沿，实心边在 span 侧）
    //         "bottom" 沿 +x 延伸，厚度朝 -y（贴屏幕下沿，实心边在 span 侧）
    //         "top"    沿 +x 延伸，厚度朝 +y（贴顶栏下沿，实心边在 0 侧）
    // base    实心底的厚度。rail 上是 railThickness（rail 自己那 8px 就是实心
    //         部分）；顶栏下沿是 **0**——顶栏自己那 44px 才是实心部分，波只能是
    //         挂在它下面的一条起伏带，多给一点顶栏就凭空变高了
    //
    // 正弦用两段二次贝塞尔逼近：控制点取 ±amp 的**两倍**偏移，因为二次曲线的
    // 中点只走到控制点的一半（B(0.5)=0.25P0+0.5P1+0.25P2）。于是内沿在
    // base 和 base+2*amp 之间摆，两段接缝处正好落在中线 base+amp
    function stripPath(along, span, phase0, axis, base) {
        const wl = root.waveLength
        const amp = root.ampNow
        const mid = base + amp
        const lo = base + amp - 2 * amp   // 控制点：波峰侧（厚度小）
        const hi = base + amp + 2 * amp   // 控制点：波谷侧（厚度大）
        const half = wl / 2
        const q = half / 2
        const vertical = axis === "left" || axis === "right"
        const mirror = axis === "right" || axis === "bottom"
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
        required property real along     // 这条边的可见长度
        required property real phase0    // 本带起点在框上的累计里程
        property real span: root.maxThick
        property real base: root.railThickness

        // 里程方向和本带局部 +u 相反时要镜像，**不能只反转位移**。
        //
        // 这里绕过一次弯，值得写下来：`stripPath` 生成的图案是 f(phase0 + u)，
        // u 是局部坐标；而物理上要的是 f(里程 - v·t)。当里程随局部 +u **递减**
        // 时（顶栏两段朝豁口、右 rail 朝上），里程 = 常数 - u，u 的系数是 -1，
        // 平移换不出来，必须镜像。
        // 只用 reverse 反转位移的话，流动方向是对的，但相位是反射的——两侧的
        // 波峰会在拐角处随时间**越走越开**，水在角上对撞。镜像之后，局部 u 就
        // 等于里程本身，phase0 直接填累计里程，四个拐角全对得上
        property bool mirrored: false

        readonly property bool horizontal: strip.axis === "bottom" || strip.axis === "top"

        visible: root.ampNow > 0.01
        clip: true

        readonly property real wl: root.waveLength

        transform: Scale {
            origin.x: strip.width / 2
            origin.y: strip.height / 2
            xScale: (strip.mirrored && strip.horizontal) ? -1 : 1
            yScale: (strip.mirrored && !strip.horizontal) ? -1 : 1
        }

        Shape {
            id: shape
            preferredRendererType: Shape.CurveRenderer
            // 同步构建：这条路径在开合过渡的十几帧里会重算，异步会撕
            asynchronous: false

            // 条带比边长出两个波长：一个给起始相位挪，一个给位移跑
            width: strip.horizontal ? strip.along + 2 * strip.wl : strip.span
            height: strip.horizontal ? strip.span : strip.along + 2 * strip.wl

            // 位移：只有这一条属性每帧在变，走 C++ 动画系统。
            // 一律 0 → wl 沿局部 +u 跑，方向由 mirrored 决定
            property real drift: 0
            x: strip.horizontal ? -strip.wl + drift : 0
            y: strip.horizontal ? 0 : -strip.wl + drift

            NumberAnimation on drift {
                running: strip.visible
                loops: Animation.Infinite
                from: 0
                to: strip.wl
                duration: root.driftMs
                // 匀速：水面起伏没有加减速，用 easing 反而像在抽
                easing.type: Easing.Linear
            }

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: root.waveColor
                PathSvg {
                    path: root.stripPath(strip.along + 2 * strip.wl, strip.span,
                                         strip.phase0, strip.axis, strip.base)
                }
            }
        }
    }

    // 五条带的 phase0 按框内沿的累计里程给，于是波是一路绕过来的。
    // 顶栏两段的 span 只有起伏带那 8px、base 给 0——顶栏自己那 44px 才是实心
    // 部分，多给一点顶栏就凭空变高了
    Strip {
        x: root.railThickness
        y: root.barHeight
        width: root.lenLeftSeg
        height: 2 * root.waveAmp
        axis: "top"
        along: root.lenLeftSeg
        span: 2 * root.waveAmp
        base: 0
        phase0: 0
        mirrored: true   // 里程从豁口往左上角走
    }

    Strip {
        x: 0
        y: root.barHeight
        width: root.maxThick
        height: root.lenVRail
        axis: "left"
        along: root.lenVRail
        phase0: root.s1
    }

    Strip {
        // 横向不留内缩：两个下角要被竖 rail 的带盖满，同色叠着最省事
        x: 0
        y: root.height - root.maxThick
        width: root.width
        height: root.maxThick
        axis: "bottom"
        along: root.width
        // 本带从 x=0 起，而底 rail 的里程从 x=railThickness 起，差这一截
        phase0: root.s2 - root.railThickness
    }

    Strip {
        x: root.width - root.maxThick
        y: root.barHeight
        width: root.maxThick
        height: root.lenVRail
        axis: "right"
        along: root.lenVRail
        phase0: root.s3
        mirrored: true   // 里程自下而上
    }

    Strip {
        x: root.width - root.railThickness - root.lenRightSeg
        y: root.barHeight
        width: root.lenRightSeg
        height: 2 * root.waveAmp
        axis: "top"
        along: root.lenRightSeg
        span: 2 * root.waveAmp
        base: 0
        phase0: root.s4
        mirrored: true   // 里程从右上角往豁口走
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
    property string lastValign: "top"
    // 出生点离拐角多远，按那条 rail 长度的比例。给 0.15（1028px 的竖 rail 上约
    // 154px）：涌浪本身 420px 长，所以出生那一刻包就跨在拐角上，读成"从角上冒
    // 出来"——这正是贴底的 N 该有的样子。给 0 会让一支波前一出闸就跑没了
    // 出生点离面板那一端的拐角多远，按那条 rail 长度的比例。
    // 约束是**出生点离路径两端要大于涌浪的半长**（210px），否则包在出生那一刻
    // 就跨在端点上、被裁剪框切掉一半。顶栏并进来之后路径的两端在**岛的豁口**，
    // 离三条 rail 都远，这条约束自动满足了（最紧的是 C 的 434px），所以内缩量
    // 可以回到 0.15——贴着面板那一端，出生那刻包就跨在拐角上，读成"从角上冒出来"
    property real originInset: 0.15

    // 波前离路径两端多少像素内开始收势。
    // 这个值就该等于**半长**：包的前沿正好在中心离端点半长时触到边界，所以从那
    // 一刻起开始收，收到 0 时中心刚好抵达顶栏——全程没有满振幅的包被硬切。
    // 之前给 100 是错的：中心还有 210px 时前沿就越界被裁了，而收势 110px 之后
    // 才开始，于是顶栏下沿被切出一道 12px 的硬边（用户看到的"像素偏移"）
    readonly property real endTaperPx: pulseLength / 2

    // 出生点在面板**自己那一端**，不是 rail 的中点。
    // 竖 rail 上里程的方向不一样：左 rail 从顶（s1）往下数，右 rail 从底（s3）
    // 往上数——所以同样是 valign "bottom"，左边取远端、右边取近端
    function originFor(edge, valign) {
        if (edge === "bottom")
            // 底 rail 上的面板（将来的 A）是居中的，中点就是它自己那一端
            return s2 + lenBottom / 2

        const inset = lenVRail * originInset
        if (edge === "right")
            return valign === "top" ? s4 - inset : s3 + inset
        return valign === "bottom" ? s2 - inset : s1 + inset
    }

    function trigger(edge, valign) {
        if (edge !== undefined && String(edge).length > 0)
            lastEdge = String(edge)
        if (valign !== undefined && String(valign).length > 0)
            lastValign = String(valign)
        // 两头哪边路远按哪边算，保证两个波前都能跑到豁口
        origin = originFor(lastEdge, lastValign)
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
        // 匀速。曾经用减速曲线（"出闸快、远端收势，像真的在扩散"），但一趟拉长
        // 到 7s 之后，减速段慢得像卡住了；而且要看清波在各条边之间怎么交接，
        // 速度恒定才跟得住
        easing.type: Easing.Linear
        onFinished: root.playing = false
    }

    // ---- 三段的里程起点 / 长度 ----
    // 写成 switch 函数而不是数组常量：绑定里每帧 new 一个数组就是每帧造垃圾，
    // 而 GC 停顿是这个壳最大的卡顿源（实测一次回收停 ~160ms）
    function segStartOf(i) {
        switch (i) {
        case 0: return 0
        case 1: return s1
        case 2: return s2
        case 3: return s3
        default: return s4
        }
    }

    function segLenOf(i) {
        switch (i) {
        case 0: return lenLeftSeg
        case 1: return lenVRail
        case 2: return lenBottom
        case 3: return lenVRail
        default: return lenRightSeg
        }
    }

    // 涌浪的钟形剖面，同起伏一样烘成静态路径。
    //
    // 这里换掉过一版切片法（把波包切 12 片薄矩形、每片厚度按 sin 取值）。那版在
    // 峰值只有 3px 时没问题——12 档档间差 0.25px 是亚像素。但峰值提到 12px 之后
    // 档间差变成 4px，配 35px 宽的片子，就是**一排肉眼可见的矩形台阶**。
    // 教训：切片法的档距是"峰值/片数"，改峰值就必须同步改片数，这种耦合不如
    // 直接画曲线。
    //
    // 两段三次贝塞尔拼一个 smoothstep：控制点与端点**同高**，于是 u=0、L/2、L
    // 三处的切线都是水平的，涌浪与平直 rail 之间没有折角。
    // kind: 0 = 厚度朝 +y（顶栏两段的底边）  1 = 朝 +x（左 rail）
    //       2 = 朝 -y（底 rail）             3 = 朝 -x（右 rail）
    function bumpPath(kind, base) {
        const L = pulseLength
        const h = pulseHeight
        const cross = base + h
        // (沿程 u, 厚度 t) → "x,y"。厚度一律从框的**外沿**量起
        const P = (u, t) => {
            const uu = u.toFixed(2)
            const tt = t.toFixed(2)
            const inv = (cross - t).toFixed(2)
            switch (kind) {
            case 0: return `${uu},${tt}`
            case 1: return `${tt},${uu}`
            case 2: return `${uu},${inv}`
            default: return `${inv},${uu}`
            }
        }
        const q = L * 0.25
        let d = `M ${P(0, base)} `
        d += `C ${P(q, base)} ${P(q, base + h)} ${P(L / 2, base + h)} `
        d += `C ${P(L - q, base + h)} ${P(L - q, base)} ${P(L, base)} `
        d += `L ${P(L, 0)} L ${P(0, 0)} Z`
        return d
    }

    // 十个涌浪包：五条边 × 两个波前。
    //
    // 两个波前是"往两边发射"的实现：出生点在面板贴的那条 rail 上、靠面板那一端，
    // 一个波前往里程增大的方向跑、一个往减小的方向跑。N 贴右 rail 底、将来 A 贴
    // 底 rail 中间，都靠这个天然分成两支——不需要为它们另写逻辑。
    //
    // 每段一个包而不是"一个包自己算在哪段"：包的几何朝向随段而变（顶栏两段朝
    // +y、左 rail 朝 +x、底 rail 朝 -y、右 rail 朝 -x），一个 item 换不了朝向，
    // 除非每帧重算路径——那又回到造垃圾的老路上。分开之后每个包的路径是**静态**
    // 的，每帧只动 x/y、taper 和 visible。
    //
    // 外层每段一个**裁剪框**，边界就是那条边在屏幕上的真实范围。涌浪包 420px
    // 长，靠 visible 判断只能拦住"中心跑出去"，拦不住包围盒探出去——而钟形剖面
    // 在包围盒两头还有实打实的墨。常驻起伏的 Strip 一直有 clip。
    Repeater {
        model: 5

        Item {
            id: seg

            required property int index

            readonly property bool vertical: index === 1 || index === 3
            // 顶栏两段的实心底是 0：顶栏自己那 44px 才是实心部分
            readonly property real base: (index === 0 || index === 4)
                ? 0 : root.railThickness
            readonly property real cross: base + root.pulseHeight
            readonly property real segLen: root.segLenOf(index)
            readonly property real segStart: root.segStartOf(index)
            // 厚度朝哪，见 bumpPath 的 kind
            readonly property int kind: {
                switch (seg.index) {
                case 1: return 1
                case 2: return 2
                case 3: return 3
                default: return 0
                }
            }

            clip: true
            visible: root.playing

            // 裁剪框 = 这条边在屏幕上的真实范围
            x: {
                switch (seg.index) {
                case 0: return root.railThickness
                case 1: return 0
                case 2: return root.railThickness
                case 3: return root.width - seg.cross
                default: return root.width - root.railThickness - seg.segLen
                }
            }
            y: seg.index === 2 ? root.height - seg.cross : root.barHeight
            width: seg.vertical ? seg.cross : seg.segLen
            height: seg.vertical ? seg.segLen : seg.cross

            Repeater {
                model: 2

                Item {
                    id: bump

                    required property int index
                    readonly property int dir: index === 0 ? 1 : -1

                    // 本波前的里程，包的中心落在它上面
                    readonly property real dist: root.origin + dir * root.spread
                    // 换算到本段内的局部里程
                    readonly property real u: dist - seg.segStart
                    readonly property real half: root.pulseLength / 2

                    // 跨拐角时相邻两段会同时可见——这是对的，波正在转弯，两条边
                    // 上各露半个包（各自被自己的裁剪框切在拐角处）。只让一段画
                    // 的话，波会在角上先消失再冒出来
                    visible: dist >= 0 && dist <= root.sEnd
                        && u > -half && u < seg.segLen + half

                    // 靠近路径两端（岛的豁口两侧）时收势，读成"波散进豁口里"。
                    //
                    // 压的是**厚度**，不是 opacity。两个理由：
                    // 1. waveColor 是不透明的 Color.background，半透明的深色带子
                    //    叠在壁纸/应用窗口上是个鬼影，不是"变薄"
                    // 2. opacity < 1 会让 Qt 有机会把这个 item 渲到离屏纹理再合成，
                    //    而纹理原点要对齐整数像素——正好是"一像素位移"的来源
                    // 振幅本身进的是静态路径，一动就得重算，所以用 Scale 变换：
                    // 原点钉在框的**外沿**，压下去时底边不动
                    readonly property real taper: {
                        const d = Math.min(bump.dist, root.sEnd - bump.dist)
                        return d >= root.endTaperPx
                            ? 1 : Math.max(0, d / root.endTaperPx)
                    }

                    transform: Scale {
                        // 厚度增长的起点不动：kind 0/1 从 0 侧长，2/3 从 cross 侧长
                        origin.x: seg.kind === 3 ? seg.cross : 0
                        origin.y: seg.kind === 2 ? seg.cross : 0
                        xScale: seg.vertical ? bump.taper : 1
                        yScale: seg.vertical ? 1 : bump.taper
                    }

                    width: seg.vertical ? seg.cross : root.pulseLength
                    height: seg.vertical ? root.pulseLength : seg.cross

                    // 坐标相对裁剪框。顶栏两段沿 -x 走（朝岛的豁口）、右 rail 沿
                    // -y 走（从底往上），这三段的局部坐标要翻过来。包是对称的，
                    // 只要把包围盒的中心摆对就行
                    x: {
                        switch (seg.index) {
                        case 0: return seg.segLen - bump.u - bump.half
                        case 2: return bump.u - bump.half
                        case 4: return seg.segLen - bump.u - bump.half
                        default: return 0
                        }
                    }
                    y: {
                        switch (seg.index) {
                        case 1: return bump.u - bump.half
                        case 3: return seg.segLen - bump.u - bump.half
                        default: return 0
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        asynchronous: false
                        ShapePath {
                            strokeWidth: 0
                            strokeColor: "transparent"
                            fillColor: root.waveColor
                            PathSvg {
                                // 静态：只依赖朝向和实心底，两者在本段里都是常量
                                path: root.bumpPath(seg.kind, seg.base)
                            }
                        }
                    }
                }
            }
        }
    }
}
