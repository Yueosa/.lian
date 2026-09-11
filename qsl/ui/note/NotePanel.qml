// NotePanel — 笔记面板（qsl.md M3）
//
// 常驻语义（用户定）：默认展开在左 rail 内侧（x=8、y=56，宽同 C 面板），
// 但可以关——它不是传统面板的 open/present 开合，而是「收起 = 滑回 rail」：
//   Super+J  唤出（隐藏时）+ 切换焦点（打字态 ↔ 静息）
//   Esc      关闭页面（退出打字 + 收起回 rail）
//   点框外   同 Esc（dismissAll 的 evicted 走到 closePanel）
//   C/Z 开着 临时让位（它们关掉再滑回来，除非已被用户 Esc 关掉）
//
// 让位用互斥表的**读侧**（Panels.activeIn("left")），不 claim 组：claim 的
// 语义是「被挤掉就关窗」，对这类面板是错的，而且常驻 claim 会把键盘栈顶住。
//
// 焦点：打字态 = 编辑框持有焦点（点击 / Super+J）。进入压 Panels 栈 + 占
// 水波槽位（edge left，anchor 报卡片中线——焦点态才有涟漪，qsl.md 定）；
// 退出 flush + release，临别波和键盘归还都由现有机制白送。
//
// 诉求上报（跟 Leftbar 的 open 绑定刻意不同）：
//   wantsOverlay 恒 false——笔记不该把框窗钉在 Overlay 层；
//   wantsKeyboard = 打字态（点进输入框由 OnDemand 给键盘，Super+J 由 grab 给）；
//   hitBox = 卡片矩形，可见时恒可点。

import QtQuick
import qs.Components
import qs.data.service
import qs.data.state

