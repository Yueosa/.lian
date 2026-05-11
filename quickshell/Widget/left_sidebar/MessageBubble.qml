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
    property bool _finalRenderQueued: false

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
        if (!_streamingPlain) _queueFinalRender();
    }
    onLiveChanged: {
        if (isTool || isThinking || isAction) _expanded = live;
        // 流式结束（live: true→false）才重新切段
        if (!live) _queueFinalRender();
    }
    onFrozenChanged: {
        if (frozen && !live) _queueFinalRender();
    }
    onTextChanged: {
        // 流式期间不重建 segs（避免 Repeater 销毁/重建 delegate 导致卡死）
        if (_streamingPlain) return;
        _queueFinalRender();
    }
    onWidthChanged: {
        if (!_streamingPlain) _queueFinalRender();
    }

    function _queueFinalRender() {
        if (_streamingPlain || _finalRenderQueued)
            return;
        _finalRenderQueued = true;
        Qt.callLater(function() {
            _finalRenderQueued = false;
            if (_streamingPlain)
                return;
            _rebuild();
            _scheduleLayout();
        });
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
        // 稳健解析 ![alt](...)：支持 <url>、带 title、以及 URL 中出现括号。
        var i = 0;
        var li = 0;
        while (i < s.length) {
            var bang = s.indexOf("![", i);
            if (bang < 0)
                break;

            var altEnd = s.indexOf("]", bang + 2);
            if (altEnd < 0) {
                i = bang + 2;
                continue;
            }

            var p = altEnd + 1;
            while (p < s.length && /\s/.test(s.charAt(p)))
                p += 1;
            if (p >= s.length || s.charAt(p) !== "(") {
                i = altEnd + 1;
                continue;
            }

            var start = p + 1;
            var depth = 1;
            p = start;
            while (p < s.length && depth > 0) {
                var ch = s.charAt(p);
                if (ch === "\\") {
                    p += 2;
                    continue;
                }
                if (ch === "(") depth += 1;
                else if (ch === ")") depth -= 1;
                p += 1;
            }
            if (depth !== 0) {
                i = altEnd + 1;
                continue;
            }

            if (bang > li)
                out.push({ t: "text", s: s.substring(li, bang) });

            var alt = s.substring(bang + 2, altEnd);
            var inner = s.substring(start, p - 1).trim();
            var raw = inner;
            if (inner.length > 0 && inner.charAt(0) === "<") {
                var gt = inner.indexOf(">");
                if (gt > 1)
                    raw = inner.substring(1, gt);
            } else {
                // 末尾 title 仅在存在空格+引号时剥离，避免把普通 URL 匹配成空串。
                var titleMatch = inner.match(/^(.*)\s+"[^"]*"\s*$/);
                raw = (titleMatch ? titleMatch[1] : inner).trim();
            }

            if (raw.length > 1 && ((raw.charAt(0) === '"' && raw.charAt(raw.length - 1) === '"') || (raw.charAt(0) === "'" && raw.charAt(raw.length - 1) === "'")))
                raw = raw.substring(1, raw.length - 1);

            // 解析失败时保留原 markdown 文本，避免整段被吞掉导致“消息不渲染”。
            if (!raw || raw.length === 0) {
                out.push({ t: "text", s: s.substring(bang, p) });
                li = p;
                i = p;
                continue;
            }

            var path = _resolveLocalPath(raw);
            var url = raw;
            if (path && LianClawClient.serverReady) {
                var thumb = Math.max(64, Math.floor(bodyW * 2));
                var u = LianClawClient.imageProxyUrl(path, thumb);
                if (u) url = u;
            }
            out.push({ t: "img", alt: alt, url: url });

            li = p;
            i = p;
        }

        if (li < s.length)
            out.push({ t: "text", s: s.substring(li) });
    }

    function _splitInlineCodeAware(s, out) {
        // 先识别 backtick 包裹区间，避免其中的 ![]() 被当作图片语法。
        var i = 0;
        var plainStart = 0;

        while (i < s.length) {
            if (s.charAt(i) !== "`") {
                i += 1;
                continue;
            }

            var ticks = 1;
            while (i + ticks < s.length && s.charAt(i + ticks) === "`")
                ticks += 1;

            var search = i + ticks;
            var close = -1;

            while (search < s.length) {
                var n = s.indexOf("`", search);
                if (n < 0)
                    break;

                var run = 1;
                while (n + run < s.length && s.charAt(n + run) === "`")
                    run += 1;

                if (run === ticks) {
                    close = n;
                    break;
                }

                search = n + run;
            }

            if (close < 0) {
                i += ticks;
                continue;
            }

            if (i > plainStart)
                _splitImages(s.substring(plainStart, i), out);

            var codeText = s.substring(i + ticks, close);
            var isBlock = ticks >= 2;

            if (isBlock)
                out.push({ t: "code", lang: "", s: codeText });
            else
                out.push({ t: "text", s: s.substring(i, close + ticks) });

            i = close + ticks;
            plainStart = i;
        }

        if (plainStart < s.length)
            _splitImages(s.substring(plainStart), out);
    }

    function _escapeHtml(raw) {
        var s = String(raw || "");
        return s
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;");
    }

    function _escapeHtmlWithBreaks(raw) {
        return _escapeHtml(raw).replace(/\n/g, "<br/>");
    }

    function _cssRgba(colorObj, alpha) {
        var a = (alpha === undefined) ? 1.0 : Math.max(0, Math.min(1, Number(alpha)));
        var r = Math.max(0, Math.min(255, Math.round(colorObj.r * 255)));
        var g = Math.max(0, Math.min(255, Math.round(colorObj.g * 255)));
        var b = Math.max(0, Math.min(255, Math.round(colorObj.b * 255)));
        return "rgba(" + r + "," + g + "," + b + "," + a.toFixed(3) + ")";
    }

    function _hasBacktickSyntax(textValue) {
        return String(textValue || "").indexOf("`") >= 0;
    }

    function _containsImageMarkdown(textValue) {
        return /!\[[^\]]*\]\(/.test(textValue || "");
    }

    function _renderInlineCodeRichText(textValue) {
        var src = String(textValue || "");
        var i = 0;
        var html = "";
        var codeBg = _cssRgba(Colorscheme.on_surface, 0.12);
        var codeFg = _cssRgba(cell.bubbleFg, 1.0);

        while (i < src.length) {
            var tickAt = src.indexOf("`", i);
            if (tickAt < 0) {
                html += _escapeHtmlWithBreaks(src.substring(i));
                break;
            }

            html += _escapeHtmlWithBreaks(src.substring(i, tickAt));

            var ticks = 1;
            while (tickAt + ticks < src.length && src.charAt(tickAt + ticks) === "`")
                ticks += 1;

            var search = tickAt + ticks;
            var close = -1;

            while (search < src.length) {
                var n = src.indexOf("`", search);
                if (n < 0)
                    break;

                var run = 1;
                while (n + run < src.length && src.charAt(n + run) === "`")
                    run += 1;

                if (run === ticks) {
                    close = n;
                    break;
                }

                search = n + run;
            }

            if (close < 0) {
                html += _escapeHtmlWithBreaks(src.substring(tickAt, tickAt + ticks));
                i = tickAt + ticks;
                continue;
            }

            var codeText = src.substring(tickAt + ticks, close);
            html += "<span style=\"font-family:'" + Sizes.fontFamilyMonoCJK
                 + "'; background-color:" + codeBg
                 + "; color:" + codeFg
                 + ";\">"
                 + _escapeHtmlWithBreaks(codeText)
                 + "</span>";

            i = close + ticks;
        }

        return "<div style=\"white-space:pre-wrap;\">" + html + "</div>";
    }

    function _textFormatForSegment(textValue, forcePlain) {
        var src = textValue || "";
        if (forcePlain)
            return Text.PlainText;
        if (_hasBacktickSyntax(src))
            return Text.RichText;
        if (_containsImageMarkdown(src))
            return Text.PlainText;
        return _usesMarkdown(src) ? Text.MarkdownText : Text.PlainText;
    }

    function _textContentForSegment(textValue, forcePlain) {
        var src = textValue || "";
        if (!forcePlain && _hasBacktickSyntax(src))
            return _renderInlineCodeRichText(src);
        return src;
    }

    function _rebuild() {
        if (!isUser && !isReply && !isTool && !isError && !isAction && !isThinking) {
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
            if (m.index > li) _splitInlineCodeAware(src.substring(li, m.index), out);
            out.push({ t: "code", lang: (m[1] || "").trim(), s: m[2] });
            li = fenceRe.lastIndex;
        }
        if (li < src.length) _splitInlineCodeAware(src.substring(li), out);
        _segs = out;
    }

    function _usesMarkdown(textValue) {
        const source = textValue || "";
        if (!source)
            return false;
        return /!\[[^\]]*\]\(|\[[^\]]+\]\([^\)]+\)|^\s{0,3}(#{1,6}|[-*+] |\d+\. |>)/m.test(source);
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
                        font.family: Sizes.fontIcon
                        font.pixelSize: 16
                        color: cell.bubbleFg
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: cell.isTool ? "build"
                              : (cell.isAction ? "auto_awesome" : "psychology")
                        font.family: Sizes.fontIcon
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
                        font.family: Sizes.fontFamily
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
                font.family: Sizes.fontFamilyMonoCJK
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
                    font.family: Sizes.fontFamilyMonoCJK
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
                text: cell._textContentForSegment(cell.text || "", false)
                color: cell.bubbleFg
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                textFormat: cell.live
                            ? Text.PlainText
                            : cell._textFormatForSegment(cell.text || "", false)
                font.family: Sizes.fontFamily
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
                         && (cell.isUser || cell.isReply || cell.isError
                             || ((cell.isThinking || cell.isTool || cell.isAction) && cell._expanded))
                width: cell.bodyW
                spacing: 4

                Repeater {
                    model: cell._hasRichSegs ? cell._segs : []

                    delegate: Item {
                        id: segItem
                        width: cell.bodyW
                        implicitHeight: {
                            if (modelData.t === "img")  return imgWrap.height;
                            if (modelData.t === "code") return codeBox.implicitHeight;
                            return txtEl.implicitHeight;
                        }
                        // Column 定位器用 height 排版，Item 默认 height=0 会被 bubble.clip 裁掉
                        height: implicitHeight

                        Text {
                            id: txtEl
                            visible: modelData.t === "text" || modelData.t === "user"
                            width: parent.width
                            text: cell._textContentForSegment(modelData.s || "", modelData.t === "user")
                            color: cell.bubbleFg
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                            textFormat: cell._textFormatForSegment(modelData.s || "", modelData.t === "user")
                            font.family: Sizes.fontFamily
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
                                    font.family: Sizes.fontFamilyMonoCJK
                                    font.pixelSize: Sizes.font.sm
                                    wrapMode: Text.NoWrap
                                    onImplicitHeightChanged: cell._scheduleLayout()
                                }
                            }
                        }

                        Rectangle {
                            id: imgWrap
                            visible: modelData.t === "img"
                            width: parent.width
                            radius: Sizes.rounding.medium
                            color: Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.08)
                            clip: true
                            readonly property real minH: 96
                            readonly property real maxH: Math.max(220, Math.floor(cell.bodyW * 1.25))
                            readonly property real readyH: {
                                const sw = imgEl.implicitWidth;
                                const sh = imgEl.implicitHeight;
                                if (imgEl.status !== Image.Ready || sw <= 0 || sh <= 0)
                                    return minH;
                                const innerW = Math.max(1, width - 12);
                                const scaled = innerW * sh / sw + 12;
                                return Math.max(minH, Math.min(maxH, scaled));
                            }
                            height: imgEl.status === Image.Ready
                                    ? readyH
                                    : (imgEl.status === Image.Loading ? 80 : 56)

                            Image {
                                id: imgEl
                                anchors.fill: parent
                                anchors.margins: 6
                                fillMode: Image.PreserveAspectFit
                                source: modelData.url || ""
                                asynchronous: true
                                cache: true
                                sourceSize.width: Math.max(128, Math.floor(cell.bodyW * 2))
                                onStatusChanged: cell._scheduleLayout()
                                onImplicitWidthChanged: cell._scheduleLayout()
                                onImplicitHeightChanged: cell._scheduleLayout()
                            }

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
                                font.family: Sizes.fontFamily
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
