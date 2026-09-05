// WallpaperPage — 卷轴浏览，本页自管顺序
// ← → 只移焦点；Enter / 再点焦点才 set。上一张下一张按本页列表 set，
// 不走 lianwall next/prev（那会刷新 space 把顺序打乱）。
// 第一次按文件名排好，之后只按 path 增删改元数据。
//
// 高度预算（wallpaperHeight 324，减 margins 20 = 304 可用）：
//   顶栏 42 + 间距 8 + 卷轴区 254，焦点卡 ~300×198 上下各留 28

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Components
import qs.data.state
import qs.data.service

FocusScope {
    id: root

    property int focusIndex: 0
    property var reel: []

    readonly property var focusedItem: {
        if (focusIndex < 0 || focusIndex >= reel.length)
            return null
        return reel[focusIndex]
    }

    Component.onCompleted: {
        Lianwall.setDetailActive(true)
        forceActiveFocus()
    }
    Component.onDestruction: Lianwall.setDetailActive(false)

    function clampFocus() {
        if (reel.length <= 0) {
            focusIndex = 0
            return
        }
        focusIndex = Math.max(0, Math.min(reel.length - 1, focusIndex))
    }

    function appliedIndex() {
        for (let i = 0; i < reel.length; i++) {
            if (reel[i] && reel[i].is_current)
                return i
        }
        return focusIndex
    }

    function applyDelta(delta) {
        if (reel.length <= 0)
            return
        const i = (appliedIndex() + delta + reel.length) % reel.length
        const it = reel[i]
        if (it && it.path)
            Lianwall.setWallpaper(it.path)
        let steps = i - focusIndex
        const n = reel.length
        if (steps > n / 2)
            steps -= n
        if (steps < -n / 2)
            steps += n
        if (steps !== 0)
            moveFocus(steps)
        punchScale = 1
        punchAnim.restart()
    }

    function snapFocusToCurrent() {
        const i = appliedIndex()
        if (i >= 0)
            focusIndex = i
        clampFocus()
    }

    function syncReel() {
        const incoming = Lianwall.items || []
        if (incoming.length === 0) {
            if (!Lianwall.loading)
                reel = []
            return
        }

        const byPath = {}
        for (let i = 0; i < incoming.length; i++) {
            const it = incoming[i]
            if (it && it.path)
                byPath[it.path] = it
        }

        let overlap = false
        for (let i = 0; i < reel.length; i++) {
            if (reel[i] && byPath[reel[i].path]) {
                overlap = true
                break
            }
        }

        if (reel.length === 0 || !overlap) {
            const next = incoming.slice()
            next.sort((a, b) => String(a.filename || "").localeCompare(
                String(b.filename || ""), "en", { numeric: true }))
            const wasPopulated = reel.length > 0
            reel = next
            snapFocusToCurrent()
            // 整批换掉 = 切了图片/视频模式：delegate 全销毁重建，让入场
            // 动画再走一遍把这段盖住（否则是一屏卡片凭空跳出来）
            if (wasPopulated)
                stagger.restart()
            return
        }

        const next = []
        const seen = {}
        for (let i = 0; i < reel.length; i++) {
            const old = reel[i]
            const fresh = old ? byPath[old.path] : null
            if (fresh) {
                next.push(fresh)
                seen[fresh.path] = true
            }
        }
        for (let i = 0; i < incoming.length; i++) {
            const it = incoming[i]
            if (it && it.path && !seen[it.path])
                next.push(it)
        }
        reel = next
        clampFocus()
    }

    Connections {
        target: Lianwall
        function onItemsChanged() { Qt.callLater(root.syncReel) }
    }

    // 焦点绕圈走。不夹在 [0, n-1]：夹住的话走到列表两端，卷轴一侧就空掉
    // 半屏（第 8 轮第一版实测——按文件名排序后当前壁纸恰好是最后一张，
    // 右边几个槽全是空的）。applyDelta 本来就是取模的，这里跟它对齐
    //
    // 槽位本身不动（delta 是槽的身份），所以不能靠 Behavior on x 做过渡——
    // 换焦点只是槽里换图，位置没变。真正在动的是 slideShift：整排按
    // visualDelta = delta - slideShift 插值，走完再改 focusIndex、瞬间回 0。
    //
    // 连按不能排队。上一版每步 400ms 排成队，按 5 下要等 2 秒。
    // 新键来了就地 settle（按已经滑过的距离四舍五入落格），再从 0
    // 开下一步。连按 = 连切，单下才走完整个 decel。
    property real slideShift: 0
    property bool sliding: false
    property bool slideAbort: false
    property real punchScale: 1

    function wrapIndex(i) {
        const n = reel.length
        if (n <= 0)
            return 0
        return ((i % n) + n) % n
    }

    function settleSlide(incoming) {
        if (!sliding)
            return
        slideAbort = true
        slideAnim.stop()
        let step = Math.round(slideShift)
        // 按住连发时 40ms 一键，slideShift 还在 0.2，四舍五入是 0，
        // 焦点永远不走。同方向就至少落一格
        const sameDir = incoming !== 0 && ((incoming > 0) === (slideShift > 0)
            || (incoming > 0) === (slideAnim.to > 0))
        if (sameDir && step === 0)
            step = incoming > 0 ? 1 : -1
        if (step !== 0)
            focusIndex = wrapIndex(focusIndex + step)
        slideShift = 0
        sliding = false
        slideAbort = false
    }

    function moveFocus(delta) {
        const n = reel.length
        if (n <= 0 || delta === 0)
            return
        settleSlide(delta)
        const steps = Math.max(-3, Math.min(3, delta))
        sliding = true
        slideAnim.from = 0
        slideAnim.to = steps
        slideAnim.start()
    }

    function commitSlide() {
        if (slideAbort)
            return
        const step = Math.round(slideAnim.to)
        if (step !== 0)
            focusIndex = wrapIndex(focusIndex + step)
        slideShift = 0
        sliding = false
    }

    NumberAnimation {
        id: slideAnim
        target: root
        property: "slideShift"
        duration: Size.anim.durFx
        easing.type: Easing.Bezier
        easing.bezierCurve: Size.anim.curveDecel
        onStopped: root.commitSlide()
    }

    SequentialAnimation {
        id: punchAnim
        NumberAnimation {
            target: root
            property: "punchScale"
            to: 1.08
            duration: Size.anim.durFx
            easing.type: Easing.Bezier
            easing.bezierCurve: Size.anim.curveSpatial
        }
        NumberAnimation {
            target: root
            property: "punchScale"
            to: 1
            duration: Size.anim.durFast
            easing.type: Easing.Bezier
            easing.bezierCurve: Size.anim.curveSpatial
        }
    }

    function activateFocused() {
        const it = focusedItem
        if (it && it.path)
            Lianwall.setWallpaper(it.path)
        punchScale = 1
        punchAnim.restart()
    }

    Keys.onLeftPressed: (e) => {
        root.moveFocus(-1)
        e.accepted = true
    }
    Keys.onRightPressed: (e) => {
        root.moveFocus(1)
        e.accepted = true
    }
    Keys.onReturnPressed: (e) => { activateFocused(); e.accepted = true }
    Keys.onEnterPressed: (e) => { activateFocused(); e.accepted = true }

    component IconBtn: Rectangle {
        id: button
        property string icon: ""
        property bool active: false
        signal clicked()

        implicitWidth: 36
        implicitHeight: 36
        radius: Size.rounding.md
        color: active
            ? Color.withAlpha(Color.primary, 0.16)
            : Color.surfaceContainerHigh

        Text {
            anchors.centerIn: parent
            text: button.icon
            font.family: Size.fontMono
            font.pixelSize: Size.fontSize.lg
            color: button.active ? Color.primary : Color.backgroundText
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    // ---- 卷轴几何 ----
    //
    // 一屏 5 张实卡（dist 0/1/2），再往外 dist 3 那格淡到 0 当出入场位。
    // 焦点卡压在邻居上面，左右两张各往它底下塞一截，所以同样的宽度能放
    // 更大的卡：平铺 5 张在 860 宽里焦点卡只有 251，叠起来能到 300。
    //
    // 尺寸不写死，从可用区反算——改岛宽不用回来改这里。
    // 总跨度 = 2 × (d2 中心 + d2 半宽) = 2.858 × base，推导见 slotOffset
    readonly property var shotScale: [1.0, 0.683, 0.466]
    readonly property var shotOpacities: [1.0, 0.9, 0.7]
    readonly property real shotAspect: 0.66     // 高 / 宽，3:2 照片比
    readonly property real overlap1: 0.12       // d1 往焦点底下塞进去的比例
    readonly property real overlap2: 0.10

    property real reelW: 0
    property real reelH: 0

    readonly property real shotBase: {
        if (reelW <= 0 || reelH <= 0)
            return 120
        const byW = reelW / 2.858
        const byH = (reelH - 16) / shotAspect
        return Math.max(120, Math.min(byW, byH))
    }
    // 解码尺寸只跟岛宽走，不跟滑动走。绑 slot.width 的话 400ms 里
    // sourceSize 每帧都变，等于 7 张图连着重解码，cache:false 再把
    // 每一帧都丢掉——←→ 闪的就是这个
    readonly property int thumbSource: Math.round(shotBase * 1.4)

    // 只给焦点附近这么多格真正加载图片。
    //
    // 第 8 轮为了止闪，把「每张壁纸一个 delegate、source 一辈子不改」和
    // asynchronous: false 一起上了。闪是止住了，但 source 是无条件设的，
    // 于是进页面要把**全部** 49 张同步解码完才还回主线程：实测烧 260ms CPU，
    // 期间连 IPC 都应答不了（94ms）。切图片/视频模式时整个 reel 被换掉，
    // delegate 全部重建，再来一遍。
    //
    // onStage 是 dist < 3.2，留 2 格余量。按住方向键 40ms 一发，
    // 两格够异步解码追上（一张 720×720 的 jpg 几毫秒）。
    readonly property int preloadDist: 5

    function offsetAt(k) {
        if (k <= 0)
            return 0
        const b = shotBase
        let off = b * 0.5 + b * shotScale[1] * 0.5 - b * overlap1
        if (k >= 2)
            off += b * shotScale[1] * 0.5 + b * shotScale[2] * 0.5 - b * overlap2
        if (k >= 3)
            off += b * shotScale[2] * 0.85
        return off
    }

    function slotOffset(d) {
        const sign = d < 0 ? -1 : 1
        const ad = Math.abs(d)
        const i0 = Math.floor(ad)
        const t = ad - i0
        return sign * (offsetAt(i0) * (1 - t) + offsetAt(i0 + 1) * t)
    }

    function slotScaleOf(d) {
        const ad = Math.abs(d)
        if (ad <= 1)
            return shotScale[0] + (shotScale[1] - shotScale[0]) * ad
        if (ad <= 2)
            return shotScale[1] + (shotScale[2] - shotScale[1]) * (ad - 1)
        if (ad <= 3)
            return shotScale[2] * (1 - (ad - 2) * 0.4)
        return shotScale[2] * 0.6
    }

    function slotOpacityOf(d) {
        const ad = Math.abs(d)
        if (ad <= 1)
            return shotOpacities[0] + (shotOpacities[1] - shotOpacities[0]) * ad
        if (ad <= 2)
            return shotOpacities[1] + (shotOpacities[2] - shotOpacities[1]) * (ad - 1)
        // 第 4 张（dist 3）是出场/退场那格：淡到 0 再让 onStage 收掉
        if (ad <= 3)
            return Math.max(0, shotOpacities[2] * (1 - (ad - 2)))
        return 0
    }

    QslStagger { id: stagger }
    function playEnter() { stagger.restart() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: 42
            Layout.maximumHeight: 42
            spacing: 10
            opacity: stagger.shown(0) ? 1 : 0
            transform: Translate {
                y: stagger.shown(0) ? 0 : 10
                Behavior on y { Anim { type: Anim.Enter } }
            }
            Behavior on opacity { Anim { type: Anim.EffectsSlow } }

            IconBtn {
                icon: Lianwall.modeIcon
                active: true
                onClicked: Lianwall.switchMode()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: (root.focusedItem ? (root.focusedItem.filename || "") : "—")
                        + (root.focusedItem && root.focusedItem.is_current ? " · 已应用" : "")
                    color: Color.backgroundText
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.md
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: Lianwall.modeLabel + "模式 · " + (Lianwall.engine || "--")
                        + " · 本页 " + root.reel.length
                        + " · 锁定 " + Lianwall.lockedCount
                    color: Color.textMuted
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.xsm
                    elide: Text.ElideRight
                }
            }

            IconBtn {
                icon: "\uf048"
                onClicked: root.applyDelta(-1)
            }
            IconBtn {
                icon: "\uf051"
                onClicked: root.applyDelta(1)
            }
        }

        Item {
            id: reelArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            // 整块只做位移，淡入交给每张卡自己（见 slot 的 entryOpacity）——
            // 两层都淡的话卡片要穿过两次半透明，边缘会发灰
            transform: Translate {
                y: stagger.shown(1) ? 0 : 14
                Behavior on y { Anim { type: Anim.Enter } }
            }

            onWidthChanged: root.reelW = width
            onHeightChanged: root.reelH = height

            // 一张壁纸一个 delegate，source 一辈子不改。
            // 以前 7 个槽按位置换绑，滑完 focusIndex++，中心那张图换到
            // 另一个 Image 上——改 source 必闪，跟加载不加载无关。
            // lianwall 的 jpg 已经在 ~/.cache 里，同步读出来即可。
            Repeater {
                model: root.reel

                Item {
                    id: slot
                    required property int index
                    required property var modelData

                    readonly property real visualDelta: {
                        const n = root.reel.length
                        if (n <= 0)
                            return 99
                        let d = index - root.focusIndex
                        if (d > n / 2)
                            d -= n
                        if (d < -n / 2)
                            d += n
                        return d - root.slideShift
                    }
                    readonly property real dist: Math.abs(visualDelta)
                    readonly property bool onStage: dist < 3.2
                    readonly property bool isFocus: dist < 0.2
                    readonly property real poseScale: root.slotScaleOf(visualDelta)
                    readonly property string thumbUrl: {
                        const thumb = String(modelData.thumb || "")
                        return thumb.length ? ("file://" + thumb) : ""
                    }

                    // 进过窗口就不再卸载。everLoaded 只从 false 变 true，所以
                    // source 一辈子只改一次 "" → url，而且那一刻这张卡还在
                    // dist 5、完全看不见——第 8 轮那次闪是 source 在**可见时**
                    // 被改（7 个槽按位置换绑），跟同步不同步无关。
                    readonly property bool nearNow: dist <= root.preloadDist
                    property bool everLoaded: false
                    onNearNowChanged: if (nearNow) everLoaded = true
                    Component.onCompleted: if (nearNow) everLoaded = true

                    // 逐张入场：焦点先亮，两侧按格数依次跟上。
                    //
                    // 不能直接给 scale / opacity 加 Behavior——那两个是
                    // visualDelta 的**逐帧函数**（滑动时每帧都在变），加了
                    // Behavior 等于给每一帧的导航都套一层阻尼。所以入场单开
                    // 两个乘数，各自带动画，与逐帧那套相乘。
                    readonly property bool entered:
                        stagger.shown(1 + Math.min(3, Math.round(dist)))
                    property real entryOpacity: entered ? 1 : 0
                    property real entryScale: entered ? 1 : 0.9
                    Behavior on entryOpacity { Anim { type: Anim.EffectsSlow } }
                    Behavior on entryScale { Anim { type: Anim.Enter } }

                    width: root.shotBase
                    height: root.shotBase * root.shotAspect
                    x: reelArea.width / 2 + root.slotOffset(visualDelta) - width / 2
                    y: (reelArea.height - height) / 2
                    z: 20 - dist * 10
                    scale: poseScale * (isFocus ? root.punchScale : 1) * entryScale
                    opacity: (onStage ? root.slotOpacityOf(visualDelta) : 0) * entryOpacity
                    visible: onStage
                    transformOrigin: Item.Center

                    Rectangle {
                        anchors.fill: parent
                        radius: Size.rounding.lg
                        color: Color.background

                        Rectangle {
                            id: face
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: Size.rounding.md
                            color: Color.surfaceContainerHigh

                            Image {
                                id: thumbImg
                                anchors.fill: parent
                                // 异步解码。同步的话 13 张也要一起堵住主线程；
                                // 异步 + 上面的逐张入场，解码正好藏在入场那 150ms 里
                                source: slot.everLoaded ? slot.thumbUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize.width: root.thumbSource
                                sourceSize.height: root.thumbSource

                                layer.enabled: slot.onStage && status === Image.Ready
                                layer.smooth: true
                                layer.effect: OpacityMask {
                                    maskSource: Item {
                                        width: root.shotBase
                                        height: root.shotBase * root.shotAspect
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: face.radius
                                            color: "#000000"
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: slot.thumbUrl.length === 0
                                text: modelData.is_video ? "\uf03d" : "\uf03e"
                                font.family: Size.fontMono
                                font.pixelSize: 22
                                color: Color.textMuted
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 6
                                width: curLabel.implicitWidth + 12
                                height: 18
                                radius: 9
                                color: Color.primary
                                visible: !!modelData.is_current
                                Text {
                                    id: curLabel
                                    anchors.centerIn: parent
                                    text: "当前"
                                    color: Color.primaryText
                                    font.pixelSize: Size.fontSize.xsm
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (slot.isFocus)
                                        root.activateFocused()
                                    else
                                        root.moveFocus(Math.round(slot.visualDelta))
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                z: 20
                visible: root.reel.length === 0 && !Lianwall.loading
                // 空态自己淡入：上面那层整块的淡入已经撤了
                opacity: stagger.shown(1) ? 1 : 0
                Behavior on opacity { Anim { type: Anim.EffectsSlow } }
                text: Lianwall.error.length > 0 ? Lianwall.error : "暂无壁纸"
                color: Color.textMuted
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.lg
            }
        }
    }
}
