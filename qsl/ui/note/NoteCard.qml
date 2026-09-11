// NoteCard — 笔记编辑器卡（qsl.md M3）
//
// 上：笔记 tab 芯片条（横向滚动 + 新建/删除）；中：标题行；下：正文
// （最小 120、上限 260，超了 TextArea 内部滚动——高度有上限，不无限长）。
//
// 打字即自动保存：服务层 500ms 无输入防抖，切笔记/退出打字态 flush。
// 编辑器文本是**命令式赋值**驱动的，不是绑定：TextArea.text 一旦被用户输入
// 赋值，绑定就永久断掉（plan-notes 第 10 轮「stop() 与赋值」那条），切笔记时
// 换不回来。所以切笔记时显式赋 text，onTextChanged 里回写服务。
//
// 焦点：本卡只管「编辑框有没有焦点」，回写到 sharedState.typing；
// 压栈/涟漪/还键盘全在 NotePanel。
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Components
import qs.data.service
import qs.data.state

Item {
    id: root

    anchors.fill: parent
    implicitHeight: mainCol.implicitHeight + 32   // 上下各 16 留白

    // 指向 NotePanel.panelState（typing / activeNoteId）
    property QtObject sharedState
    property bool _switching: false

    // 当前笔记（revision 兜底：notes 是重赋值数组，这里顺带吃掉绑定依赖）
    readonly property var activeNote: {
        void Note.revision
        const id = root.sharedState ? root.sharedState.activeNoteId : ""
        if (!id)
            return null
        for (let i = 0; i < Note.notes.length; i++) {
            if (Note.notes[i] && Note.notes[i].id === id)
                return Note.notes[i]
        }
        return null
    }

    // ---- 焦点同步 ----
    function syncTyping() {
        if (root.sharedState)
            root.sharedState.typing = titleInput.activeFocus || bodyEdit.activeFocus
    }

    Connections {
        target: titleInput
        function onActiveFocusChanged() { root.syncTyping() }
    }
    Connections {
        target: bodyEdit
        function onActiveFocusChanged() { root.syncTyping() }
    }

    function grabEditorFocus() {
        // 焦点落在正文（用户定）：标题是元信息，写内容才是主路径。
        // 服务加载完之前 activeNote 还是 null，这一拍无焦点可落，no-op
        Qt.callLater(() => {
            if (root.activeNote)
                bodyEdit.forceActiveFocus()
        })
    }

    function releaseEditorFocus() {
        titleInput.focus = false
        bodyEdit.focus = false
    }

    // Ctrl+Tab：笔记间循环。id 列表只随增删变（Note.noteIds），
    // 转一圈回到自己的情况（只有一篇）由 selectNote 的等值检查吞掉。
    // 调用点在两个编辑框本体的 Keys.onTabPressed（Tab 一族不冒泡，
    // 见上）
    function cycleNote(step) {
        const ids = Note.noteIds
        if (ids.length === 0)
            return
        let i = ids.indexOf(root.sharedState.activeNoteId)
        if (i < 0)
            i = 0
        root.selectNote(ids[(i + step + ids.length) % ids.length])
    }

    // ---- 笔记选择 ----
    // activeNoteId 存在 sharedState（NotePanel）里：容器让位会卸载本卡，
    // 状态不能跟卡一起死
    function ensureActive() {
        if (root.activeNote)
            return
        const ids = Note.noteIds
        if (root.sharedState)
            root.sharedState.activeNoteId = ids.length > 0 ? ids[0] : ""
    }

    Component.onCompleted: {
        root.ensureActive()
        root._loadTexts()
    }

    Connections {
        target: Note
        function onRevisionChanged() { root.ensureActive() }
    }

    // 回填文本。_loadedFor 挡住两类重入：
    //  · setBody/setTitle 每敲一下重赋值 notes → activeNote 每次都是新对象，
    //    onActiveNoteChanged 会跟着响——回填同一篇会重置光标/撤销栈
    //  · 服务晚于本卡加载（FileView 异步）：ensureActive 选中第一篇时在这里
    //    把磁盘内容填进编辑框
    property string _loadedFor: ""

    onActiveNoteChanged: {
        if (!root._switching)
            root._loadTexts()
    }

    // 卡重生（让位回来）时从 activeNoteId 回填文本
    function _loadTexts() {
        const n = root.activeNote
        if (n && root._loadedFor === n.id)
            return
        root._switching = true
        titleInput.text = n ? n.title : ""
        bodyEdit.text = n ? n.body : ""
        root._switching = false
        root._loadedFor = n ? n.id : ""
    }

    function selectNote(id) {
        if (!root.sharedState || root.sharedState.activeNoteId === id)
            return
        // 离开旧笔记先落盘（服务内存里已经是新的，flush 只补落盘）
        Note.flush()
        root.sharedState.activeNoteId = id
        root._loadTexts()
        bodyEdit.forceActiveFocus()
    }

    function addNote() {
        Note.flush()
        const id = Note.add()
        root.sharedState.activeNoteId = id
        root._loadTexts()
        // 新笔记也落在正文（用户定）：标题空着，光标直接进内容
        bodyEdit.forceActiveFocus()
    }

    function removeActive() {
        if (!root.activeNote)
            return
        const cur = root.activeNote.id
        Note.flush()
        Note.remove(cur)
        // 删到一篇不剩 = 立刻立一篇新的：默认就该是新建的笔记（用户定），
        // 空态不可达。剩下的情况落在第一条
        let ids = Note.noteIds
        if (ids.length === 0)
            ids = [Note.add()]
        root.sharedState.activeNoteId = ids[0]
        root._loadTexts()
        bodyEdit.forceActiveFocus()
    }

    ColumnLayout {
        id: mainCol
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: Size.spacing.sm

        // ---- tab 芯片条 ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.xs

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                contentWidth: tabRow.implicitWidth
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: tabRow
                    spacing: Size.spacing.xs

                    Repeater {
                        model: Note.noteIds

                        QslChip {
                            required property string modelData

                            // 标题走 revision 兜底：setTitle 重赋值数组才发通知
                            text: {
                                void Note.revision
                                const t = Note.titleOf(modelData)
                                return t.length > 0 ? t : ("笔记 " + (index + 1))
                            }
                            selected: root.sharedState
                                && modelData === root.sharedState.activeNoteId
                            chipHeight: 32
                            onClicked: root.selectNote(modelData)
                        }
                    }
                }
            }

            // 新建（固定 32×32，热区严格等于自身——TodoRow 的误触教训）
            Item {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: "add"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.iconSize.lg
                    color: Color.primary
                }

                QslStateLayer {
                    source: addMa
                    tint: Color.primary
                }

                MouseArea {
                    id: addMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addNote()
                }
            }

            // 删除当前（悬停转 error 色）
            Item {
                visible: root.activeNote !== null
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: "delete"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.iconSize.md
                    color: delMa.containsMouse ? Color.error : Color.textMuted
                    Behavior on color { CAnim {} }
                }

                QslStateLayer {
                    source: delMa
                    tint: Color.error
                }

                MouseArea {
                    id: delMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.removeActive()
                }
            }
        }

        // ---- 标题（有背景，观感同正文输入区）----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            visible: root.activeNote !== null
            radius: Size.rounding.sm
            color: Color.surfaceContainerHigh
            border.width: titleInput.activeFocus ? Style.border.width : 0
            border.color: Color.withAlpha(Color.primary, 0.5)

            TextInput {
                id: titleInput
                anchors.fill: parent
                anchors.leftMargin: Size.spacing.md
                anchors.rightMargin: Size.spacing.md
                color: Color.text
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.titleMedium
                font.bold: true
                clip: true
                selectByMouse: true
                verticalAlignment: Text.AlignVCenter

                // Tab 挂在输入框**自己**身上（wifi 密码框同款思路）：QQC2
                // TextArea 会把 Tab 当普通字符吞掉，外层作用域拦不到，但挂在本
                // 体上的 Keys 先于 C++ 处理（offscreen 实测）。而且一旦挂了本体
                // 处理器，Tab 一族就不再冒泡——所以 Ctrl+Tab 也在这里就地处理
                // （accept 掉），不放给外层
                Keys.onTabPressed: (e) => {
                    if (e.modifiers & Qt.ControlModifier) {
                        root.cycleNote(e.modifiers & Qt.ShiftModifier ? -1 : 1)
                        e.accepted = true
                        return
                    }
                    bodyEdit.forceActiveFocus()
                    e.accepted = true
                }
                Keys.onBacktabPressed: (e) => {
                    if (e.modifiers & Qt.ControlModifier) {
                        root.cycleNote(e.modifiers & Qt.ShiftModifier ? -1 : 1)
                        e.accepted = true
                        return
                    }
                    bodyEdit.forceActiveFocus()
                    e.accepted = true
                }

                onTextChanged: {
                    if (root._switching)
                        return
                    const n = root.activeNote
                    if (n && titleInput.text !== n.title)
                        Note.setTitle(n.id, titleInput.text)
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: !titleInput.text && titleInput.activeFocus
                    text: "标题"
                    color: Color.textMuted
                    font: titleInput.font
                }
            }
        }

        // ---- 正文 ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.activeNote !== null
                ? Math.min(260, Math.max(120, bodyEdit.contentHeight + 16))
                : 0
            visible: root.activeNote !== null
            radius: Size.rounding.sm
            color: Color.surfaceContainerHigh
            border.width: bodyEdit.activeFocus ? Style.border.width : 0
            border.color: Color.withAlpha(Color.primary, 0.5)

            TextArea {
                id: bodyEdit
                anchors.fill: parent
                anchors.leftMargin: Size.spacing.sm
                anchors.rightMargin: Size.spacing.sm
                anchors.topMargin: Size.spacing.sm
                anchors.bottomMargin: Size.spacing.sm
                wrapMode: TextArea.Wrap
                selectByMouse: true
                textFormat: TextEdit.PlainText
                placeholderText: "写点什么…"
                placeholderTextColor: Color.textMuted
                color: Color.text
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.bodyMedium
                background: null
                padding: 0

                // 同上：Tab 本体拦截，Ctrl+Tab 就地切笔记
                Keys.onTabPressed: (e) => {
                    if (e.modifiers & Qt.ControlModifier) {
                        root.cycleNote(e.modifiers & Qt.ShiftModifier ? -1 : 1)
                        e.accepted = true
                        return
                    }
                    titleInput.forceActiveFocus()
                    e.accepted = true
                }
                Keys.onBacktabPressed: (e) => {
                    if (e.modifiers & Qt.ControlModifier) {
                        root.cycleNote(e.modifiers & Qt.ShiftModifier ? -1 : 1)
                        e.accepted = true
                        return
                    }
                    titleInput.forceActiveFocus()
                    e.accepted = true
                }

                onTextChanged: {
                    if (root._switching)
                        return
                    const n = root.activeNote
                    if (n && bodyEdit.text !== n.body)
                        Note.setBody(n.id, bodyEdit.text)
                }
            }
        }

        // ---- 快捷键提示：一行小字（方案见 qsl.md M3）----
        Text {
            Layout.fillWidth: true
            Layout.topMargin: Size.spacing.xs
            text: "Tab 标题/正文 · Ctrl+N 新建 · Ctrl+Tab 切笔记(Shift 反向)"
            color: Color.textMuted
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.labelSmall
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
