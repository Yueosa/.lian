// NotePanel — 常驻笔记面板（qsl.md M3）
//
// 全壳第一种常驻形态：不走 present 开合，一直贴在左 rail 内侧（x=8、y=56，
// 宽同 C 面板）。让位：C/Z 开着时滑回 rail、它们关掉再滑出来——用的是互斥表
// 的**读侧**（Panels.activeIn("left")），不 claim 组：claim 的语义是「被挤掉就
// 关窗」，对常驻面板是错的，而且常驻 claim 会把键盘栈永远顶住。
//
// 焦点：打字态 = 编辑框持有焦点（点击 / Super+J）。进入压 Panels 栈 + 占
// 水波槽位（edge left，anchor 报卡片中线——焦点态才有涟漪，qsl.md 定）；
// 退出 flush + release，临别波和键盘归还都由现有机制白送。
//
// 诉求上报（跟 Leftbar 的 open 绑定刻意不同）：
//   wantsOverlay 恒 false——常驻面板不该把框窗钉在 Overlay 层；
//   wantsKeyboard = 打字态（点进输入框由 OnDemand 给键盘，Super+J 由 grab 给）；
//   hitBox = 卡片矩形，常驻可点（让位时 0×0）。

import QtQuick
import qs.Components
import qs.data.service
import qs.data.state

Item {
    id: root

    anchors.fill: parent

    readonly property string panelId: "qsl-note"

    // 让位：left 组（C / Z）有人开着，我就不占地方
    readonly property bool yieldToPanel: Panels.activeIn("left") !== ""

    // 打字态（NoteCard 据输入框焦点回写；让位时本文件强制清掉）
    QtObject {
        id: panelState

        property bool typing: false
        property string activeNoteId: ""
    }

    readonly property bool wantsOverlay: false
    readonly property bool wantsKeyboard: panelState.typing
    readonly property Item hitBox: hitRegion

    onYieldToPanelChanged: {
        if (root.yieldToPanel)
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

    // 点框外（dismissAll）或键盘栈被顶替 → 退出打字态，笔记本体保持常驻
    Connections {
        target: Panels
        function onEvicted(id) {
            if (id === root.panelId)
                root.exitTyping()
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

    // Super+J（M4 IPC note focus）走这里：打字中 = 归还；否则抢占。
    // C/Z 开着时先逐客（它们让位后笔记才可见、可聚焦）——「抢占」语义。
    // 笔记容器可能还在派生中（bodyItem 未建），挂个 callLater 重试闸
    property bool _pendingFocus: false

    function toggleFocus() {
        if (panelState.typing) {
            exitTyping()
            return
        }
        if (yieldToPanel) {
            const other = Panels.activeIn("left")
            if (other !== "")
                Panels.evicted(other)
        }
        _pendingFocus = true
        _grabWhenReady()
    }

    function _grabWhenReady() {
        if (!_pendingFocus)
            return
        if (yieldToPanel) {
            // 逐客没生效（目标已自己关了之类），放弃这次聚焦，别空转
            _pendingFocus = false
            return
        }
        if (noteContainer.bodyItem) {
            _pendingFocus = false
            noteContainer.bodyItem.grabEditorFocus()
        } else {
            Qt.callLater(_grabWhenReady)
        }
    }

    // ---- 键盘：Esc 退出打字态（Keys.BeforeItem 在编辑框之前拦到）----
    // 悬停聚焦（qsl.md 定）：鼠标进卡就 forceActiveFocus，焦点视觉先行；
    // 打字仍要点击输入框或 Super+J——hover 不抢应用键盘（OnDemand 只认点击）
    property bool hovered: hoverMa.containsMouse

    FocusScope {
        id: noteScope
        anchors.fill: parent
        focus: root.hovered || panelState.typing

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape && panelState.typing) {
                root.exitTyping()
                event.accepted = true
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
        enabled: !root.yieldToPanel
        onContainsMouseChanged: {
            if (containsMouse)
                Qt.callLater(() => noteScope.forceActiveFocus())
        }
    }

    // ---- 常驻容器：RailContainer 白送贴 rail 几何/耳朵/派生动画 ----
    // present = 让位条件的反相；让位即滑回 rail（同一条派生语言），
    // 回来重新派生、内容重建
    RailContainer {
        id: noteContainer
        x: 8
        y: 56
        edge: "left"
        gate: true
        naturalWidth: Size.panel.cWidth
        present: !root.yieldToPanel
        staggerMs: 0
        exitStaggerMs: 0
        sourceComponent: NoteCard {
            sharedState: panelState
        }
    }

    // 让位时 0×0（同 RailPage inputMask 的口径）
    Item {
        id: hitRegion
        x: noteContainer.x
        y: noteContainer.y
        width: root.yieldToPanel ? 0 : noteContainer.width
        height: root.yieldToPanel ? 0 : noteContainer.height
    }
}
