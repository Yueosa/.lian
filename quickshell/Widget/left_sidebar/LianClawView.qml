import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.config
import Clavis.LianClaw

// LianClaw 主视图：抽屉 → 归档提示 → 消息流 → 输入占位 → 模式条
// 整体风格对齐 weather 卡片：大圆角、半透明、柔和边框。
Item {
    id: root

    readonly property bool _isArchived: LianClawState.currentIsArchived
    readonly property bool _hasSession: LianClawState.currentSid !== ""
    readonly property bool _editable: _hasSession && !_isArchived

    property bool _modeOpen: false
    property bool _wmodeOpen: false

    Component.onCompleted: {
        if (LianClawState.sessions.length === 0) LianClawState.refreshSessions();
    }

    function _statusText() {
        var p = LianClawState.streamPhase;
        if (!p) return _hasSession ? "就绪" : "";
        if (p === "accepted")      return "● 请求已接收";
        if (p === "processing")    return "● 处理中";
        if (p === "context_ready") return "● 上下文就绪";
        if (p === "llm")           return "● LLM 调用中" + (LianClawState.streamModel ? " · " + LianClawState.streamModel : "");
        if (p === "completed")     return "✓ 完成";
        if (p === "error")         return "× " + (LianClawState.lastStreamError || "错误");
        return "● " + p;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Sizes.spacing.md
        spacing: Sizes.spacing.m

        SessionDrawer { Layout.fillWidth: true }

        // 归档提示
        LcSurfaceCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            visible: root._isArchived
            cardRadius: Sizes.rounding.large
            cardOpacity: 0.78

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Sizes.spacing.md
                anchors.rightMargin: Sizes.spacing.md
                spacing: 6
                Text {
                    text: "inventory_2"
                    font.family: Sizes.fontIcon
                    font.pixelSize: 16
                    color: Colorscheme.on_surface_variant
                }
                Text {
                    text: "此会话已归档，仅可查看历史"
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.on_surface_variant
                }
                Item { Layout.fillWidth: true }
            }
        }

        // 消息流
        LcSurfaceCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            cardRadius: Sizes.rounding.xl
            cardOpacity: 0.62

            ListView {
                id: msgList
                property bool _layoutQueued: false
                anchors.fill: parent
                anchors.margins: Sizes.spacing.md
                anchors.rightMargin: Sizes.spacing.md + 6  // 让出细滚动条空间
                clip: true
                spacing: Sizes.spacing.s
                model: LianClawState.blocks
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 800
                ScrollBar.vertical: LcThinScrollBar {}

                function _scheduleLayout(stickBottom) {
                    if (_layoutQueued)
                        return;
                    var nearBottomBefore = (msgList.contentY + msgList.height + 24) >= msgList.contentHeight;
                    _layoutQueued = true;
                    Qt.callLater(function() {
                        _layoutQueued = false;
                        msgList.forceLayout();
                        if (stickBottom || inputCard._streaming || nearBottomBefore || msgList.atYEnd)
                            msgList.positionViewAtEnd();
                    });
                }

                onCountChanged: _scheduleLayout(true)
                onContentHeightChanged: _scheduleLayout(inputCard._streaming)
                onWidthChanged: _scheduleLayout(inputCard._streaming)
                onHeightChanged: _scheduleLayout(inputCard._streaming)

                Connections {
                    target: LianClawState

                    function onCurrentSidChanged() {
                        msgList._scheduleLayout(true)
                    }

                    function onStreamPhaseChanged() {
                        var p = LianClawState.streamPhase
                        if (p === "completed" || p === "error")
                            msgList._scheduleLayout(true)
                    }
                }

                delegate: MessageBubble {
                    kind: model.kind
                    text: model.text
                    live: model.live
                    frozen: model.frozen
                    toolName: model.toolName
                    toolStatus: model.toolStatus
                    toolCallId: model.toolCallId
                    toolArgs: model.toolArgs
                    actionType: model.actionType
                    actionLabel: model.actionLabel
                    modelName: model.modelName
                }

                LcWelcomeView {
                    anchors.fill: parent
                    visible: msgList.count === 0
                    hasSession: root._hasSession
                    historyLoading: LianClawState.historyLoading
                }
            }
        }

        // 输入栏（P3）
        LcSurfaceCard {
            id: inputCard
            Layout.fillWidth: true
            // 不再依赖 inputArea.implicitHeight（会和 dynamic padding 形成反馈环）
            // 用 contentHeight（仅文本本身高度，不含 padding） + 固定 padding 计算。
            // 36px 按钮 + 上下 6px margin = 48 作为下限，避免发送/重试/停止被底部裁切。
            Layout.preferredHeight: Math.max(48, Math.min(140, inputArea.contentHeight + 28))
            visible: root._editable
            cardRadius: Sizes.rounding.large
            cardOpacity: inputArea.activeFocus ? 0.96 : 0.78
            Behavior on cardOpacity { NumberAnimation { duration: 140 } }

            readonly property bool _streaming: LianClawState.activeIntentId !== ""
                                                || LianClawState.streamPhase === "accepted"
                                                || LianClawState.streamPhase === "processing"
                                                || LianClawState.streamPhase === "context_ready"
                                                || LianClawState.streamPhase === "llm"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Sizes.spacing.md
                anchors.rightMargin: Sizes.spacing.s
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                spacing: 6

                Flickable {
                    id: inputFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: inputArea.contentHeight + inputArea.topPadding + inputArea.bottomPadding
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    TextArea.flickable: TextArea {
                        id: inputArea
                        wrapMode: TextArea.Wrap
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.font.md
                        color: Colorscheme.on_surface
                        placeholderText: inputCard._streaming ? "回复中… (Esc 取消)" : "输入消息，Enter 发送"
                        placeholderTextColor: Colorscheme.outline
                        selectByMouse: true
                        background: null
                        Material.accent: Colorscheme.primary
                        leftPadding: 4; rightPadding: 4
                        topPadding: 4; bottomPadding: 4
                        Keys.onPressed: function(e) {
                            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                if (e.modifiers & Qt.ShiftModifier) return;
                                e.accepted = true;
                                if (inputCard._streaming) return;
                                if (LianClawState.sendMessage(text)) text = "";
                            } else if (e.key === Qt.Key_Escape && inputCard._streaming) {
                                e.accepted = true;
                                LianClawState.cancelStream();
                            }
                        }
                    }

                    ScrollBar.vertical: LcThinScrollBar {}
                }

                // 主按钮：发送 / 停止
                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    radius: 18
                    color: {
                        if (inputCard._streaming)
                            return sendMa.containsMouse ? Colorscheme.error
                                : Qt.rgba(Colorscheme.error.r, Colorscheme.error.g, Colorscheme.error.b, 0.85);
                        var enabled = inputArea.text.trim().length > 0;
                        if (!enabled)
                            return Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.08);
                        return sendMa.containsMouse ? Colorscheme.primary
                            : Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.88);
                    }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: inputCard._streaming ? "stop"
                              : (inputArea.text.trim().length > 0 ? "send" : "edit")
                        font.family: Sizes.fontIcon
                        font.pixelSize: 18
                        color: inputCard._streaming
                            ? Colorscheme.on_error
                            : (inputArea.text.trim().length > 0
                                ? Colorscheme.on_primary
                                : Colorscheme.on_surface_variant)
                    }
                    MouseArea {
                        id: sendMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (inputCard._streaming) {
                                LianClawState.cancelStream();
                            } else if (inputArea.text.trim().length > 0) {
                                if (LianClawState.sendMessage(inputArea.text)) inputArea.text = "";
                            }
                        }
                    }
                }
            }
        }

        // 模式条
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            visible: root._editable

            ModeChip {
                id: modeChip
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                options: ["fast", "deep"]
                current: LianClawState.currentModeChoice
                expanded: root._modeOpen
                accentBg: Colorscheme.primary_container
                accentFg: Colorscheme.on_primary_container
                onToggleRequested: {
                    root._wmodeOpen = false;
                    root._modeOpen = !root._modeOpen;
                }
                onPicked: function(v) {
                    LianClawState.setModeChoice(LianClawState.currentSid, v);
                    root._modeOpen = false;
                }
            }

            Text {
                anchors.left: modeChip.right
                anchors.right: wmodeChip.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Sizes.spacing.m
                anchors.rightMargin: Sizes.spacing.m
                horizontalAlignment: Text.AlignHCenter
                text: root._statusText()
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.font.xs
                color: LianClawState.streamPhase === "error" ? Colorscheme.error
                                                             : Colorscheme.on_surface_variant
                elide: Text.ElideRight
            }

            ModeChip {
                id: wmodeChip
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                options: ["ask", "plan", "agent"]
                current: LianClawState.currentWorkMode
                expanded: root._wmodeOpen
                accentBg: Colorscheme.tertiary_container
                accentFg: Colorscheme.on_tertiary_container
                onToggleRequested: {
                    root._modeOpen = false;
                    root._wmodeOpen = !root._wmodeOpen;
                }
                onPicked: function(v) {
                    LianClawState.setWorkMode(LianClawState.currentSid, v);
                    root._wmodeOpen = false;
                }
            }
        }
    }

    // ===================== 工具确认对话框 =====================
    // 半透明遮罩 + 居中卡片，对应 SSE tool/confirm_required。
    Rectangle {
        id: confirmOverlay
        anchors.fill: parent
        visible: LianClawState.pendingConfirm !== null
        color: Qt.rgba(0, 0, 0, 0.42)
        z: 100

        MouseArea {
            anchors.fill: parent
            // 拦截一切点击，避免穿透到底层
            onClicked: {}
            onWheel: function(w) { w.accepted = true; }
        }

        LcSurfaceCard {
            anchors.centerIn: parent
            width: Math.min(parent.width - Sizes.spacing.lg * 2, 360)
            implicitHeight: confirmCol.implicitHeight + Sizes.spacing.md * 2
            cardRadius: Sizes.rounding.xl
            cardOpacity: 0.98

            ColumnLayout {
                id: confirmCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Sizes.spacing.md
                spacing: Sizes.spacing.s

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: "verified_user"
                        font.family: Sizes.fontIcon
                        font.pixelSize: 18
                        color: Colorscheme.tertiary
                    }
                    Text {
                        text: "工具调用确认"
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.font.lg
                        font.bold: true
                        color: Colorscheme.on_surface
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: LianClawState.pendingConfirm
                                 && LianClawState.pendingConfirm.risk_level
                        text: LianClawState.pendingConfirm
                              ? "风险: " + (LianClawState.pendingConfirm.risk_level || "")
                              : ""
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.font.xs
                        color: Colorscheme.error
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: LianClawState.pendingConfirm
                          ? (LianClawState.pendingConfirm.tool_name || "tool")
                          : ""
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.primary
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: LianClawState.pendingConfirm
                             && LianClawState.pendingConfirm.command
                    Layout.preferredHeight: cmdText.implicitHeight + 14
                    radius: Sizes.rounding.medium
                    color: Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.06)
                    Text {
                        id: cmdText
                        anchors.fill: parent
                        anchors.margins: 7
                        text: LianClawState.pendingConfirm
                              ? (LianClawState.pendingConfirm.command || "")
                              : ""
                        wrapMode: Text.Wrap
                        font.family: Sizes.fontFamilyMono
                        font.pixelSize: Sizes.font.xsm
                        color: Colorscheme.on_surface
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: LianClawState.pendingConfirm
                             && LianClawState.pendingConfirm.reasons
                             && LianClawState.pendingConfirm.reasons.length > 0
                    text: {
                        if (!LianClawState.pendingConfirm
                            || !LianClawState.pendingConfirm.reasons) return "";
                        var rs = LianClawState.pendingConfirm.reasons;
                        var out = "";
                        for (var i = 0; i < rs.length; ++i) out += "• " + rs[i] + "\n";
                        return out.trim();
                    }
                    wrapMode: Text.Wrap
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.xsm
                    color: Colorscheme.on_surface_variant
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Sizes.spacing.s
                    spacing: Sizes.spacing.s
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredWidth: 84; Layout.preferredHeight: 30
                        radius: Sizes.rounding.medium
                        color: cancelMa.containsMouse
                               ? Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.10)
                               : "transparent"
                        border.color: Colorscheme.outline
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "拒绝"
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.sm
                            color: Colorscheme.on_surface
                        }
                        MouseArea {
                            id: cancelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LianClawState.confirmTool(false, "")
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 84; Layout.preferredHeight: 30
                        radius: Sizes.rounding.medium
                        color: okMa.containsMouse
                               ? Colorscheme.primary
                               : Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.88)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "允许"
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.sm
                            color: Colorscheme.on_primary
                            font.bold: true
                        }
                        MouseArea {
                            id: okMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LianClawState.confirmTool(true, "")
                        }
                    }
                }
            }
        }
    }

    // ===================== 表单对话框 =====================
    // 对应 SSE human/form_required，问题类型支持 single / multi / text。
    Rectangle {
        id: formOverlay
        anchors.fill: parent
        visible: LianClawState.pendingForm !== null
        color: Qt.rgba(0, 0, 0, 0.42)
        z: 100

        // 收集答案
        property var _single: ({})       // qid -> optionKey
        property var _multi:  ({})       // qid -> [optionKey,...]
        property var _text:   ({})       // qid -> text
        property var _note:   ({})       // qid -> 备注

        onVisibleChanged: {
            if (visible) {
                _single = {}; _multi = {}; _text = {}; _note = {};
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
            onWheel: function(w) { w.accepted = true; }
        }

        LcSurfaceCard {
            anchors.centerIn: parent
            width: Math.min(parent.width - Sizes.spacing.lg * 2, 380)
            implicitHeight: Math.min(parent.height - Sizes.spacing.lg * 2,
                                     formCol.implicitHeight + Sizes.spacing.md * 2)
            cardRadius: Sizes.rounding.xl
            cardOpacity: 0.98

            Flickable {
                anchors.fill: parent
                anchors.margins: Sizes.spacing.md
                contentHeight: formCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: LcThinScrollBar {}

                Column {
                    id: formCol
                    width: parent.width
                    spacing: Sizes.spacing.s

                    Row {
                        spacing: 6
                        Text {
                            text: "assignment"
                            font.family: Sizes.fontIcon
                            font.pixelSize: 18
                            color: Colorscheme.tertiary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: LianClawState.pendingForm
                                  ? (LianClawState.pendingForm.title || "请回答以下问题")
                                  : ""
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.lg
                            font.bold: true
                            color: Colorscheme.on_surface
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Repeater {
                        model: LianClawState.pendingForm
                               ? (LianClawState.pendingForm.questions || [])
                               : []
                        delegate: Column {
                            width: formCol.width
                            spacing: 4

                            property var q: modelData

                            Text {
                                width: parent.width
                                text: (index + 1) + ". " + (q.text || "(未命名问题)")
                                wrapMode: Text.Wrap
                                font.family: Sizes.fontFamily
                                font.pixelSize: Sizes.font.sm
                                color: Colorscheme.on_surface
                            }

                            // single
                            Column {
                                visible: q.type === "single"
                                width: parent.width
                                spacing: 2
                                Repeater {
                                    model: q.options || []
                                    delegate: Item {
                                        width: parent.width
                                        height: 24
                                        property var opt: modelData
                                        readonly property bool _checked:
                                            formOverlay._single[q.id] === opt.key
                                        Row {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6
                                            Rectangle {
                                                width: 14; height: 14; radius: 7
                                                color: "transparent"
                                                border.color: _checked ? Colorscheme.primary : Colorscheme.outline
                                                border.width: _checked ? 4 : 1
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: opt.label || opt.key
                                                font.family: Sizes.fontFamily
                                                font.pixelSize: Sizes.font.xsm
                                                color: Colorscheme.on_surface_variant
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var n = {};
                                                for (var k in formOverlay._single) n[k] = formOverlay._single[k];
                                                n[q.id] = opt.key;
                                                formOverlay._single = n;
                                            }
                                        }
                                    }
                                }
                            }

                            // multi
                            Column {
                                visible: q.type === "multi"
                                width: parent.width
                                spacing: 2
                                Repeater {
                                    model: q.options || []
                                    delegate: Item {
                                        width: parent.width
                                        height: 24
                                        property var opt: modelData
                                        readonly property bool _checked: {
                                            var arr = formOverlay._multi[q.id] || [];
                                            for (var i = 0; i < arr.length; ++i)
                                                if (arr[i] === opt.key) return true;
                                            return false;
                                        }
                                        Row {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6
                                            Rectangle {
                                                width: 14; height: 14; radius: 3
                                                color: _checked ? Colorscheme.primary : "transparent"
                                                border.color: _checked ? Colorscheme.primary : Colorscheme.outline
                                                border.width: 1
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text {
                                                    visible: _checked
                                                    anchors.centerIn: parent
                                                    text: "check"
                                                    font.family: Sizes.fontIcon
                                                    font.pixelSize: 12
                                                    color: Colorscheme.on_primary
                                                }
                                            }
                                            Text {
                                                text: opt.label || opt.key
                                                font.family: Sizes.fontFamily
                                                font.pixelSize: Sizes.font.xsm
                                                color: Colorscheme.on_surface_variant
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var arr = (formOverlay._multi[q.id] || []).slice();
                                                var hit = -1;
                                                for (var i = 0; i < arr.length; ++i)
                                                    if (arr[i] === opt.key) { hit = i; break; }
                                                if (hit >= 0) arr.splice(hit, 1); else arr.push(opt.key);
                                                var n = {};
                                                for (var k in formOverlay._multi) n[k] = formOverlay._multi[k];
                                                n[q.id] = arr;
                                                formOverlay._multi = n;
                                            }
                                        }
                                    }
                                }
                            }

                            // text
                            Rectangle {
                                visible: q.type === "text"
                                width: parent.width
                                height: 56
                                radius: Sizes.rounding.medium
                                color: Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.06)
                                TextArea {
                                    anchors.fill: parent
                                    background: null
                                    wrapMode: TextArea.Wrap
                                    font.family: Sizes.fontFamily
                                    font.pixelSize: Sizes.font.sm
                                    color: Colorscheme.on_surface
                                    placeholderText: "输入答案…"
                                    placeholderTextColor: Colorscheme.outline
                                    selectByMouse: true
                                    onTextChanged: {
                                        var n = {};
                                        for (var k in formOverlay._text) n[k] = formOverlay._text[k];
                                        n[q.id] = text;
                                        formOverlay._text = n;
                                    }
                                }
                            }

                            // 备注
                            Rectangle {
                                width: parent.width
                                height: 30
                                radius: Sizes.rounding.medium
                                color: Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.04)
                                TextField {
                                    anchors.fill: parent
                                    background: null
                                    leftPadding: 8; rightPadding: 8
                                    font.family: Sizes.fontFamily
                                    font.pixelSize: Sizes.font.xsm
                                    color: Colorscheme.on_surface_variant
                                    placeholderText: "备注（可选）"
                                    placeholderTextColor: Colorscheme.outline
                                    onTextChanged: {
                                        var n = {};
                                        for (var k in formOverlay._note) n[k] = formOverlay._note[k];
                                        n[q.id] = text;
                                        formOverlay._note = n;
                                    }
                                }
                            }
                        }
                    }

                    // 操作按钮
                    Row {
                        layoutDirection: Qt.RightToLeft
                        width: formCol.width
                        spacing: Sizes.spacing.s
                        Rectangle {
                            width: 84; height: 30
                            radius: Sizes.rounding.medium
                            color: submitMa.containsMouse
                                   ? Colorscheme.primary
                                   : Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.88)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                anchors.centerIn: parent
                                text: "提交"
                                font.family: Sizes.fontFamily
                                font.pixelSize: Sizes.font.sm
                                color: Colorscheme.on_primary
                                font.bold: true
                            }
                            MouseArea {
                                id: submitMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var form = LianClawState.pendingForm;
                                    if (!form) return;
                                    var answers = {};
                                    var qs = form.questions || [];
                                    for (var i = 0; i < qs.length; ++i) {
                                        var q = qs[i];
                                        if (q.type === "multi") {
                                            answers[q.id] = formOverlay._multi[q.id] || [];
                                        } else if (q.type === "text") {
                                            answers[q.id] = formOverlay._text[q.id] || "(未回答)";
                                        } else {
                                            answers[q.id] = formOverlay._single[q.id] || "(未回答)";
                                        }
                                        var note = (formOverlay._note[q.id] || "").trim();
                                        if (note.length > 0) answers[q.id + "_note"] = note;
                                    }
                                    LianClawState.submitForm(answers);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
