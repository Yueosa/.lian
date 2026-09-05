// RailRipple — 框边的水波（plan 第 6 轮）
//
// 这个效果在合并之前做不了，不是因为效果本身难，而是因为 bar 和三条 rail 是
// 四个独立 Wayland surface：面板所在的窗没法往 rail 所在的窗里画一个像素，
// 想同步就得跨窗传状态，还要指望两个窗在同一帧提交。合并成一棵场景图之后，
// 波只是一个沿路径推进的数——所以这里没有任何跨窗机制，就是普通 QML。
//
// ============================================================
// 只有一层：一发一发的移动波
// ============================================================
// 有面板贴着某条 rail 开着时，那条 rail 每隔约 pulseEveryMs 放一发波，沿框的
// 内沿绕一趟；开、关面板各另放一发（弹出把水推开，缩回把水带回来）。一发出闸
// 就跟面板脱钩、跑完全程才消失——所以反复开关能攒出好几道波同时在框上跑，面板
// 关掉之后波还在路上。
//
// 波只朝框内鼓、绝不让 rail 变薄，理由见 pulseHeight。
//
// "不规律"是伪造的，靠三件事：
//  1. 每发的长短高矮在出闸那一刻各掷一次骰子，间隔也抖 ±40%
//  2. 长波跑得快（色散，见 wave.launch）——于是同一条 rail 放出的波会互相追上、
//     并成一个高峰再穿出去。同速的话它们是一列平行线，里程差恒定，永不相遇
//  3. 相遇时波峰**相加**（见 wave.boostA），不是各画各的谁高谁盖住
// 骰子只在出闸时掷、全程不变，所以每帧的开销跟随机无关。
//
// 曾经还有第二层「常驻起伏」：面板开着时整条内沿一直在波动，一串等长等高的
// 波瓣首尾相接。删了，因为**一串全等波瓣在几何上就是正弦**，一眼就读出周期
// （用户原话："很容易就能看出来是正弦"）。它当时还兼着一件事：给移动波垫一个
// 起伏的底子，免得一个孤零零的鼓包爬过一条笔直静止的边（那个观感用户报过，
// 见下面"路径"一节里顶栏的那段）。所以如果哪天嫌静止时的框太死，回来的方式是
// 给每个波瓣一个**按序号哈希的固定振幅**——波瓣接头处厚度恒为零，所以振幅各
// 不相同也看不出接缝——而不是恢复等幅波瓣。
//
// 全关且波跑完之后彻底停：Shape 不可见、动画 running 转假、一个像素都不画。
// 渲染循环是 n=basic（渲染同步在主线程），永久动画等于主线程永远不休息，所以
// "空闲真的静止"是硬要求，不是省一点的问题。
//
// ============================================================
// 为什么是「静态路径 + 只动变换」
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
// 所以每发波都烘成**静态**路径（Shape + PathSvg + CurveRenderer），每帧变的只有
// item 的 x/y 和一个 Scale——都走 C++ 动画/绑定，JS 一行都不跑。
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

    property color waveColor: Color.background

    // ---- 移动波 ----
    // 波峰高出框内沿多少。
    //
    // 「只朝内鼓、绝不变薄」这条踩过一次，记下来：一开始想的是"从 rail 那 8px
    // 里拿出 4px 来摆"，于是 rail 自己得缩到 4px 才能露出波谷。而框的**接缝全是
    // 按 8px 配的**——四颗凹角耳是 14×14、顶栏两段的下外角是 r=22，都照 8px 的
    // rail 对齐。rail 一缩，这些圆角当场露馅，那条波带也从"rail 在呼吸"变成
    // "rail 旁边多了一条会动的东西"（用户原话："彻底和 railbar 分离开…圆角也
    // 直接露馅了"）。所以实心底就是 rail 那 8px 本身，接缝一个都不动，波峰盖住
    // 应用窗口边缘几个像素——用户明确说没关系（开 railbar 时本来不看窗口），
    // Hyprland 那边还留着外边距。
    //
    // 高度、长度、间隔是一起调的，目标是**别读成"一记水波在跑"**：上一版是
    // 「高 12、长 420、每 6s 一发」，框上大部分时候静止，隔一会儿来一个明显的
    // 鼓包爬过去——那读起来就是一记水波，很土。现在反过来：矮、长（一记要跑
    // 一秒多才过完一个点，读成"这一段边在缓缓涨落"）、密（一发没跑完下一发就
    // 出闸，路上常年三四发）。看到的是好几发叠出来的总和在不规律起落
    property int pulseHeight: 6
    // 沿路径的基准长度。每一发在此基础上掷一次骰子（见 wave.launch）
    property int pulseLength: 900
    // 两发之间的基准间隔，也要掷骰子。远小于 durRipple（一趟 7000），所以路上
    // 常年有好几发；等间隔的波列会读成节拍器，所以间隔本身也得抖
    property int pulseEveryMs: 2200

    // ============================================================
    // 端点收势：压厚度之外还得压长度
    // ============================================================
    // 只压厚度是不够的，这一步算漏过一次。厚度倍率按包心离端点的距离取，而裁剪是
    // 硬切——倍率归零时包的身子已经跨过端点一半了。把漏出的厚度写成函数
    // （d = 包心离端点的距离，r = d / 收势区，profile 是鼓包剖面）：
    //
    //   漏出厚度 = h · r · (1-r)²(1+2r)      在 r ≈ 0.42 处取极大
    //
    // 按当年 12px 的峰值算是漏 12 × 0.52 ≈ 6px。每个包往豁口走的路上**必然**经过
    // 那个极大点，所以用户看到的是"波到达的时候一定会泄露几个像素"。
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

    // ---- 框内沿的累计里程 ----
    // 沿框的内边界走一圈（顺时针）：左段底边（岛的豁口 → 左上角）→ 左 rail
    // （自上而下）→ 底 rail（自左而右）→ 右 rail（自下而上）→ 右段底边
    // （右上角 → 岛的豁口）。两端收在岛的豁口两侧，那是框上唯一的开口。
    //
    // 顶栏进出过一次，教训值得记：第一版顶栏在路径里，但那时波峰有 12px，一个
    // 孤零零的高鼓包爬过顶栏那条笔直的下沿——用户截图逐列量出来鼓出 7~8px，读成
    // "水波超出 Rightbar 的范围"。于是把顶栏从路径里砍掉（只走三条 rail）；但砍
    // 掉之后波拍到上面两个拐角就摊平，框成了个开口的槽，更糟。
    // 现在顶栏还在路径里，靠的是**把波压矮**（6px 峰、单发 3~6px）而不是靠给
    // 顶栏垫一层起伏——那层起伏后来因为"看得出是正弦"删了，见文件头。
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
    // 周期行波的发射：一格波源槽位一个发射器
    // ============================================================
    // 发射器和 `Panels.railSlots` 的格子一一对应，各自看自己那格空不空。
    // 波源本来就该是多个：左边的 C 和右边的 V 不互斥、能同时开着；底 rail 上
    // A（中段）和 Z（左段）也不互斥。原先只有一个 origin，第二个面板开了只能
    // 把第一个的波顶掉；后来改成"一条边一格"，还是装不下同一条边上的两个。
    //
    // 为什么固定格数、而不是跟着开着的面板数增删：格子永不增删，发射器就
    // **永不重建**——跟着数组增删的话，开第二个面板会把第一个的发射器连带重建，
    // 它攒着的 lastOrigin（临别那一发要用）和定时器相位当场清零；更糟的是面板
    // 关掉时发射器直接销毁，临别那一发没人放。理由的另一半在 Panels.railSlots
    //
    // 波相遇时波峰**相加**，做法见 wave.boostA（不是并集——并集是"谁高谁盖住"，
    // 两道波穿过彼此时一点反应都没有，假）。
    //
    // 出生点离面板那一端的拐角多远，按那条 rail 长度的比例。
    // 原先的约束是「出生点离路径两端要大于涌浪的半长」，否则包在出生那一刻就跨
    // 在端点上被切掉一半。现在半长（450+）已经超过最紧的那个出生点（C 的
    // 434px），但不再是硬约束了：端点收势是连续的，跨端点出生只是"出闸时振幅
    // 略小于满值"（434/450 = 96%），不会有硬边。所以内缩量
    // 可以给 0.15——贴着面板那一端，出生那刻包就跨在拐角上，读成"从角上冒出来"
    property real originInset: 0.15

    // 波前离路径两端多少像素内开始收势——每一发按**它自己的半长**算（长度是
    // 掷出来的，见 wave.launch），所以这里只留个函数。
    // 为什么就该等于半长：包的前沿正好在中心离端点半长时触到边界，所以从那一刻
    // 起开始收，收到 0 时中心刚好抵达端点——全程没有满振幅的包被硬切。
    // 之前给固定 100 是错的：中心还有半长时前沿就越界被裁了，而收势 110px 之后
    // 才开始，于是顶栏下沿被切出一道硬边（用户看到的"像素偏移"）

    // 出生点在面板**自己那一端**，不是 rail 的中点。
    // 竖 rail 上里程的方向不一样：左 rail 从顶（s1）往下数，右 rail 从底（s3）
    // 往上数——所以同样是 valign "bottom"，左边取远端、右边取近端
    function originFor(edge, valign, anchor) {
        if (edge === "bottom") {
            // 底 rail 上不止一个面板，各占一段（A 中段、Z 左段），所以出生点得
            // 由面板自己报屏幕 x（见 Panels.railSlots 的 anchor）。夹进本段里：
            // 报进来的是卡片中线，卡片贴左时那条线可能落在左 rail 的厚度里
            if (anchor >= 0)
                return s2 + Math.max(0, Math.min(lenBottom, anchor - railThickness))
            return s2 + lenBottom / 2
        }

        const inset = lenVRail * originInset
        if (edge === "right")
            return valign === "top" ? s4 - inset : s3 + inset
        return valign === "bottom" ? s2 - inset : s1 + inset
    }

    // 一格槽位一个发射器。非可视，只存"我这一格放到哪了"。
    //
    // 数目固定（= Panels.railSlotCount），跟着**槽位**而不是跟着面板：面板一关，
    // 它那格变 null，发射器还在，才有人去放临别那一发。而且格子永不增删，
    // 别的发射器攒着的 lastOrigin / 定时器相位不会被牵连重建
    Repeater {
        id: emitters
        model: Panels.railSlotCount

        Item {
            id: emitter

            required property int index
            // 我这一格：{ id, edge, valign, anchor }，空着则为 null
            readonly property var src: Panels.railSlots[emitter.index]
            readonly property bool armed: root.keyOwner && !!emitter.src
            readonly property real origin: emitter.armed
                ? root.originFor(emitter.src.edge, emitter.src.valign,
                                 emitter.src.anchor) : 0

            // 放波的触发条件只认**波源本身**，不认几何。
            //
            // 这里踩过一次：本来写的是 onArmedChanged + onOriginChanged，结果开
            // C 时连放两发——armed 先置真（那一拍 origin 还是 0），几何算完
            // origin 才跳到 434。两发挨在同一毫秒里，看不出来，但同一个绑定还有
            // 个真隐患：origin 依赖顶栏两段的宽度，而段宽跟着内容变，于是**多
            // 一个托盘图标就会把在飞的波重启**。
            //
            // 改成认一个字符串签名：开/关面板、这格换了主人（同组换面板 V→N，
            // 或槽位被别的面板接手）都会让它变；几何漂移不会。
            // id 要进签名：底 rail 上 A 和 Z 的 edge/valign 一模一样，光凭那两个
            // 字段换了主人也看不出来
            readonly property string srcKey: emitter.armed
                ? (emitter.src.id + "/" + emitter.src.edge + "/"
                    + emitter.src.valign) : ""

            // 最后一次的出生点。关面板时 src 已经没了、origin 归零，得自己记着
            property real lastOrigin: 0

            // 开一发、关也一发：面板弹出是把水推开，缩回去是把水带回来，两下都该
            // 有反应。已经出闸的波不受影响——它归波池管，跑完全程为止，所以反复
            // 开关能攒出好几道波同时在框上跑。
            //
            // 启动时不会误放：srcKey 的初值和绑定结果都是空串，不产生变更信号
            onSrcKeyChanged: {
                if (emitter.srcKey !== "") {
                    emitter.lastOrigin = emitter.origin
                    root.fire(emitter.origin)
                } else {
                    root.fire(emitter.lastOrigin)
                }
            }

            // 开着的时候不停地放，间隔在基准值的 ±40% 里抖——固定间隔的波列
            // 会读成节拍器（每次触发重掷，所以这里是**赋值**、不是绑定）
            Timer {
                id: pulseTimer
                interval: root.pulseEveryMs * (0.6 + Math.random() * 0.8)
                repeat: true
                running: emitter.armed
                onTriggered: {
                    root.fire(emitter.origin)
                    pulseTimer.interval = root.pulseEveryMs * (0.6 + Math.random() * 0.8)
                }
            }
        }
    }

    // ============================================================
    // 波池：每一发都是独立的一发
    // ============================================================
    // 一发波出闸之后就跟发它的面板脱钩了，跑完全程才消失。于是反复开关面板可以
    // 攒出好几道波同时在框上跑（用户要的就是这个）。
    //
    // 固定 poolSize 个槽位，满了回收**最老**的那一发。不动态创建的理由是老的：
    // 一发波要 5 段 × 2 波前 = 10 个 Shape，临场同步创建正好砸在动画里
    // （见 plan.md 第 6 轮「同步创建撞上动画时钟」）。槽位空着时 visible 为假，
    // 一个像素都不画
    // 一趟 7000ms×色散系数（0.79~1.41，最慢的一发要 9.9s），平均每 2200ms 一发
    // → 一条 rail 常年 4~5 发在飞；左右两条同时开着就是 9~10 发，加上间隔抖动的
    // 尖峰，给 12 个槽位。
    //
    // 满了回收**最老**的那一发正好是最不显眼的：最老 = spread 最大 = 两个波前都
    // 最靠近路径两端 = 端点收势已经把它压到接近零，回收时基本看不见
    readonly property int poolSize: 12
    property int _seq: 0


    // 有没有波在飞。裁剪框和 Shape 的可见性要看它——面板全关之后常驻起伏会淡出，
    // 但那时可能还有波在路上，不能跟着一起藏掉。
    //
    // 写成累加而不是「见到一个就 return true」：短路会让绑定只依赖到第一个 alive，
    // 后面几个的变化收不到通知（QML 绑定的依赖是求值时**读到过**的那些）
    readonly property bool anyAlive: {
        let n = 0
        for (let i = 0; i < waves.count; i++) {
            const w = waves.itemAt(i)
            if (w && w.alive)
                n++
        }
        return n > 0
    }

    function fire(origin) {
        // 先找空位；全满就回收最老的那一发
        let slot = null
        let oldest = null
        for (let i = 0; i < waves.count; i++) {
            const w = waves.itemAt(i)
            if (!w)
                continue
            if (!w.alive) {
                slot = w
                break
            }
            if (!oldest || w.seq < oldest.seq)
                oldest = w
        }
        const target = slot || oldest
        if (target)
            target.launch(origin)
    }

    Repeater {
        id: waves
        model: root.poolSize

        Item {
            id: wave

            required property int index
            property real origin: 0
            // 波前离出生点的距离，0 → 跑完全程
            property real spread: 0
            property bool alive: false
            // 越大越新，回收时挑最小的
            property int seq: 0

            // 这一发的长短和高矮，出闸时掷一次，全程不变
            property real len: root.pulseLength
            property real amp: 1
            readonly property real half: wave.len / 2

            // ---- 出生收势 ----
            // spread=0 那一刻两个波前重合在波源上。振幅这时若已是满的，波峰就是
            // **凭空出现**的——用户报的正是这个：蔓延路上是平滑曲线，波源处却突然
            // 冒出一个峰。让振幅随波前离开波源的路程从 0 长起来，跑满半个波长
            // （鼓包这时正好完全离开波源）到顶，读起来是水面先在波源处鼓起、
            // 再劈成两道跑开。
            //
            // 用独立的 NumberAnimation 而不是 spread 的绑定：绑定要每帧算 JS，
            // 而 spread 是**匀速**的（anim.easing = Linear），时间正比于路程，
            // 所以一条按时间跑的斜坡和按路程算的完全等价，白拿一个零开销
            property real birth: 0
            // 画和叠加都用这个：掷出来的振幅乘上出生收势
            readonly property real ampNow: wave.amp * wave.birth

            NumberAnimation {
                id: birthAnim
                target: wave
                property: "birth"
                from: 0
                to: 1
                // 时长在出闸时按「半个波长要跑多久」改写（见 launch）
                duration: 200
                // 两头都零斜率：起手不磕、长满那一刻也不留折角
                easing.type: Easing.InOutSine
            }

            // 两个波前的里程：一个往里程增大的方向跑、一个往减小的方向跑
            readonly property real distA: wave.origin + wave.spread
            readonly property real distB: wave.origin - wave.spread

            // ---- 波峰叠加 ----
            // 两道波撞在一起时波峰要**相加**，不是各画各的然后谁高谁盖住（并集）。
            // 真正的求和要每帧重算路径形状，而这个文件的设计前提是「每帧只动变换、
            // 一行 JS 都不跑」（理由见文件头）。所以用一个等价的近似：
            //
            //   两个**等长**鼓包完全重合时，和就是「同一个鼓包、两倍高」。
            //   所以让每个波前按「别人在我这儿的高度之和」放大自己的振幅，重合处
            //   两个都放大到 2 倍、并集自然就是 2 倍高——峰值处和算术和完全一致，
            //   部分重叠时形状是近似的（真和会更胖一点）。
            //
            // 不算自己那条兄弟波前：同一发的两个波前在出闸那一刻是重合的，那时
            // 物理上只有**一道**波峰，算进去会变成出生就双倍高再劈开。
            //
            // 封顶 2 倍：十二道波叠在一处会是十二倍，而波峰是盖在应用窗口上的。
            // 封在两倍 = 「两道波相遇」这一个可读的情形，总厚度就封在
            // 8 + pulseHeight*2 = 24px，裁剪框正好按这个数开（见 seg.cross）。
            // 两道等幅波相遇时 16 → 24px，一半的增量，看得出来；三道以上才被
            // 封顶削掉，那种情形本来也读不出"三道"
            //
            // 注：波撞不撞得起来跟这里无关，取决于速度**是否有差**（见 launch
            // 里的色散）。同速的话同一条 rail 的波是一列平行线，永不相遇
            readonly property real boostA: root.boostAt(wave.index, wave.distA, wave.amp)
            readonly property real boostB: root.boostAt(wave.index, wave.distB, wave.amp)

            function launch(o) {
                wave.origin = o
                wave.seq = ++root._seq
                wave.alive = true

                // 每一发的长短高矮都掷一次骰子。等长等高等间隔的一列包读起来是
                // 节拍器（"伪不规律"就伪在这儿：随机只在出闸这一刻掷，全程不变，
                // 所以每帧的开销依然是零——不规律来自**很多发叠加**，不是来自
                // 让某一发自己抖）。
                //
                // amp 封在 1 以内：裁剪框的厚度是按 pulseHeight*boostCap 算的，
                // 掷出大于 1 的振幅会被那个框齐齐切平
                const lenMul = 0.5 + Math.random() * 1.1
                wave.len = root.pulseLength * lenMul
                wave.amp = 0.5 + Math.random() * 0.5

                // ---- 色散：长波跑得快 ----
                // 这一条是为了让波**撞得起来**，不是为了好看。
                //
                // 之前所有波同速，于是同一条 rail 放出的波是一列平行线：两个前沿
                // 的里程差恒等于「出闸时间差 × 速度」，永远不变，永远不相遇。
                // 一个发射器的波只可能跟**另一条 rail** 的波对撞（C 和 V 同时开
                // 着时在底 rail 上），只开一个面板就一次叠加都没有——用户说"总
                // 感觉没有叠加效果"，就是这个，不是封顶封掉了。
                //
                // 给每发一个自己的速度，快的就能追上慢的、并成一个高峰再穿出去。
                // 速度不是另掷一次骰子，而是从长度导出来的：深水波 v ∝ √λ，长的
                // 快。速度比约 1.8 倍（最长 vs 最短），一个 2.2s 的间隔（约 1700px）
                // 大概 4s 就追平，一趟之内能撞上好几回
                anim.duration = Size.anim.durRipple / Math.sqrt(lenMul)

                anim.stop()
                wave.spread = 0
                // 两头哪边路远按哪边算，保证两个波前都能跑到豁口
                anim.to = Math.max(o, root.sEnd - o) + wave.len
                anim.restart()

                // 出生收势的时长 = 跑半个波长要的时间（spread 匀速，按比例换算）
                birthAnim.stop()
                wave.birth = 0
                birthAnim.duration = Math.max(1,
                    Math.round(anim.duration * wave.half / anim.to))
                birthAnim.restart()
            }

            NumberAnimation {
                id: anim
                target: wave
                property: "spread"
                // 每发出闸时按自己的长度改写（色散，见 launch），所以这里只是个
                // 初值、不是绑定
                duration: Size.anim.durRipple
                // 单发**匀速**。曾经用减速曲线（"出闸快、远端收势，像真的在扩散"），但一趟
                // 拉长到 7s 之后，减速段慢得像卡住了；而且要看清波在各条边之间怎么
                // 交接，速度恒定才跟得住
                easing.type: Easing.Linear
                onFinished: wave.alive = false
            }
        }
    }

    // 一个波前的振幅倍率。
    //
    // 倍率 = (自己的振幅 + 别人的鼓包在我这个里程上的高度之和) / 自己的振幅，
    // 于是「振幅 × 倍率」正好等于**算术和**——峰值处和真求和一模一样。
    // 除以自己的 amp 不怕除零：amp 掷在 [0.5, 1]，除数有下界。
    //
    // skip 是自己那一发的槽位号（自己的两个波前都跳过，理由见 boostA 那段注释）
    readonly property real boostCap: 2
    function boostAt(skip, d, myAmp) {
        // 跑出路径的波前不画，也就不用算——一发波有一半时间里至少一个前沿在界外，
        // 这一行省掉的是每帧上百次 cos
        if (d < 0 || d > sEnd)
            return 1
        let sum = myAmp
        for (let i = 0; i < waves.count; i++) {
            if (i === skip)
                continue
            const w = waves.itemAt(i)
            if (!w || !w.alive)
                continue
            // 用 ampNow：刚出闸的波还没长起来，对别人的抬举也该按它此刻的高度算
            sum += w.ampNow * (humpAt(d - w.distA, w.half) + humpAt(d - w.distB, w.half))
        }
        return Math.min(root.boostCap, sum / myAmp)
    }

    // 归一化的鼓包剖面：偏移 0 时为 1，到半长处为 0。和 humpPath 画的是同一条
    // 曲线的高度（那条是 smoothstep 拼的，这条用 cos 近似——差别在肉眼之下，
    // 而它每帧要算上百次，便宜要紧）
    function humpAt(delta, half) {
        const a = Math.abs(delta)
        if (a >= half)
            return 0
        return 0.5 * (1 + Math.cos(Math.PI * a / half))
    }

    // ============================================================
    // 五段的里程 / 长度
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

    // ============================================================
    // 鼓包剖面
    // ============================================================
    // 两段三次贝塞尔拼一个 smoothstep：控制点与端点**同高**，于是 u=0、len/2、
    // len 三处的切线都是水平的——波和平直的框边之间因此没有折角，两头是"贴上去"
    // 的而不是"接上去"的。
    //
    // 形状是**对称**的，所以里程方向朝哪都能用同一条路径，不需要镜像。
    //
    // 实心底 base 别给 0。给 0 的话形状在包围盒两头掐成零厚度——两条相切的曲线在一点上收口，抗锯齿处理不了，就是一个尖点。
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
            // 裁剪框按**叠加封顶**开：两道波相遇时波峰是 base + pulseHeight*boostCap。
            // 按单发算的话，相遇那一下会被这个框齐齐切平，切出来是一道横着的硬边
            readonly property real cross: base + root.pulseHeight * root.boostCap
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
            // 路上没波就整段不画。面板关不关无所谓——一发出闸就跟面板脱钩了，
            // 认 anyAlive 才是对的
            visible: root.anyAlive

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

            // ---- 周期行波：波池 × 两个波前 ----
            // 出生点在面板贴的那条 rail 上、靠面板那一端，一个波前往里程增大的
            // 方向跑、一个往减小的方向跑。N 贴右 rail 底、将来 A 贴底 rail 中间，
            // 都靠这个天然分成两支——不需要为它们另写逻辑。
            //
            // 池里通常只有一两发在飞，其余 visible 为假，一个像素都不画
            Repeater {
                model: 2 * root.poolSize

                Item {
                    id: bump

                    required property int index
                    // 偶数号往里程增大的方向跑，奇数号往减小的方向
                    readonly property bool fwd: bump.index % 2 === 0
                    // 绑 waves.count 而不是直接 itemAt：itemAt 不是响应式的，
                    // 而 Repeater 建完子项那一刻只有 count 会发通知
                    readonly property var wave: waves.count > Math.floor(bump.index / 2)
                        ? waves.itemAt(Math.floor(bump.index / 2)) : null
                    readonly property real len: bump.wave ? bump.wave.len : 0

                    // 本波前的里程，包的中心落在它上面
                    readonly property real dist: bump.wave
                        ? (bump.fwd ? bump.wave.distA : bump.wave.distB) : -1
                    // 波峰叠加的振幅倍率，见 wave.boostA
                    readonly property real boost: bump.wave
                        ? (bump.fwd ? bump.wave.boostA : bump.wave.boostB) : 1
                    readonly property real u: dist - seg.segStart
                    readonly property real half: bump.len / 2

                    visible: !!bump.wave && bump.wave.alive
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
                    readonly property real taper: bump.edgeDist >= bump.half
                        ? 1 : Math.max(0, bump.edgeDist / bump.half)
                    readonly property real lenScale: root.lenScaleFor(bump.edgeDist, bump.len)
                    readonly property bool anchorAtLen:
                        root.nearHighOf(bump.dist) === seg.reversed
                    // 厚度轴的总倍率：端点收势 × 这一发此刻的振幅（含出生收势）
                    // × 波峰叠加
                    readonly property real thick:
                        bump.taper * (bump.wave ? bump.wave.ampNow : 1) * bump.boost

                    transform: Scale {
                        origin.x: seg.vertical
                            ? (seg.kind === 1 ? seg.base : seg.cross - seg.base)
                            : (bump.anchorAtLen ? bump.len : 0)
                        origin.y: seg.vertical
                            ? (bump.anchorAtLen ? bump.len : 0)
                            : (seg.kind === 0 ? seg.base : seg.cross - seg.base)
                        // 厚度轴上乘了 boost：Scale 的原点钉在**波谷那条线**（实心底
                        // 的外表面），所以放大只让波峰长高，谷线不动。实心底那一截
                        // 被一起放大到框外/栏里去了，本来就在裁剪框外，看不见
                        xScale: seg.vertical ? bump.thick : bump.lenScale
                        yScale: seg.vertical ? bump.lenScale : bump.thick
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
