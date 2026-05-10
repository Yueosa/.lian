import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import Clavis.LianClaw

// 单条消息气泡：
//   * 流式期间：整段走 PlainText（Markdown 重解析会卡死主线程）
//   * 冻结后：把 text 切成 [text|code|image] 段，分别用 MarkdownText / Flickable
//     代码块 / Image 元素渲染。代码块支持横向滚动；图片走原生 Image，URL 中的
//     ()/+/空格 不会再被 CommonMark 截断。
Item {
    id: cell
    width: ListView.view ? ListView.view.width : implicitWidth

    // ---- delegate 字段 ----
    property string kind: "status"
    property string text: ""
    property bool   live: false
    property bool   frozen: false
    property string toolName: ""
    property string toolStatus: ""
    property string toolCallId: ""
    property string toolArgs: ""
    property string actionType: ""
    property string actionLabel: ""
    property string modelName: ""

    property bool _expanded: false
    property bool _layoutQueued: false

    readonly property bool isUser:     kind === "user"
    readonly property bool isReply:    kind === "reply"
    readonly property bool isThinking: kind === "thinking"
    readonly property bool isTool:     kind === "tool"
    readonly property bool isAction:   kind === "action"
    readonly property bool isError:    kind === "error"

    // 流式期间用单 PlainText 直显；落定后用切段渲染。
    readonly property bool _streamingPlain: live && (isReply || isThinking)

    Component.onCompleted: {
        if (isTool || isThinking || isAction) _expanded = live;
        if (!_streamingPlain) _rebuild();
    }
    onLiveChanged: {
        if (isTool || isThinking || isAction) _expanded = live;
        // 流式结束（live: true→false）才重新切段
        if (!_streamingPlain) {
            _rebuild();
            _scheduleLayout();
        }
    }
    onTextChanged: {
        // 流式期间不重建 segs（避免 Repeater 销毁/重建 delegate 导致卡死）
        if (_streamingPlain) return;
        _rebuild();
        _scheduleLayout();
    }

    function _scheduleLayout() {
        if (!ListView.view || _layoutQueued)
            return;
        _layoutQueued = true;
        Qt.callLater(function() {
            _layoutQueued = false;
            if (!ListView.view)
                return;
            ListView.view.forceLayout();
            if (cell.live || ListView.view.atYEnd)
                ListView.view.positionViewAtEnd();
        });
    }

    readonly property color bubbleBg: {
        if (isUser)  return Qt.rgba(Colorscheme.primary_container.r, Colorscheme.primary_container.g, Colorscheme.primary_container.b, 0.92);
        if (isError) return Qt.rgba(Colorscheme.error_container.r, Colorscheme.error_container.g, Colorscheme.error_container.b, 0.85);
        if (isThinking || isTool || isAction)
            return Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.05);
        return Qt.rgba(Colorscheme.surface_container_high.r, Colorscheme.surface_container_high.g, Colorscheme.surface_container_high.b, 0.85);
    }
    readonly property color bubbleFg: {
        if (isUser)  return Colorscheme.on_primary_container;
        if (isError) return Colorscheme.on_error_container;
        if (isThinking || isTool || isAction) return Colorscheme.on_surface_variant;
        return Colorscheme.on_surface;
    }
    readonly property color toolStatusColor: {
        if (toolStatus === "error") return Colorscheme.error;
        if (toolStatus === "done")  return Colorscheme.primary;
        return Colorscheme.tertiary;
    }

    readonly property real maxBubbleW: cell.width * (isUser ? 0.84 : 0.97)
    readonly property real innerPad: 11
    readonly property real bodyW: maxBubbleW - innerPad * 2

    readonly property string bodyFamily: "Noto Sans CJK SC"
    readonly property string monoFamily: "Noto Sans Mono CJK SC"
    readonly property bool _hasRichSegs: {
        for (let i = 0; i < _segs.length; ++i) {
            const seg = _segs[i];
            if (seg.t !== "text" && seg.t !== "user")
                return true;
        }
        return false;
    }
    readonly property bool _frozenPlainText: !cell._streamingPlain
                                            && (cell.isReply || cell.isError || cell.isUser)
                                            && !cell._hasRichSegs
                                            && !cell._usesMarkdown(cell.text)

    implicitHeight: bubble.implicitHeight + 4

    // ============ 段拆分 ============
    property var _segs: []

    function _resolveLocalPath(raw) {
        if (!raw) return null;
        if (raw.indexOf("http://") === 0 || raw.indexOf("https://") === 0) return null;
        if (raw.indexOf("file://") === 0) {
            try { return decodeURIComponent(raw.substring(7)); } catch (e) { return null; }
        }
        if (raw.charAt(0) === "/" && raw.indexOf("//") !== 0) {
            if (raw.indexOf("/local-image") === 0 || raw.indexOf("/api/") === 0) return null;
            try { return decodeURIComponent(raw); } catch (e) { return raw; }
        }
        if (raw.length > 1 && raw.charAt(0) === "~" && raw.charAt(1) === "/") {
            try { return decodeURIComponent(raw); } catch (e) { return raw; }
        }
        return null;
    }

    function _splitImages(s, out) {
        // 支持 ![](url)、![](<url>)、![](url "title")
        var re = /!\[([^\]]*)\]\(\s*<?([^>)\s]+)>?(?:\s+"[^"]*")?\s*\)/g;
        var li = 0, m;
        while ((m = re.exec(s)) !== null) {
            if (m.index > li) out.push({ t: "text", s: s.substring(li, m.index) });
            var raw = m[2];
            var path = _resolveLocalPath(raw);
            var url = raw;
            if (path && LianClawClient.serverReady) {
                var thumb = Math.max(64, Math.floor(bodyW * 2));
                var u = LianClawClient.imageProxyUrl(path, thumb);
                if (u) url = u;
            }
            out.push({ t: "img", alt: m[1], url: url });
            li = re.lastIndex;
        }
        if (li < s.length) out.push({ t: "text", s: s.substring(li) });
    }

    function _rebuild() {
        if (!isReply && !isTool && !isError && !isAction && !isThinking) {
            _segs = [{ t: "text", s: text || "" }];
            return;
        }
        if (_streamingPlain) {
            // 流式期间走独立 _liveText，_segs 保持不动避免 Repeater rebind
            _segs = [];
            return;
        }
        var src = text || "";
        var out = [];
        var fenceRe = /```([^\n`]*)\n([\s\S]*?)```/g;
        var li = 0, m;
        while ((m = fenceRe.exec(src)) !== null) {
            if (m.index > li) _splitImages(src.substring(li, m.index), out);
            out.push({ t: "code", lang: (m[1] || "").trim(), s: m[2] });
            li = fenceRe.lastIndex;
        }
        if (li < src.length) _splitImages(src.substring(li), out);
        _segs = out;
    }

    function _usesMarkdown(textValue) {
        const source = textValue || "";
        if (!source)
            return false;
        return /```|`[^`]+`|!\[[^\]]*\]\(|\[[^\]]+\]\([^\)]+\)|^\s{0,3}(#{1,6}|[-*+] |\d+\. |>)/m.test(source);
    }

    Rectangle {
        id: bubble
        anchors.right: cell.isUser ? parent.right : undefined
        anchors.left:  cell.isUser ? undefined    : parent.left
        width: cell.maxBubbleW
        implicitHeight: contentCol.implicitHeight + cell.innerPad * 2
        radius: Sizes.rounding.large
        color: cell.bubbleBg
        clip: true

        Column {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: cell.innerPad
            anchors.rightMargin: cell.innerPad
            anchors.topMargin: cell.innerPad
            spacing: 4

            // ----- 折叠头：thinking / tool / action -----
            Item {
                visible: cell.isThinking || cell.isTool || cell.isAction
                width: parent.width
                height: 20

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cell._expanded = !cell._expanded
                }

                Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: cell._expanded ? "expand_more" : "chevron_right"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: cell.bubbleFg
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: cell.isTool ? "build"
                              : (cell.isAction ? "auto_awesome" : "psychology")
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 14
                        color: cell.isTool ? cell.toolStatusColor
                              : (cell.isAction ? Colorscheme.tertiary : cell.bubbleFg)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: {
                            if (cell.isTool) {
                                var s = cell.toolName || "tool";
                                if (cell.toolStatus === "running") return s + " · 运行中…";
                                if (cell.toolStatus === "error")   return s + " · 失败";
                                return s;
                            }
                            if (cell.isAction) return cell.actionLabel || cell.actionType || "action";
                            return cell.live ? "思考中…" : "内部思考";
                        }
                        font.family: cell.bodyFamily
                        font.pixelSize: Sizes.font.xsm
                        font.bold: cell.isTool || cell.isAction
                        color: cell.bubbleFg
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // tool args 折叠时一行预览
            Text {
                visible: cell.isTool && !cell._expanded && cell.toolArgs.length > 0
                width: parent.width
                text: cell.toolArgs
                color: Colorscheme.on_surface_variant
                font.family: cell.monoFamily
                font.pixelSize: Sizes.font.xs
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // tool args 展开时全文
            Rectangle {
                visible: cell.isTool && cell._expanded && cell.toolArgs.length > 0
                width: parent.width
                radius: Sizes.rounding.medium
                color: Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.06)
                implicitHeight: argsText.implicitHeight + 12
                Text {
                    id: argsText
                    anchors.fill: parent
                    anchors.margins: 6
                    text: cell.toolArgs
                    wrapMode: Text.Wrap
                    color: Colorscheme.on_surface_variant
                    font.family: cell.monoFamily
                    font.pixelSize: Sizes.font.xs
                }
            }

            // 主文本：直接坐在 Column 里。一条 Text 同时承载流式与冻结两种状态：
            //   * live=true 或 不含 markdown ⇒ PlainText（避免 MarkdownText 在
            //     不完整 token / 流式中间产生的卡顿）
            //   * 冻结后且包含 markdown 标记 ⇒ MarkdownText
            // 折叠态（thinking/tool/action 未展开）下不显示。
            Text {
                id: mainText
                visible: !cell._hasRichSegs
                         && (cell.isUser || cell.isReply || cell.isError
                             || ((cell.isThinking || cell.isTool || cell.isAction) && cell._expanded))
                width: cell.bodyW
                text: cell.text || ""
                color: cell.bubbleFg
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                textFormat: (!cell.live && cell._usesMarkdown(cell.text))
                            ? Text.MarkdownText
                            : Text.PlainText
                font.family: cell.bodyFamily
                font.italic: cell.isThinking
                font.pixelSize: cell.isThinking ? Sizes.font.xsm
                                : (cell.isAction ? Sizes.font.xsm : Sizes.font.md)
                linkColor: Colorscheme.primary
                onLinkActivated: function(link) { Qt.openUrlExternally(link); }
                onImplicitHeightChanged: cell._scheduleLayout()
            }

            // rich 段（代码块 / 图片）：仅当 _hasRichSegs 为 true 时启用，
            // 此时 mainText 已隐藏，所有内容都从 _segs 渲染。
            Column {
                id: richBody
                visible: cell._hasRichSegs
                width: cell.bodyW
                spacing: 4

                Repeater {
                    model: cell._hasRichSegs ? cell._segs : []

                    delegate: Item {
                        id: segItem
                        width: cell.bodyW
                        implicitHeight: {
                            if (modelData.t === "img")  return imgEl.height;
                            if (modelData.t === "code") return codeBox.implicitHeight;
                            return txtEl.implicitHeight;
                        }
                        // Column 定位器用 height 排版，Item 默认 height=0 会被 bubble.clip 裁掉
                        height: implicitHeight

                        Text {
                            id: txtEl
                            visible: modelData.t === "text" || modelData.t === "user"
                            width: parent.width
                            text: modelData.s || ""
                            color: cell.bubbleFg
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                            textFormat: modelData.t === "user" || !cell._usesMarkdown(modelData.s)
                                        ? Text.PlainText
                                        : Text.MarkdownText
                            font.family: cell.bodyFamily
                            font.italic: cell.isThinking
                            font.pixelSize: cell.isThinking ? Sizes.font.xsm
                                            : (cell.isAction ? Sizes.font.xsm : Sizes.font.md)
                            linkColor: Colorscheme.primary
                            onLinkActivated: function(link) { Qt.openUrlExternally(link); }
                            onImplicitHeightChanged: cell._scheduleLayout()
                        }

                        Rectangle {
                            id: codeBox
                            visible: modelData.t === "code"
                            width: parent.width
                            radius: Sizes.rounding.medium
                            color: Qt.rgba(0, 0, 0, 0.22)
                            border.width: 1
                            border.color: Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.08)
                            implicitHeight: codeFlick.height + 12

                            Flickable {
                                id: codeFlick
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                height: Math.min(codeText.implicitHeight, 360)
                                contentWidth: codeText.implicitWidth
                                contentHeight: codeText.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.HorizontalAndVerticalFlick
                                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded; height: 6 }
                                ScrollBar.vertical:   ScrollBar { policy: ScrollBar.AsNeeded; width:  6 }

                                Text {
                                    id: codeText
                                    text: modelData.s || ""
                                    color: cell.bubbleFg
                                    textFormat: Text.PlainText
                                    font.family: cell.monoFamily
                                    font.pixelSize: Sizes.font.sm
                                    wrapMode: Text.NoWrap
                                    onImplicitHeightChanged: cell._scheduleLayout()
                                }
                            }
                        }

                        Image {
                            id: imgEl
                            visible: modelData.t === "img"
                            width: parent.width
                            fillMode: Image.PreserveAspectFit
                            source: modelData.url || ""
                            asynchronous: true
                            cache: true
                            sourceSize.width: Math.max(128, Math.floor(cell.bodyW * 2))
                            height: status === Image.Ready
                                    ? Math.min(implicitHeight, 480)
                                    : (status === Image.Loading ? 80 : 24)
                            onStatusChanged: cell._scheduleLayout()

                            Rectangle {
                                anchors.centerIn: parent
                                visible: imgEl.status === Image.Loading
                                width: 28; height: 28
                                radius: 14
                                color: "transparent"
                                border.width: 2
                                border.color: Colorscheme.primary
                                opacity: 0.5
                                RotationAnimation on rotation {
                                    running: imgEl.status === Image.Loading
                                    from: 0; to: 360; duration: 900
                                    loops: Animation.Infinite
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: imgEl.status === Image.Error
                                text: "图片加载失败"
                                color: Colorscheme.error
                                font.family: cell.bodyFamily
                                font.pixelSize: Sizes.font.xs
                            }
                        }
                    }
                }
            }

            // 流式光标
            Rectangle {
                visible: cell.live && cell.isReply && (cell.text || "").length > 0
                width: 6; height: 12
                radius: 1
                color: Colorscheme.primary
                opacity: 1.0
                SequentialAnimation on opacity {
                    running: cell.live && cell.isReply
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }
        }
    }
}
