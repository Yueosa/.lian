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

    // 槽位尺寸恒为自然尺寸，绝不跟 progress 变。
    // QQuickBasePositioner 把 width==0 或 height==0 的子项当「不可见」直接跳过，
    // 所以槽位一收到 0，Column 立刻把下面的容器全部上移打包——而它们自己的
    // 退场动画还没播完，就在错位置上收完，这就是「退场瞬移」。
    // 实测证据：容器 0 宽度归 0 的下一帧，容器 1 从 y=450 跳到 y=0，
    // 而它的 progress 还在 0.63。容器越多、被顶的越多，所以系统页最明显。
    // 生长一律交给里面的裁切框（right 边本来就是这么做的，现在 left/bottom 对齐）
    implicitWidth: innerW
    implicitHeight: innerH

    // 内容长高/变矮要滑，不要跳：扫到新 SSID、来了新更新包、发现新蓝牙设备时，
    // 卡片的 implicitHeight 会直接跳一截（列表卡是 contentHeight 算出来的），
    // 槽位跟着瞬变，Column 里下面的容器也一起瞬移。
    // 只在完全派生之后才动画——派生/收回期间槽位必须严格跟 progress 走，
    // 不然两套动画会打架。此时卡片本体已是新高度，由裁切框长出来揭开它
    Behavior on implicitHeight {
        enabled: root.wantOpen && root.progress >= 1
        Anim { type: Anim.SpatialFast }
    }

    // 内容必须同步加载。异步孵化过一版，会引入瞬移：孵化期间
    // bodyLoader.implicitHeight 是 0 → 容器高 0 → Column 把所有容器打包到
    // y=0，卡片陆续建好后高度到位、大家再一起下移。而实例化本来也不是
    // 卡顿源（A/B 实测：2 张轻卡的时间页和 5 张重卡的系统页停顿一样大），
    // 何况它现在落在 focusSettleMs 那一拍的动画前空档里，不花钱

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
        interval: root.staggerMs
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
            ? Math.round(root.innerH * root.progress)
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

            // 背景：贴 rail 侧直边，外侧两角圆角
            Rectangle {
                anchors.fill: parent
                color: Color.background
                topLeftRadius: root.edge === "left" ? 0 : 16
                topRightRadius: root.edge === "right" ? 0 : 16
                bottomLeftRadius: root.edge === "left" ? 0 : 16
                bottomRightRadius: root.edge === "right" ? 0 : 16
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
                height: root.innerH
                // 收回动画播完才卸载。看 present 不看 wantOpen：内容自报空时
                // 它必须继续活着，否则就读不到 hasContent 了（见 shown 的注释）
                active: root.present || root.progress > 0
                onStatusChanged: root._tryDerive()
            }
        }
    }

    // 贴 rail 侧上下衔接耳（接近到位才淡入：接缝只在贴合时存在）
    // TODO: bottom 方向的耳朵（迁移 A/Z/X 时补）
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
}