Item {
    id: root

    anchors.fill: parent

    readonly property string panelId: "qsl-note"

    // 默认收起（用户定）：启动不展开，Super+J 才唤出；Esc/点框外关掉后
    // 同样保持隐藏直到下次 Super+J
    property bool userHidden: true
    // 让位：left 组（C / Z）有人开着，我就不占地方
    readonly property bool yieldToPanel: Panels.activeIn("left") !== ""
    readonly property bool hidden: userHidden || yieldToPanel

    // 打字态（NoteCard 据输入框焦点回写；隐藏时本文件强制清掉）
    QtObject {
        id: panelState

        property bool typing: false
        property string activeNoteId: ""
    }

    readonly property bool wantsOverlay: false
    readonly property bool wantsKeyboard: panelState.typing
    readonly property Item hitBox: hitRegion

    onHiddenChanged: {
        if (root.hidden)
            exitTyping()
    }

    // 打字态进出：压/弹键盘栈 + 占/清水波槽位。
    // edge 给 "left"：claim 自带进波、release 自带临别波，周期波只在占用期间
    Connections {
        target: panelState
        function onTypingChanged() {
            if (panelState.typing) {
                Panels.claim(root.panelId, "", "left", "top",
                             Math.round(56 + noteContainer.height / 2))
            } else {
                Note.flush()
                Panels.release(root.panelId)
            }
        }
    }

    // 点框外（dismissAll）→ 关闭页面；键盘栈被顶替 → 只退打字态（C/V 开窗
    // 时笔记还可见，不该整页关掉）
    Connections {
        target: Panels
        function onEvicted(id) {
            if (id === root.panelId)
                root.closePanel()
        }
        function onKeyboardOwnerChanged() {
            if (panelState.typing && Panels.keyboardOwner !== root.panelId)
                root.exitTyping()
        }
    }

    function exitTyping() {
        if (!panelState.typing)
            return
        // flush + release 由 onTypingChanged 负责，这里只拨状态、松编辑框焦点
        panelState.typing = false
        if (noteContainer.bodyItem)
            noteContainer.bodyItem.releaseEditorFocus()
    }

    // Esc / 点框外：关闭页面 = 退出打字 + 收起回 rail（用户定）
    function closePanel() {
        exitTyping()
        userHidden = true
    }

    // Super+J（M4 IPC note toggle）：唤出 + 切换焦点。
    // 笔记容器可能还在派生中（bodyItem 未建），挂个 callLater 重试闸
    property bool _pendingFocus: false
    property bool _pendingAdd: false

    function toggleFocus() {
        if (hidden) {
            userHidden = false
            _requestFocus()
            return
        }
        if (panelState.typing) {
            exitTyping()
            return
        }
        _requestFocus()
    }

    // IPC focus：总是抢占（不 toggle）
    function grabFocus() {
        _requestFocus()
    }

    // IPC add：新建一篇并聚焦正文
    function addNote() {
        userHidden = false
        _requestFocus()
        _pendingAdd = true
        _grabWhenReady()
    }

    function _requestFocus() {
        if (yieldToPanel) {
            const other = Panels.activeIn("left")
            if (other !== "")
                Panels.evicted(other)
        }
        _pendingFocus = true
        _grabWhenReady()
    }

    function _grabWhenReady() {
        if (!_pendingFocus && !_pendingAdd)
            return
        if (root.hidden) {
            // 逐客没生效（目标已自己关了之类），放弃这次请求，别空转
            _pendingFocus = false
            _pendingAdd = false
            return
        }
        if (noteContainer.bodyItem) {
            const card = noteContainer.bodyItem
            if (_pendingAdd) {
                _pendingAdd = false
                _pendingFocus = false
                card.addNote()
            } else if (_pendingFocus) {
                _pendingFocus = false
                card.grabEditorFocus()
            }
        } else {
            Qt.callLater(_grabWhenReady)
        }
    }

    // ---- 键盘 ----
    // 焦点作用域必须**包住**笔记容器：内容放在作用域外面（兄弟节点）时，
    // 编辑框一拿 activeFocus 焦点就带出了本子树，Keys.onPressed 从此不再
    // 触发——RailPage.keyScope 注释里记着 V 面板焦点饥饿的同一课，本文件
    // 第一版就栽在这上面（Esc 无路可退 = 「笔记关不掉」）。
    // 悬停聚焦（qsl.md 定）：鼠标进卡就 forceActiveFocus，焦点视觉先行；
    // 打字仍要点击输入框或 Super+J——hover 不抢应用键盘（OnDemand 只认点击）
    property bool hovered: hoverMa.containsMouse

    FocusScope {
        id: noteScope
        anchors.fill: parent
        focus: root.hovered || panelState.typing

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: (event) => {
            const shift = event.modifiers & Qt.ShiftModifier
            const ctrl = event.modifiers & Qt.ControlModifier
            // Tab 的标题↔正文切换不在这里——挂在编辑框本体的 Keys.onTabPressed
            // 上（QQC2 TextArea 会把 Tab 吞成字符，外层作用域拦不到，实测）。
            // 这里只管 Ctrl 一族与 Esc（Ctrl+Tab 从 TextArea 正常冒泡，实测）
            if (panelState.typing && noteContainer.bodyItem) {
                const card = noteContainer.bodyItem
                if (ctrl && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
                    card.cycleNote(shift || event.key === Qt.Key_Backtab ? -1 : 1)
                    event.accepted = true
                    return
                }
                if (ctrl && event.key === Qt.Key_N) {
                    card.addNote()
                    event.accepted = true
                    return
                }
            }
            if (event.key === Qt.Key_Escape) {
                root.closePanel()
                event.accepted = true
            }
        }

        // ---- 容器：RailContainer 白送贴 rail 几何/耳朵/派生动画 ----
        // present = hidden 的反相；收起即滑回 rail（同一条派生语言），
        // 回来重新派生、内容重建
        RailContainer {
            id: noteContainer
            x: 8
            y: 56
            edge: "left"
            gate: true
            naturalWidth: Size.panel.cWidth
            present: !root.hidden
            staggerMs: 0
            exitStaggerMs: 0
            // 打字逐行换高度 = 高频重定目标：过冲档会「长过头再缩回来」
            // （A 搜索列表的教训），换不过冲的减速档，同 A / Z
            elasticType: Anim.EnterFast
            sourceComponent: NoteCard {
                sharedState: panelState
            }
        }
    }

    MouseArea {
        id: hoverMa
        x: noteContainer.x
        y: noteContainer.y
        width: noteContainer.width
        height: noteContainer.height
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: !root.hidden
        onContainsMouseChanged: {
            if (containsMouse)
                Qt.callLater(() => noteScope.forceActiveFocus())
        }
    }

    // 隐藏时 0×0（同 RailPage inputMask 的口径）
    Item {
        id: hitRegion
        x: noteContainer.x
        y: noteContainer.y
        width: root.hidden ? 0 : noteContainer.width
        height: root.hidden ? 0 : noteContainer.height
    }
}
