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
//   常驻起伏（drift）  有面板开着时，框的整条内沿一直在波动。厚度在
//                      waveMin ~ waveMin+2*waveAmp 之间摆，波谷正好落在静止时
//                      的框内沿上——所以起伏只朝内鼓、绝不变薄，"框在呼吸"。
//   周期行波（pulse）  每 pulseEveryMs 放一发，从面板贴的那条边出发绕框跑一趟，
//                      峰值比起伏的波峰再高，所以能从起伏里认出来。开面板那一
//                      刻也放一发。
//
// 全关之后两层都停：Shape 不可见、动画 running 转假、一个像素都不画。渲染循环
// 是 n=basic（渲染同步在主线程），永久动画等于主线程永远不休息，所以"空闲真的
// 静止"是硬要求，不是省一点的问题。
//
// ============================================================
// 为什么两层都是"静态路径 + 只动变换"
// ============================================================
// 一眼看去最直接的做法是把整条 rail 切成几百个小矩形、每片厚度按 sin 取值，
// 每帧推进相位。别这么干：那是每帧上千次 JS 绑定求值 + 上千个临时对象，而渲染
// 循环是 n=basic——渲染和 JS 抢的是**同一条主线程**，每帧的 JS 直接从 16ms 的
// 帧预算里扣。给一个装饰动画付这笔钱是本末倒置。
// （这段注释以前把理由写成「GC 停顿是本壳最大卡顿源」，那个结论已经推翻：真凶
// 是 TrayMenu 那份关着也不解除的 dbusmenu 订阅，自然 GC 实测只要 1~5ms。
// 但「别每帧跑 JS」这条建议本身仍然成立，只是理由换成上面那个。）
//
// 切片法还栽过一次形状上的跟头：涌浪起初切 12 片薄矩形，峰值只有 3px 时没问题
// （12 档档间差 0.25px 是亚像素），峰值提到 12px 之后档间差变成 4px、配 35px 宽
// 的片子，就是**一排肉眼可见的矩形台阶**（用户原话："一堆矩形条"）。教训：切片
// 法的档距是"峰值/片数"，改峰值就得同步改片数，这种耦合不如直接画曲线。
//
// 所以两层都烘成**静态**路径（Shape + PathSvg + CurveRenderer），每帧变的只有
// item 的 x/y 和一个 Scale——都走 C++ 动画/绑定，JS 一行都不跑。
//
// ============================================================
// 起伏为什么拆成一串波瓣，而不是一条长路径
// ============================================================
// 第一版起伏是"一条烘死的长正弦路径 + 每帧只平移 x/y"，比现在省 item。它被换掉
// 是因为**框有两个自由端**（岛的豁口两侧），而那个结构没法在端点收势：
//
//   包络要在屏幕上静止，路径却在动。一条静态路径加平移，做不出静止的包络。
//
// 于是端点只能靠 clip 硬切，切口高度随漂移在 0~8px 之间来回——波峰漂到端点就是
// 一道 8px 的垂直台阶。用户逐次截图报的"右上角很尖锐的锯齿""RightBar 最左边、
// LeftBar 最右边"，都是这一处；拐角反而一直稳，因为相邻两段相位连续。
//
// 换法的支点是：那条正弦本来就是**一串一模一样的波瓣**——`base + amp(1-cos)`
// 在每个波长的两端都正好等于 base。所以拆成独立的波瓣 item 之后：
//
//   相邻波瓣的接头处厚度偏移恒为零 → 每个波瓣可以有**自己的振幅倍率**而看不出
//   接缝。包络成了按波瓣量化的阶梯，却是隐形的。
//
// 附带两个好处：
//  1. 波瓣按**全局里程**索引（第 k 个波瓣的起点 = k*waveLength + drift），四个
//     拐角自动连续。上一版要靠一个 mirrored 开关把局部坐标镜像过来才能对齐相位
//     （只反转位移的话相位是反射的，波峰会在角上对撞），那套算术整个删掉了。
//  2. 振幅从路径里挪进 Scale，路径成了**永久**静态——连开合渐进那十几帧都不用
//     重算，`ampNow` 只是缩放系数。
//
// 代价是 item 数从 5 涨到 ~33。都是十来个三角形的静态 Shape，每帧只更新变换，
// 换来的是端点能收势。
//
// ============================================================
// 路径
// ============================================================
// 框不是闭环：顶边中间是空的（左段、岛、右段之间有豁口）。所以路径是一条开口的
// 线，两端就是两个豁口，波跑到那儿收势散掉：
//
//   左段底边(由内向外) → 左 rail(上→下) → 底 rail(左→右)
//                       → 右 rail(下→上) → 右段底边(由内向外)

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

    // 只有主屏那份画波（面板只在主屏）
    required property bool keyOwner

    // 贴边 rail 上有面板开着才动。**岛不算**——它是独立体系，理由见 Panels.railHeld
    readonly property bool active: Panels.railHeld && keyOwner

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

    readonly property int maxThick: waveMin + 2 * waveAmp

    // 起伏的幅度是渐进的：面板开合那一下让它长出来/收回去，别啪一下出现。
    // 这条现在只进 Scale，不进路径——路径是永久静态的
    property real ampNow: 0
    Behavior on ampNow {
        Anim { type: Anim.Spatial }
    }
    onActiveChanged: ampNow = active ? waveAmp : 0

    // 波瓣沿里程方向的整体位移，0 → 一个波长就回零。第 k 个波瓣的起点里程是
    // k*waveLength + drift，所以位移走满一个波长时第 k 个正好接上第 k-1 个原来
    // 的位置——波瓣彼此全等，接缝处像素级重合，看不出跳
    property real drift: 0
    NumberAnimation on drift {
        running: root.ampNow > 0.01
        loops: Animation.Infinite
        from: 0
        to: root.waveLength
        duration: root.driftMs
        // 匀速：水面起伏没有加减速，用 easing 反而像在抽
        easing.type: Easing.Linear
    }

    // 起伏在路径两端多少像素内收势。
    // 给一个波长：顶栏段的行程约 362px，于是段上还留得下一个满振幅的波瓣，靠豁口
    // 那一两个逐级压平——读成"水往豁口那头平息下去"。给两个波长的话整条顶栏段都
    // 在收势区里，顶栏就几乎不起伏了，那等于把顶栏又摘出去
    readonly property real ambientTaperPx: waveLength

    // ============================================================
    // 端点收势：压厚度之外还得压长度
    // ============================================================
    // 只压厚度是不够的，这一步算漏过一次。厚度倍率按包心离端点的距离取，而裁剪是
    // 硬切——倍率归零时包的身子已经跨过端点一半了。把漏出的厚度写成函数
    // （d = 包心离端点的距离，r = d / 收势区，profile 是鼓包剖面）：
    //
    //   漏出厚度 = h · r · (1-r)²(1+2r)      在 r ≈ 0.42 处取极大
    //
    // 起伏漏 8 × 0.259 ≈ 2px，行波漏 12 × 0.52 ≈ 6px。每个包往豁口走的路上**必然**
    // 经过那个峰，所以用户看到的是"波到达的时候一定会泄露几个像素"。
    //
    // 所以再压长度：让包的前沿永远够不到端点。锚点钉在包**远离端点**的那一头，
    // 于是和相邻波瓣的接头不动——钉中心的话接头会往里缩，端点附近裂出一段平的。
    //   d ≥ len/2 时不压（包本来就在里面）
    //   d < len/2 时压到 0.5 + d/len，前沿正好落在端点上
    // 再往里让 1px：形状边缘正好压在裁剪线上时，抗锯齿还会糊出一条亚像素
    function lenScaleFor(d, len) {
        return Math.max(0, Math.min(1, 0.5 + (d - 1) / len))
    }

    function edgeDistOf(c) {
        return Math.min(c, sEnd - c)
    }

    // 近的那一端是里程的大头还是小头。包要朝**反方向**压，所以要知道是哪一端
    function nearHighOf(c) {
        return (sEnd - c) < c
    }

    // ---- 行波 ----
    // 涌浪高出框内沿多少。要明显高过起伏的波峰（maxThick=16）才能从起伏里认出来，
    // 所以给 12 → 框上总厚 20
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
    // 周期行波的发射：一条 rail 一个发射器
    // ============================================================
    // 三条贴边 rail 各摆一个发射器（左/右/底），各自看 Panels.railSources 里
    // 自己那一格。左组的 C 和右组的 V 本来就不互斥、能同时开着，所以波源本来
    // 就该是多个——原先只有一个 origin，第二个面板开了只能把第一个的波顶掉。
    //
    // 为什么是**固定三个**、而不是跟着 railSources 的条目数增删：一个组同时
    // 只可能有一个面板（那正是 Panels 上半部分在做的事），而一个组正好对应
    // 一条 rail。固定三个的好处是发射器**永不重建**——跟着数组增删的话，开
    // 第二个面板会把第一个的发射器连带重建，它在飞的那一发波当场消失。
    //
    // 波相遇：两个鼓包重叠时是**并集**（同色不透明，谁高谁盖住），不是算术
    // 求和。求和要每帧重算路径形状，而这个文件的整个设计前提是「每帧只动变换、
    // 一行 JS 都不跑」（理由见文件头）。并集读起来也是两道波峰并成一道，而且
    // 总厚度还是封顶在 20px——求和会叠到 32px，那已经吃掉应用窗口一大条了。
    //
    // 出生点离面板那一端的拐角多远，按那条 rail 长度的比例。
    // 约束是**出生点离路径两端要大于涌浪的半长**（210px），否则包在出生那一刻
    // 就跨在端点上、被裁剪框切掉一半。顶栏并进来之后路径的两端在**岛的豁口**，
    // 离三条 rail 都远，这条约束自动满足了（最紧的是 C 的 434px），所以内缩量
    // 可以给 0.15——贴着面板那一端，出生那刻包就跨在拐角上，读成"从角上冒出来"
    property real originInset: 0.15

    // 波前离路径两端多少像素内开始收势。
    // 这个值就该等于**半长**：包的前沿正好在中心离端点半长时触到边界，所以从那
    // 一刻起开始收，收到 0 时中心刚好抵达端点——全程没有满振幅的包被硬切。
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

    // 三个发射器。非可视，只存"这条 rail 的波跑到哪了"
    Repeater {
        id: emitters
        model: ["left", "right", "bottom"]

        Item {
            id: emitter

            required property string modelData
            // 本组当前开着的面板贴在哪条边、哪一头；没开则为 undefined
            readonly property var src: Panels.railSources[emitter.modelData]
            readonly property bool armed: root.keyOwner && !!emitter.src
            readonly property real origin: emitter.armed
                ? root.originFor(emitter.src.edge, emitter.src.valign) : 0

            // 波前离出生点的距离，0 → 跑完全程
            property real spread: 0
            property bool playing: false

            // 放波的触发条件只认**波源本身**，不认几何。
            //
            // 这里踩过一次：本来写的是 onArmedChanged + onOriginChanged，结果开
            // C 时连放两发——armed 先置真（那一拍 origin 还是 0），几何算完
            // origin 才跳到 434。两发挨在同一毫秒里，看不出来，但同一个绑定还有
            // 个真隐患：origin 依赖顶栏两段的宽度，而段宽跟着内容变，于是**多
            // 一个托盘图标就会把在飞的波重启**。
            //
            // 改成认一个字符串签名：开/关面板、同组换面板（右组 V→N，valign 从
            // top 变 bottom）都会让它变；几何漂移不会。在飞的波则跟着几何平移，
            // 这是对的——框变形了，水槽也就变形了
            readonly property string srcKey: emitter.armed
                ? (emitter.src.edge + "/" + emitter.src.valign) : ""
            // 面板关了立刻停：波留在半路上不动更难看
            onSrcKeyChanged: emitter.srcKey === "" ? emitter.stop() : emitter.fire()

            function fire() {
                // 两头哪边路远按哪边算，保证两个波前都能跑到豁口
                const reach = Math.max(emitter.origin, root.sEnd - emitter.origin)
                    + root.pulseLength
                spreadAnim.stop()
                emitter.spread = 0
                emitter.playing = true
                spreadAnim.to = reach
                spreadAnim.restart()
                pulseTimer.restart()
            }

            function stop() {
                spreadAnim.stop()
                emitter.playing = false
            }

            // 面板关了就别再发；开着的时候每 pulseEveryMs 来一发
            Timer {
                id: pulseTimer
                interval: root.pulseEveryMs
                repeat: true
                running: emitter.armed
                onTriggered: emitter.fire()
            }

            NumberAnimation {
                id: spreadAnim
                target: emitter
                property: "spread"
                duration: Size.anim.durRipple
                // 匀速。曾经用减速曲线（"出闸快、远端收势，像真的在扩散"），但一趟
                // 拉长到 7s 之后，减速段慢得像卡住了；而且要看清波在各条边之间怎么
                // 交接，速度恒定才跟得住
                easing.type: Easing.Linear
                onFinished: emitter.playing = false
            }
        }
    }

    // ============================================================
    // 五段的里程 / 长度 / 波瓣编号
    // ============================================================
    // 写成 switch 函数而不是数组常量：绑定里每帧 new 一个数组就是每帧造垃圾，
    // 而渲染循环是 n=basic，JS 和渲染抢同一条主线程
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

    // 本段要摆几个波瓣、从第几号起。
    //
    // 波瓣按**全局**里程编号（第 k 个占 [k*wl+drift, (k+1)*wl+drift]），所以每段
    // 只需要覆盖自己里程区间的那几号。drift ∈ [0, wl)，把两头各多给一个就够：
    // 需要的 k 落在 (segStart/wl - 2, (segStart+segLen)/wl) 内，而 k0 起、
    // 数 ceil(segLen/wl)+2 个正好把这个开区间的整数全包住（两边各验过一遍）。
    // 跨拐角的波瓣会在相邻两段各画一次、各被自己的裁剪框切在角上——这是对的，
    // 波正在转弯；只让一段画的话，波会在角上先消失再冒出来
    function lobeK0Of(i) {
        return Math.floor(segStartOf(i) / waveLength) - 1
    }

    function lobeCountOf(i) {
        return Math.ceil(segLenOf(i) / waveLength) + 2
    }

    // ============================================================
    // 鼓包剖面：起伏的波瓣和涌浪共用一个
    // ============================================================
    // 两段三次贝塞尔拼一个 smoothstep：控制点与端点**同高**，于是 u=0、len/2、
    // len 三处的切线都是水平的。这一条同时管住两件事——涌浪与平直框边之间没有
    // 折角，以及相邻波瓣在接头处是 C1 连续的（两边都是水平切线接在同一高度）。
    //
    // 形状是**对称**的，所以里程方向朝哪都能用同一条路径，不需要镜像。
    //
    // 实心底 base 别给 0。给 0 的话形状在两端（起伏是每个波谷、涌浪是包围盒两头）
    // 掐成零厚度——两条相切的曲线在一点上收口，抗锯齿处理不了，就是一个尖点。
    // 顶栏那两段本来给的是 0（想着"顶栏自己那 44px 才是实心部分"），结果下沿每
    // 220px 冒一个锯齿；改成和 rail 一样给 8、裁剪框往栏里挪 8px，可见边界一模
    // 一样，藏进栏里那 8px 由顶栏自己盖住
    //
    // kind: 0 = 厚度朝 +y（顶栏两段的底边）  1 = 朝 +x（左 rail）
    //       2 = 朝 -y（底 rail）             3 = 朝 -x（右 rail）
    function humpPath(kind, base, cross, len, h) {
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
        const q = len * 0.25
        let d = `M ${P(0, base)} `
        d += `C ${P(q, base)} ${P(q, base + h)} ${P(len / 2, base + h)} `
        d += `C ${P(len - q, base + h)} ${P(len - q, base)} ${P(len, base)} `
        d += `L ${P(len, 0)} L ${P(0, 0)} Z`
        return d
    }

    // ============================================================
    // 五个裁剪框，每个装一串起伏波瓣 + 两个涌浪波前
    // ============================================================
    // 每段一个裁剪框，边界就是那条边在屏幕上的真实范围。靠 visible 判断只能拦住
    // "中心跑出去"，拦不住包围盒探出去——而鼓包剖面在包围盒两头还有实打实的墨。
    //
    // 每段一套 item 而不是"一个 item 自己算在哪段"：鼓包的几何朝向随段而变（顶栏
    // 两段朝 +y、左 rail 朝 +x、底 rail 朝 -y、右 rail 朝 -x），一个 item 换不了
    // 朝向，除非每帧重算路径——那又回到造垃圾的老路上
    Repeater {
        model: 5

        Item {
            id: seg

            required property int index

            readonly property bool vertical: index === 1 || index === 3
            // 里程随本段局部坐标**递减**的三段：顶栏两段朝豁口、右 rail 自下而上
            readonly property bool reversed: index === 0 || index === 3 || index === 4
            readonly property real base: root.railThickness
            // 裁剪框要同时容下起伏的波峰（maxThick）和涌浪的峰值（base+pulseHeight）
            readonly property real cross: Math.max(root.maxThick, base + root.pulseHeight)
            readonly property real segLen: root.segLenOf(index)
            readonly property real segStart: root.segStartOf(index)
            // 厚度朝哪，见 humpPath 的 kind
            readonly property int kind: {
                switch (seg.index) {
                case 1: return 1
                case 2: return 2
                case 3: return 3
                default: return 0
                }
            }

            // 局部里程 → 本段局部坐标。鼓包都是对称的，摆对包围盒的中心就行
            function place(u, len) {
                return seg.reversed ? seg.segLen - u - len : u
            }

            clip: true
            // 起伏的幅度大于零就等于「有面板开着」，而行波只在有面板开着时存在
            // （发射器 disarm 会立刻停波），所以这一个条件就够，不用再聚合六个
            // 发射器的 playing
            visible: root.ampNow > 0.01

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
            y: {
                switch (seg.index) {
                case 2: return root.height - seg.cross
                // 顶栏两段：往栏里挪 8px，藏起来的那截由顶栏自己盖住
                case 1:
                case 3: return root.barHeight
                default: return root.barHeight - root.railThickness
                }
            }
            width: seg.vertical ? seg.cross : seg.segLen
            height: seg.vertical ? seg.segLen : seg.cross

            // ---- 常驻起伏：一串波瓣 ----
            Repeater {
                model: root.lobeCountOf(seg.index)

                Item {
                    id: lobe

                    required property int index
                    readonly property int k: root.lobeK0Of(seg.index) + index
                    readonly property real len: root.waveLength
                    // 本波瓣起点的全局里程，以及换算到本段内的局部里程
                    readonly property real m0: lobe.k * lobe.len + root.drift
                    readonly property real u0: lobe.m0 - seg.segStart

                    visible: root.ampNow > 0.01
                        && lobe.u0 < seg.segLen && lobe.u0 + lobe.len > 0

                    width: seg.vertical ? seg.cross : lobe.len
                    height: seg.vertical ? lobe.len : seg.cross
                    x: seg.vertical ? 0 : seg.place(lobe.u0, lobe.len)
                    y: seg.vertical ? seg.place(lobe.u0, lobe.len) : 0

                    // 包络：靠近路径两端（岛的豁口两侧）时按波瓣压幅度。
                    // 按**波瓣中心**取距离，所以包络是按波长量化的阶梯——但相邻
                    // 波瓣在接头处厚度偏移恒为零，阶梯是隐形的。这正是拆成波瓣的
                    // 全部理由，见文件头
                    readonly property real center: lobe.m0 + lobe.len / 2
                    readonly property real edgeDist: root.edgeDistOf(lobe.center)
                    readonly property real taper: lobe.edgeDist >= root.ambientTaperPx
                        ? 1 : Math.max(0, lobe.edgeDist / root.ambientTaperPx)
                    // 开合的渐进也走这里，于是路径永久静态
                    readonly property real amp: lobe.taper * root.ampNow / root.waveAmp
                    // 压长度那一半的收势，见 root.lenScaleFor
                    readonly property real lenScale: root.lenScaleFor(lobe.edgeDist, lobe.len)
                    readonly property bool anchorAtLen:
                        root.nearHighOf(lobe.center) === seg.reversed

                    // 一个 Scale 管两件事：厚度轴的原点钉在**波谷那条线**（实心底
                    // 的外表面），压下去时谷线不动；长度轴的原点钉在远离端点的那一
                    // 头。两根轴互不相干，所以一个变换就够
                    transform: Scale {
                        origin.x: seg.vertical
                            ? (seg.kind === 1 ? seg.base : seg.cross - seg.base)
                            : (lobe.anchorAtLen ? lobe.len : 0)
                        origin.y: seg.vertical
                            ? (lobe.anchorAtLen ? lobe.len : 0)
                            : (seg.kind === 0 ? seg.base : seg.cross - seg.base)
                        xScale: seg.vertical ? lobe.amp : lobe.lenScale
                        yScale: seg.vertical ? lobe.lenScale : lobe.amp
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
                                // 永久静态：只依赖朝向和几何常量
                                path: root.humpPath(seg.kind, seg.base, seg.cross,
                                                    lobe.len, 2 * root.waveAmp)
                            }
                        }
                    }
                }
            }

            // ---- 周期行波：三个发射器 × 两个波前 ----
            // 出生点在面板贴的那条 rail 上、靠面板那一端，一个波前往里程增大的
            // 方向跑、一个往减小的方向跑。N 贴右 rail 底、将来 A 贴底 rail 中间，
            // 都靠这个天然分成两支——不需要为它们另写逻辑。
            //
            // 六个里通常只有两个在画（一条 rail 开着面板），其余 visible 为假，
            // 一个像素都不画。两条 rail 同时开着时两列波各跑各的，重叠处取并集
            Repeater {
                model: 6

                Item {
                    id: bump

                    required property int index
                    // 偶数号往里程增大的方向跑，奇数号往减小的方向
                    readonly property int dir: (bump.index % 2 === 0) ? 1 : -1
                    // 绑 emitters.count 而不是直接 itemAt：itemAt 不是响应式的，
                    // 而 Repeater 建完子项那一刻只有 count 会发通知
                    readonly property var emitter: emitters.count > Math.floor(bump.index / 2)
                        ? emitters.itemAt(Math.floor(bump.index / 2)) : null
                    readonly property real len: root.pulseLength

                    // 本波前的里程，包的中心落在它上面
                    readonly property real dist: bump.emitter
                        ? bump.emitter.origin + bump.dir * bump.emitter.spread : -1
                    readonly property real u: dist - seg.segStart
                    readonly property real half: bump.len / 2

                    visible: !!bump.emitter && bump.emitter.playing
                        && dist >= 0 && dist <= root.sEnd
                        && u > -half && u < seg.segLen + half

                    width: seg.vertical ? seg.cross : bump.len
                    height: seg.vertical ? bump.len : seg.cross
                    x: seg.vertical ? 0 : seg.place(bump.u - bump.half, bump.len)
                    y: seg.vertical ? seg.place(bump.u - bump.half, bump.len) : 0

                    // 靠近路径两端时收势，读成"波散进豁口里"。
                    //
                    // 压的是**几何**，不是 opacity。两个理由：
                    // 1. waveColor 是不透明的 Color.background，半透明的深色带子
                    //    叠在壁纸/应用窗口上是个鬼影，不是"变薄"
                    // 2. opacity < 1 会让 Qt 有机会把这个 item 渲到离屏纹理再合成，
                    //    而纹理原点要对齐整数像素——正好是"一像素位移"的来源
                    readonly property real edgeDist: root.edgeDistOf(bump.dist)
                    readonly property real taper: bump.edgeDist >= root.endTaperPx
                        ? 1 : Math.max(0, bump.edgeDist / root.endTaperPx)
                    readonly property real lenScale: root.lenScaleFor(bump.edgeDist, bump.len)
                    readonly property bool anchorAtLen:
                        root.nearHighOf(bump.dist) === seg.reversed

                    transform: Scale {
                        origin.x: seg.vertical
                            ? (seg.kind === 1 ? seg.base : seg.cross - seg.base)
                            : (bump.anchorAtLen ? bump.len : 0)
                        origin.y: seg.vertical
                            ? (bump.anchorAtLen ? bump.len : 0)
                            : (seg.kind === 0 ? seg.base : seg.cross - seg.base)
                        xScale: seg.vertical ? bump.taper : bump.lenScale
                        yScale: seg.vertical ? bump.lenScale : bump.taper
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
                                path: root.humpPath(seg.kind, seg.base, seg.cross,
                                                    bump.len, root.pulseHeight)
                            }
                        }
                    }
                }
            }
        }
    }
}
