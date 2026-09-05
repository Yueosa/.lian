// RailContainer — 从 rail 派生的内容容器（进入模式的最小单元）
//
// present 驱动派生/收回；收回动画播完才卸载内容（Loader）。
// 派生方式 = 整卡滑入（不是宽度裁切揭示）：
//   宽度裁切会把圆角壳的圆角切成方边，且把内容切出方口（实测反馈）；
//   整卡滑入让圆角随身携带，屏幕边缘/rail 边缘就是天然裁切线
// edge 决定派生方向：
//   left  = 从 leftrail 向右滑入
//   right = 从 rightrail 向左滑入
//   bottom = 从 bottomrail 向上滑入
// 形状：贴 rail 侧直边，外侧两角圆角，贴 rail 侧上下各一颗凹耳。
// 位移取整：分数位移会让内容逐帧重采样（Tray 教训）。

import QtQuick
import qs.Components
import qs.data.state

Item {
    id: root

    property string edge: "left"
    property bool present: false
    // 内容自报空（hasContent=false）时收回并让出槽位，但内容仍留在内存里。
    //
    // 为什么不并进 present：present 还管着 Loader 的存活，而"空不空"是从
    // 已加载的内容上读出来的（bodyItem.hasContent）。合并就成了死循环——
    // 空 → 不派生 → Loader 卸载 → 读不到 hasContent → 按"未加载"当作有内容
    // → 又加载。实测症状是蓝牙关掉时列表卡全都赖着不走
    property bool shown: true

    // 上升沿防抖窗口：见 _shownEff
    property int shownRiseMs: 280
    property bool _shownEff: true

    // 占位防抖，只防上升沿，两个方向故意不对称：
    //   变空 → 立刻收。空卡不该占地方，而且开页那一拍内容刚建好就自报空时，
    //          必须当场压住，否则空卡会闪一下再退（蓝牙关着切到蓝牙页就是这样）
    //   变非空 → 等它稳住再出。数据可能只抖一帧——wifi 刷新列表时，同 SSID 的
    //          新 AP 对象会先以"未连接"出现，被归进"已保存"，把那张卡顶出来又
    //          收回去。一次进场+退场是 600ms 的动画，为一帧抖动付这个代价不值
    onShownChanged: {
        if (shown) {
            shownRise.restart()
        } else {
            shownRise.stop()
            _shownEff = false
        }
    }

    Timer {
        id: shownRise
        interval: root.shownRiseMs
        onTriggered: root._shownEff = root.shown
    }

    // 真正决定"该不该展开"的合成条件：页面要它，且它自己有话说
    readonly property bool wantOpen: present && _shownEff
    // 级联延迟：页面框架按容器序号注入，依次派生
    property int staggerMs: 0
    // 退场的级联延迟。默认跟进场一致，但页面框架会把它**反过来**注入：
    // 自顶向下排布的列里，退场必须自下而上。
    //
    // 理由是 Column 会跳过 visible=false 的子项：上面的容器一收完就从布局里消失，
    // 下面那些**还在收**的立刻被重新排到新位置，move 过渡把它们一路往上拽（还带
    // M3 过冲）。实测时间页 Esc：容器 0 的 progress 归零那一帧起，容器 1 从 y=450
    // 被拽到 -23.7，而它自己的 progress 还在 0.6——用户看到的「第一个容器退出后
    // 第二个瞬移/闪烁」就是这一下。
    //
    // 反过来之后先走的永远排在最后，它离场时前面的项一个都不用重排，回流从根上
    // 消失了。这和「槽位尺寸恒为自然尺寸」是同一个教训的两面：定位器会跳过的东西
    // 不止零尺寸，还有不可见
    property int exitStaggerMs: staggerMs
    // 显式尺寸；0 = 取内容 implicit 尺寸
    property int naturalWidth: 0
    property int naturalHeight: 0

    property alias sourceComponent: bodyLoader.sourceComponent
    // 页面框架用来给内容连信号（requestClose 等）
    property alias bodyItem: bodyLoader.item

    // 派生进度：0=收回 rail，1=完全展开
    property real progress: 0

    // 尺寸冻结：present 变 false 的瞬间捕获，退出动画期间不再跟内容变
    property int _frozenW: 0
    property int _frozenH: 0

    readonly property int innerW: naturalWidth > 0 ? naturalWidth
        : (wantOpen ? bodyLoader.implicitWidth : _frozenW)
    readonly property int innerH: naturalHeight > 0 ? naturalHeight
        : (wantOpen ? bodyLoader.implicitHeight : _frozenH)

    // ---- 底边堆叠（A 起用）----
    //
    // 左右边的容器是**沿边并排**的：生长方向垂直于排布方向，所以每个容器行程
    // 一样、谁也碰不到谁。底边不是——排布方向就是生长方向，容器沿**行程轴**
    // 摞起来，下面那格一张开，上面的容器就得被顶上去。
    //
    // A 要的正是这个：应用列表先贴着 rail 长出来，然后下面那格撑开把它顶起来
    // （「脱离」），搜索框再从 rail 里长进让出来的那条缝。
    //
    // 这看着跟下面「槽位恒为自然尺寸」那条老规矩打架，其实是同一条规矩的另一
    // 面。老规矩防的是**多个容器同时在动**时互相推挤（见 exitStaggerMs 那段的
    // 实测）。底边堆叠是严格顺序的三拍：上面那个先长完站定，下面那格才开；开的
    // 时候上面那个是静态的，被顶上去就是设计动作，不是回流事故。
    // 所以这条路显式开（slotGrows 默认 false），不让它悄悄生效。
    property bool slotGrows: false
    // 槽位里留给**本容器上方**那条缝的高度。缝跟槽位一起长，不能交给定位器的
    // spacing——spacing 是阶跃的：槽位从 0 长到 1px 那一帧，缝会整条插进来，
    // 上面的容器凭空跳一截（底边的 Column 因此 spacing: 0，见 RailPage）
    property int slotGapAbove: 0
    // 槽位比内容早开多久 = 「脱离」那一拍的起点
    property int slotStaggerMs: 0
    property real slotProgress: 0

    // 开：等错峰到点再张（三拍的第二拍）。收：跟内容一起缩回去——上面的容器
    // 落回 rail 和搜索框缩进 rail 是同一下，读起来是「抽屉把它吞回去」
    readonly property bool _slotWant: root.slotGrows && root.wantOpen && root.gate
        && bodyLoader.status === Loader.Ready

    on_SlotWantChanged: {
        if (_slotWant) {
            slotDelay.restart()
        } else {
            slotDelay.stop()
            slotProgress = 0
        }
    }

    Timer {
        id: slotDelay
        interval: root.slotStaggerMs
        onTriggered: root.slotProgress = 1
    }

    Behavior on slotProgress {
        Anim { type: root.wantOpen ? Anim.SpatialFast : Anim.Exit }
    }

    // 脱离度（0=底边还贴着 rail，1=已抬起）。由页面按「自己底边离列底多远」注入，
    // 不靠翻兄弟节点——那种写法在 Repeater 里既不可靠也不响应。
    // 抬起之后耳朵淡出、贴 rail 那侧的两个角圆起来：它不再贴着谁了
    property real detached: 0

    // 圆角：贴 rail 那侧直边，外侧圆角。底边容器脱离后那两个角跟着圆起来
    readonly property int radius: 16
    readonly property int _railSideR: root.edge === "bottom"
        ? Math.round(root.radius * root.detached) : 0

    // 左沿焊在左 rail 上（底边贴左段的页，Z/X）。
    //
    // 底 rail 上的卡片本来只跟下面那条 rail 贴合：下沿直边、下沿两侧各一只耳朵
    // 填接缝。挪到左段之后卡片的**左沿**也压在左 rail 的内沿上，于是
    //   · 左上角那个 16 的圆角悬在 rail 内沿边上，读成一个说不清的缺口
    //   · 底左那只耳朵（x=-14）整块落在左 rail 里，等于在 rail 上糊了一块背景色
    // 焊上之后：左侧两角改直边，底左耳撤掉，接缝改到**左上角**——那儿的形状和
    // C 那类左边页的上耳一模一样（卡在右、rail 在左、上方空着）
    property bool weldLeft: false
    readonly property int _weldR: root.weldLeft
        ? Math.round(root.radius * root.detached) : root.radius

    // 右沿焊在右 rail 上（底边贴右段的页，X）：上面那段的镜像
    property bool weldRight: false
    readonly property int _weldRR: root.weldRight
        ? Math.round(root.radius * root.detached) : root.radius

    // 槽位尺寸恒为自然尺寸，绝不跟 progress 变（底边堆叠除外，见上面 slotGrows）。
    // QQuickBasePositioner 把 width==0 或 height==0 的子项当「不可见」直接跳过，
    // 所以槽位一收到 0，Column 立刻把下面的容器全部上移打包——而它们自己的
    // 退场动画还没播完，就在错位置上收完，这就是「退场瞬移」。
    // 实测证据：容器 0 宽度归 0 的下一帧，容器 1 从 y=450 跳到 y=0，
    // 而它的 progress 还在 0.63。容器越多、被顶的越多，所以系统页最明显。
    // 生长一律交给里面的裁切框（right 边本来就是这么做的，现在 left/bottom 对齐）
    implicitWidth: innerW
    // 夹 0：收回那一拍 slotProgress 会冲到负的（-0.05，实测）。Behavior 的
    // 曲线类型绑在 wantOpen 上，而这里的赋值和 wantOpen 翻转在同一次求值里，
    // 动画可能还拿着带过冲的开场曲线起跑，1→0 的过冲就是负数。
    // progress 那条没这个毛病是因为它由 exitDelay 定时器隔了一拍才赋值
    implicitHeight: root.slotGrows
        ? Math.max(0, Math.round((root.displayH + root.slotGapAbove) * root.slotProgress))
        : root.displayH

    // 内容长高/变矮要滑，不要跳。
    //
    // 以前 Behavior 挂在 implicitHeight 上：Column 的槽位是在动，但底边卡片
    // 的可见壳是 clipFrame，高度写的是 innerH * progress——内容一变壳当场跳
    // 到新高度。用户说的「6 格瞬间变 1 格」就是这层，不是曲线没挂上。
    //
    // 所以真正插值的是 displayH（内容目标高度的缓动副本）。槽位、裁切框、
    // 完全打开后的内容视口都读它，三层同一个钟。派生/收回期间 Behavior
    // 关掉，displayH 跟 innerH 钉死，揭示还是 progress 的事。
    //
    // 曲线可由页面换（默认 spatial 带过冲）：高度**高频重定目标**的页要换成
    // 不过冲的一档。A 搜索每敲一个键列表就换一次高度，过冲会让它长过头再
    // 缩回来——多出来那 20 来 px 的行冒出来又被裁掉，读成「应用回弹得太猛」
    property int elasticType: Anim.SpatialFast
    property int displayH: innerH

    Behavior on displayH {
        enabled: root.wantOpen && root.progress >= 1
        Anim { type: root.elasticType }
    }

    // 内容必须同步加载。异步孵化过一版，会引入瞬移：孵化期间
    // bodyLoader.implicitHeight 是 0 → 容器高 0 → Column 把所有容器打包到
    // y=0，卡片陆续建好后高度到位、大家再一起下移。而实例化本来也不是
    // 卡顿源（A/B 实测：2 张轻卡的时间页和 5 张重卡的系统页停顿一样大），
    // 何况它现在落在起跑闸那一拍的动画前空档里，不花钱（见 RailPage 的 derivGate）

    // 错峰延迟是否已到（开闸的另一半条件）
    property bool _staggerDone: false

    onWantOpenChanged: {
        if (wantOpen) {
            _staggerDone = false
            enterDelay.restart()
        } else {
            enterDelay.stop()
            // 冻结此刻尺寸：必须直读 bodyLoader——innerH/W 的绑定此刻
            // 已切到 _frozen 分支，读它们只会冻到 0（退场瞬移的根因）
            _frozenW = bodyLoader.implicitWidth
            _frozenH = bodyLoader.implicitHeight
            // 回收也错峰：按 staggerMs 依次退场（出场已有级联）
            exitDelay.restart()
        }
    }

    // 派生开闸的第三个条件（由页面注入）：窗口已经拿到键盘焦点。
    // 申请焦点会让主线程停 ~190ms，等它落地再起动画，掉帧就变成了纯延迟
    property bool gate: true

    // 开闸条件：错峰到了 && 内容建好了 && 闸放开了。谁最后到谁触发
    function _tryDerive() {
        if (wantOpen && _staggerDone && gate && bodyLoader.status === Loader.Ready)
            progress = 1
    }

    onGateChanged: _tryDerive()

    Timer {
        id: enterDelay
        interval: root.staggerMs
        onTriggered: {
            root._staggerDone = true
            root._tryDerive()
        }
    }

    Timer {
        id: exitDelay
        interval: root.exitStaggerMs
        onTriggered: root.progress = 0
    }

    // 打开用 spatial 过冲（打开类别），收回用 accel 离场
    Behavior on progress {
        Anim { type: root.wantOpen ? Anim.Spatial : Anim.Exit }
    }

    // 裁切框：贴 rail 那一侧钉住，向外生长（left 向右 / right 向左 / bottom 向上）。
    // 取整防分数尺寸逐帧重采样（Tray 教训）
    Item {
        id: clipFrame
        clip: true
        x: 0
        y: 0
        width: root.edge === "bottom"
            ? root.width
            : Math.round(root.innerW * root.progress)
        height: root.edge === "bottom"
            ? Math.round(root.displayH * root.progress)
            : root.height
        anchors.right: root.edge === "right" ? parent.right : undefined
        anchors.bottom: root.edge === "bottom" ? parent.bottom : undefined

        // 生长体：尺寸跟随 progress，圆角每帧都在（壳随尺寸走）
        Item {
            id: slideBody
            // 生长体尺寸跟随裁切框（过冲也在内），
            // 果冻是"壳向外多弹一截再收回"，不是内容被推出 rail 裁掉
            width: root.edge === "bottom" ? root.width : clipFrame.width
            height: root.edge === "bottom" ? clipFrame.height : root.height
            x: 0
            y: 0

            // 背景：贴 rail 侧直边，外侧两角圆角（底边的下两角见 _railSideR）
            Rectangle {
                anchors.fill: parent
                color: Color.background
                topLeftRadius: root.edge === "left" ? 0 : root._weldR
                topRightRadius: root.edge === "right" ? 0 : root._weldRR
                bottomLeftRadius: root.edge === "left"
                    ? 0
                    : (root.edge === "bottom"
                        ? Math.min(root._railSideR, root._weldR) : root.radius)
                bottomRightRadius: root.edge === "right"
                    ? 0
                    : (root.edge === "bottom"
                        ? Math.min(root._railSideR, root._weldRR) : root.radius)
            }

            Loader {
                id: bodyLoader
                // 内容永远按自然尺寸布局，只被裁切框揭示：内容钉在贴 rail 那一侧，
                // 壳向外生长把它揭开；过冲期壳比内容宽一截，正是果冻的那一下。
                //
                // 关键：内容的 width/height 绝不能跟着 progress 变。之前 left 边
                // 写的是 width: parent.width，而 parent 宽度就是 innerW*progress，
                // 于是派生的每一帧都要整卡重排——文本重新折行、ListView 重算行、
                // Canvas 全量重绘（SysPsiCard 就有一个）。C 的系统页 5 个容器
                // 同时这么干，就是「容器弹出退出时卡顿」的主因。
                // right 边一直是钉住的，所以 V/N 从来没这个问题
                anchors.right: root.edge === "right" ? parent.right : undefined
                anchors.left: root.edge === "right" ? undefined : parent.left
                anchors.bottom: root.edge === "bottom" ? parent.bottom : undefined
                anchors.top: root.edge === "bottom" ? undefined : parent.top
                width: root.innerW
                // 打开之后视口跟 displayH 走：列表卡是 anchors.fill，视口一动
                // 行数就是在收/放，而不是壳在动、里面的格子已经跳完了。
                // 派生/收回仍钉 innerH，避免内容每帧跟着 progress 重排
                height: root.progress >= 1 ? root.displayH : root.innerH
                // 收回动画播完才卸载。看 present 不看 wantOpen：内容自报空时
                // 它必须继续活着，否则就读不到 hasContent 了（见 shown 的注释）
                active: root.present || root.progress > 0
                onStatusChanged: root._tryDerive()
            }
        }
    }

    // 贴 rail 侧上下衔接耳（接近到位才淡入：接缝只在贴合时存在）
    EarCanvas {
        visible: root.edge === "left"
        x: 0
        y: -14
        width: 14
        height: 14
        opacity: root.progress
        corner: EarCanvas.BottomRight
    }
    EarCanvas {
        visible: root.edge === "left"
        x: 0
        y: root.height
        width: 14
        height: 14
        opacity: root.progress
        corner: EarCanvas.TopRight
    }
    EarCanvas {
        visible: root.edge === "right"
        x: root.width - 14
        y: -14
        width: 14
        height: 14
        opacity: root.progress
        corner: EarCanvas.BottomLeft
    }
    EarCanvas {
        visible: root.edge === "right"
        x: root.width - 14
        y: root.height
        width: 14
        height: 14
        opacity: root.progress
        corner: EarCanvas.TopLeft
    }

    // 底边的两只耳朵贴在容器**底边两侧**（rail 在下方）。
    // 弧心放在离接缝最远那个角上，填的是对角月牙——左耳接缝在右下、弧心左上，
    // 所以是 BottomLeft；右耳镜像。
    // detached 抬起后淡出：耳朵是「接缝的填料」，接缝没了还留着就是两块悬空月牙
    EarCanvas {
        // 焊在左 rail 上时这只不画：它整块落在 rail 里（见 weldLeft）
        visible: root.edge === "bottom" && !root.weldLeft
        x: -14
        y: root.height - 14
        width: 14
        height: 14
        opacity: root.progress * (1 - root.detached)
        corner: EarCanvas.BottomLeft
    }

    // 焊在左 rail 上时的接缝：卡片上沿与左 rail 内沿的那个凹角。
    // 形状同左边页的上耳（卡在右、rail 在左、上方空着），所以弧心也在右上 →
    // BottomRight。跟着 progress 淡入：接缝只在贴合时存在
    EarCanvas {
        visible: root.edge === "bottom" && root.weldLeft
        x: 0
        y: -14
        width: 14
        height: 14
        opacity: root.progress * (1 - root.detached)
        corner: EarCanvas.BottomRight
    }
    EarCanvas {
        // 同理，焊在右 rail 上时这只整块落在 rail 里，不画
        visible: root.edge === "bottom" && !root.weldRight
        x: root.width
        y: root.height - 14
        width: 14
        height: 14
        opacity: root.progress * (1 - root.detached)
        corner: EarCanvas.BottomRight
    }

    // 焊在右 rail 上时的接缝（weldLeft 那只的镜像）：形状同右边页的上耳
    // ——卡在左、rail 在右、上方空着，所以弧心在左上 → BottomLeft
    EarCanvas {
        visible: root.edge === "bottom" && root.weldRight
        x: root.width - 14
        y: -14
        width: 14
        height: 14
        opacity: root.progress * (1 - root.detached)
        corner: EarCanvas.BottomLeft
    }
}
