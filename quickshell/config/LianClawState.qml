pragma Singleton
import QtQuick
import Quickshell
import Clavis.LianClaw 1.0

// 全局会话状态。基于 Clavis.LianClaw.LianClawClient 做 RPC 编排。
//
// blocks 是 ListModel —— 增量更新只 setProperty 一行，避免 ListView 整表 rebind
// （webui 用 currentReplyIdx 同义）。
QtObject {
    id: root

    // ---------- 会话列表 ----------
    property var sessions: []
    property bool sessionsLoading: false
    property string sessionsError: ""

    // ---------- 当前会话 ----------
    property string currentSid: ""
    property var currentMeta: ({})
    property var currentRuntime: ({})
    property bool sessionLoading: false
    property string sessionError: ""

    readonly property string currentModeChoice: (currentRuntime && currentRuntime.mode_choice) ? String(currentRuntime.mode_choice) : ""
    readonly property string currentWorkMode:   (currentMeta    && currentMeta.work_mode)     ? String(currentMeta.work_mode)     : ""
    readonly property bool   currentIsArchived: (currentMeta    && currentMeta.status === "archived")

    // ---------- 历史与消息块 ----------
    property ListModel blocks: ListModel {}
    property bool historyLoading: false
    property bool hasMoreHistory: false
    property int historyTotal: 0

    // ---------- 流状态 ----------
    property string activeIntentId: ""
    property string streamPhase: ""
    property string streamModel: ""
    property string lastStreamError: ""

    // ---------- 工具 / 表单 ----------
    property var pendingConfirm: null
    property var pendingForm: null

    // 内部增量索引
    property int _liveReplyIdx: -1
    property int _liveThinkingIdx: -1
    property int _liveActionIdx: -1
    property int _lastEnvelopeSeq: 0
    property var _toolIdxMap: ({})
    property string _liveIntentId: ""

    // ---------- 行为标签（与 webui chatActionLabels 同步） ----------
    readonly property var _actionLabel: ({
        memory: "正在回忆", transcript: "正在检索", delegate: "正在委派",
        query_status: "正在查询", create_plan: "正在规划", modify_plan: "正在调整",
        spawn_worker: "正在分配", interrupt: "正在中断", report: "正在汇报",
        abort_plan: "正在终止", done: "正在总结", failed: "正在报错",
        compact: "正在压缩对话",
        __confirm: "正在请求协助", __form: "正在请求填写表单"
    })
    readonly property var _actionDoneLabel: ({
        memory: "回忆完成", transcript: "检索完成", delegate: "委派完成",
        query_status: "查询完成", create_plan: "规划完成", modify_plan: "调整完成",
        spawn_worker: "分配完成", interrupt: "已中断", report: "汇报完成",
        abort_plan: "已终止", done: "已总结", failed: "执行失败",
        compact: "压缩完成",
        __confirm: "协助请求", __form: "请填写表单"
    })

    // ============================================================
    //                       工具函数
    // ============================================================
    function _uuid() {
        function h(n) { var s = ""; for (var i = 0; i < n; ++i) s += Math.floor(Math.random()*16).toString(16); return s; }
        return h(8) + "-" + h(4) + "-4" + h(3) + "-" + (8 + Math.floor(Math.random()*4)).toString(16) + h(3) + "-" + h(12);
    }

    function _defaultRow() {
        return {
            key: "", kind: "status", text: "",
            live: false, frozen: false,
            toolName: "", toolStatus: "", toolCallId: "", toolArgs: "",
            actionType: "", actionLabel: "",
            intentId: "", modelName: "", msgId: -1
        };
    }
    function _row(over) {
        var r = _defaultRow();
        if (over) for (var k in over) r[k] = over[k];
        return r;
    }

    // ============================================================
    //                       RPC: 会话列表
    // ============================================================
    function refreshSessions() {
        if (!LianClawClient.serverReady) LianClawClient.resolveServerBase();
        sessionsLoading = true;
        sessionsError = "";
        LianClawClient.request("lc:sessions", "GET", "/sessions?status=all");
    }

    function enterSession(sid) {
        if (!sid || sid === currentSid) return;
        currentSid = sid;
        currentMeta = {};
        currentRuntime = {};
        blocks.clear();
        historyTotal = 0;
        hasMoreHistory = false;
        sessionLoading = true;
        sessionError = "";
        pendingConfirm = null;
        pendingForm = null;
        LianClawClient.closeStream();
        _resetLiveState();
        LianClawClient.request("lc:meta:" + sid, "GET", "/sessions/" + sid);
        LianClawClient.request("lc:runtime:" + sid, "GET", "/sessions/" + sid + "/runtime");
        LianClawClient.request("lc:history:" + sid, "GET",
                               "/sessions/" + sid + "/history?limit=50&offset=0");
    }

    function createSession(title) {
        var body = {};
        if (title && title.length) body.title = title;
        LianClawClient.request("lc:create", "POST", "/sessions", body);
    }
    function renameSession(sid, newTitle) {
        if (!sid || !newTitle) return;
        LianClawClient.request("lc:rename:" + sid, "PUT", "/sessions/" + sid, { title: newTitle });
    }
    function deleteSession(sid) {
        if (!sid) return;
        LianClawClient.request("lc:delete:" + sid, "DELETE", "/sessions/" + sid);
    }
    function setModeChoice(sid, choice) {
        if (!sid || (choice !== "fast" && choice !== "deep")) return;
        var rt = {};
        var src = currentRuntime || {};
        for (var k in src) rt[k] = src[k];
        rt.mode_choice = choice;
        currentRuntime = rt;
        LianClawClient.request("lc:mode:" + sid, "PUT",
                               "/sessions/" + sid + "/mode-choice",
                               { choice: choice });
    }
    function setWorkMode(sid, mode) {
        if (!sid) return;
        var m = {};
        var src2 = currentMeta || {};
        for (var k2 in src2) m[k2] = src2[k2];
        m.work_mode = mode;
        currentMeta = m;
        LianClawClient.request("lc:wmode:" + sid, "PUT",
                               "/sessions/" + sid + "/work-mode",
                               { work_mode: mode });
    }

    function sendMessage(text) {
        if (!currentSid) return false;
        if (!text || !text.trim()) return false;
        if (currentIsArchived) return false;
        if (activeIntentId !== "") return false;
        var t = text;
        var cmid = _uuid();
        blocks.append(_row({
            key: "u:" + cmid, kind: "user", text: t, frozen: true
        }));
        streamPhase = "accepted";
        LianClawClient.request("lc:send:" + currentSid, "POST",
                               "/sessions/" + currentSid + "/messages",
                               { message: t, client_message_id: cmid });
        return true;
    }
    function cancelStream() {
        if (!currentSid) return;
        if (activeIntentId === "" && streamPhase === "") return;
        LianClawClient.request("lc:cancel:" + currentSid, "POST",
                               "/sessions/" + currentSid + "/cancel", {});
    }
    function retryLast() {
        if (!currentSid) return;
        if (activeIntentId !== "") return;
        LianClawClient.request("lc:retry:" + currentSid, "POST",
                               "/sessions/" + currentSid + "/retry", {});
    }

    function confirmTool(approved, feedback) {
        if (!currentSid || !pendingConfirm) return;
        var body = {
            confirmation_id: pendingConfirm.confirmation_id,
            approved: !!approved
        };
        if (feedback && feedback.length) body.feedback = feedback;
        LianClawClient.request("lc:confirm:" + currentSid, "POST",
                               "/sessions/" + currentSid + "/confirm", body);
        pendingConfirm = null;
    }
    function submitForm(answers) {
        if (!currentSid || !pendingForm) return;
        LianClawClient.request("lc:form:" + currentSid, "POST",
                               "/sessions/" + currentSid + "/form_response",
                               { form_id: pendingForm.form_id, answers: answers || {} });
        pendingForm = null;
    }

    // ============================================================
    //                       内部：history → blocks
    // ============================================================
    function _appendHistory(messages) {
        if (!messages) return;
        // 收集 assistant.tool_calls 用于补 tool 行的 args
        var toolArgs = {};
        for (var ai = 0; ai < messages.length; ++ai) {
            var am = messages[ai];
            if (am.role === "assistant" && am.tool_calls) {
                for (var ti = 0; ti < am.tool_calls.length; ++ti) {
                    var tc = am.tool_calls[ti];
                    if (tc && tc.id) toolArgs[tc.id] = tc;
                }
            }
        }
        for (var i = 0; i < messages.length; ++i) {
            var m = messages[i];
            var mid = (m._msg_id !== undefined) ? Number(m._msg_id) : -1;
            var keyBase = "h" + (mid >= 0 ? mid : i);
            if (m.role === "user") {
                blocks.append(_row({
                    key: keyBase, kind: "user", text: m.content || "",
                    frozen: true, msgId: mid
                }));
            } else if (m.role === "assistant") {
                if (m.thinking && m.thinking.length > 0) {
                    blocks.append(_row({
                        key: keyBase + ":t", kind: "thinking", text: m.thinking,
                        frozen: true, msgId: mid
                    }));
                }
                if (m.content && m.content.length > 0) {
                    blocks.append(_row({
                        key: keyBase + ":r", kind: "reply",
                        text: m.content,
                        frozen: true, msgId: mid
                    }));
                }
            } else if (m.role === "tool") {
                var argHint = "";
                var name = m.name || "tool";
                if (m.tool_call_id && toolArgs[m.tool_call_id]) {
                    var tcref = toolArgs[m.tool_call_id];
                    if (tcref.function && tcref.function.name) name = tcref.function.name;
                    if (tcref.function && tcref.function.arguments) {
                        argHint = String(tcref.function.arguments).replace(/\s+/g, " ").substring(0, 120);
                    }
                }
                blocks.append(_row({
                    key: keyBase + ":tool", kind: "tool",
                    text: m.content || "",
                    frozen: true, msgId: mid,
                    toolName: name,
                    toolStatus: "done",
                    toolCallId: m.tool_call_id || "",
                    toolArgs: argHint
                }));
            } else if (m.role === "system") {
                // 解析 [action:NAME] 前缀
                var c = String(m.content || "");
                var ma = c.match(/^\[action:(\w+)\]\s*([\s\S]*)/);
                if (ma) {
                    var act = ma[1];
                    blocks.append(_row({
                        key: keyBase + ":act", kind: "action",
                        text: ma[2] || "",
                        frozen: true, msgId: mid,
                        actionType: act,
                        actionLabel: _actionDoneLabel[act] || act
                    }));
                }
            }
        }
    }

    function _resetLiveState() {
        _liveReplyIdx = -1;
        _liveThinkingIdx = -1;
        _liveActionIdx = -1;
        _lastEnvelopeSeq = 0;
        _toolIdxMap = {};
        _liveIntentId = "";
        activeIntentId = "";
        streamPhase = "";
        streamModel = "";
    }

    // ============================================================
    //                       SSE envelope 处理
    // ============================================================
    function _onEnvelope(env) {
        if (!env) return;
        if (currentSid && env.session_id && env.session_id !== currentSid) return;
        var seq = Number(env.seq || -1);
        if (seq >= 0) {
            if (seq <= _lastEnvelopeSeq)
                return;
            _lastEnvelopeSeq = seq;
        }
        var dom = env.domain || "";
        var typ = env.type || "";
        var data = env.data || {};

        if (dom === "control") {
            if (typ === "intent_accepted") {
                _liveIntentId = data.intent_id || "";
                activeIntentId = _liveIntentId;
                streamPhase = "accepted";
                _liveReplyIdx = -1;
                _liveThinkingIdx = -1;
                _liveActionIdx = -1;
            } else if (typ === "intent_processing") {
                streamPhase = "processing";
            } else if (typ === "intent_completed" || typ === "intent_done") {
                streamPhase = "completed";
                _freezeLive();
                activeIntentId = "";
            } else if (typ === "intent_failed") {
                streamPhase = "error";
                lastStreamError = (data && data.error) || "intent failed";
                _freezeLive();
                activeIntentId = "";
            } else if (typ === "intent_cancelled") {
                streamPhase = "completed";
                _freezeLive();
                activeIntentId = "";
            }
        } else if (dom === "agent") {
            if (typ === "context_ready") {
                streamPhase = "context_ready";
            } else if (typ === "llm_start") {
                streamPhase = "llm";
                streamModel = data.model || "";
            } else if (typ === "turn_end") {
                _freezeLive();
            } else if (typ === "compact_start") {
                _pushAction("compact", _actionLabel.compact, /*live*/ true);
            } else if (typ === "round_end") {
                // round 结束：把当前 live action 标完成
                _freezeAction();
            } else if (typ === "action_start") {
                var actName = data.action || data.name || "action";
                _pushAction(actName, _actionLabel[actName] || actName, true);
            } else if (typ === "action_result") {
                var actName2 = data.action || data.name || "action";
                _resolveAction(actName2, data.summary || "");
            }
        } else if (dom === "llm") {
            if (typ === "thinking") {
                _appendThinking(data.text || "");
            } else if (typ === "delta") {
                _appendDelta(data.text || "");
            }
        } else if (dom === "tool") {
            if (typ === "call") {
                _onToolCall(data);
            } else if (typ === "result") {
                _onToolResult(data);
            } else if (typ === "confirm_required") {
                pendingConfirm = data;
            } else if (typ === "confirm_resolved") {
                if (pendingConfirm && pendingConfirm.confirmation_id === data.confirmation_id) {
                    pendingConfirm = null;
                }
            }
        } else if (dom === "human") {
            if (typ === "form_required") {
                pendingForm = data;
            } else if (typ === "form_resolved") {
                if (pendingForm && pendingForm.form_id === data.form_id) {
                    pendingForm = null;
                }
            }
        } else if (dom === "system") {
            if (typ === "error") {
                blocks.append(_row({
                    key: "err:" + (env.seq || Date.now()),
                    kind: "error",
                    text: (data && (data.message || data.error)) || "未知错误",
                    frozen: true
                }));
            }
        }
    }

    function _appendThinking(t) {
        if (!t) return;
        if (_liveThinkingIdx < 0 || _liveThinkingIdx >= blocks.count) {
            blocks.append(_row({
                key: "live:" + _liveIntentId + ":t",
                kind: "thinking", text: t, live: true, frozen: false,
                intentId: _liveIntentId
            }));
            _liveThinkingIdx = blocks.count - 1;
        } else {
            var prev = blocks.get(_liveThinkingIdx).text || "";
            blocks.setProperty(_liveThinkingIdx, "text", prev + t);
        }
    }
    function _appendDelta(t) {
        if (!t) return;
        if (_liveThinkingIdx >= 0 && _liveThinkingIdx < blocks.count) {
            blocks.setProperty(_liveThinkingIdx, "live", false);
            blocks.setProperty(_liveThinkingIdx, "frozen", true);
            _liveThinkingIdx = -1;
        }
        if (_liveReplyIdx < 0 || _liveReplyIdx >= blocks.count) {
            blocks.append(_row({
                key: "live:" + _liveIntentId + ":r",
                kind: "reply", text: t,
                live: true, frozen: false,
                intentId: _liveIntentId, modelName: streamModel
            }));
            _liveReplyIdx = blocks.count - 1;
        } else {
            var prev2 = blocks.get(_liveReplyIdx).text || "";
            blocks.setProperty(_liveReplyIdx, "text", prev2 + t);
        }
    }
    function _freezeLive() {
        if (_liveThinkingIdx >= 0 && _liveThinkingIdx < blocks.count) {
            blocks.setProperty(_liveThinkingIdx, "live", false);
            blocks.setProperty(_liveThinkingIdx, "frozen", true);
        }
        if (_liveReplyIdx >= 0 && _liveReplyIdx < blocks.count) {
            blocks.setProperty(_liveReplyIdx, "live", false);
            blocks.setProperty(_liveReplyIdx, "frozen", true);
        }
        _freezeAction();
        _liveThinkingIdx = -1;
        _liveReplyIdx = -1;
    }

    function _freezeReplyIfLive() {
        if (_liveReplyIdx < 0 || _liveReplyIdx >= blocks.count)
            return;
        var row = blocks.get(_liveReplyIdx);
        if (!row || row.kind !== "reply") {
            _liveReplyIdx = -1;
            return;
        }
        if (row.live)
            blocks.setProperty(_liveReplyIdx, "live", false);
        blocks.setProperty(_liveReplyIdx, "frozen", true);
        _liveReplyIdx = -1;
    }

    function _pushAction(actName, label, live) {
        // action 起点要切分 reply：后续 delta 会自动开启新的 reply 行。
        if (_liveThinkingIdx >= 0 && _liveThinkingIdx < blocks.count) {
            blocks.setProperty(_liveThinkingIdx, "live", false);
            blocks.setProperty(_liveThinkingIdx, "frozen", true);
            _liveThinkingIdx = -1;
        }
        _freezeReplyIfLive();
        blocks.append(_row({
            key: "act:" + actName + ":" + Date.now(),
            kind: "action", text: "",
            live: !!live, frozen: !live,
            actionType: actName,
            actionLabel: label || actName
        }));
        _liveActionIdx = blocks.count - 1;
    }
    function _resolveAction(actName, summary) {
        if (_liveActionIdx >= 0 && _liveActionIdx < blocks.count) {
            blocks.setProperty(_liveActionIdx, "live", false);
            blocks.setProperty(_liveActionIdx, "frozen", true);
            blocks.setProperty(_liveActionIdx, "actionLabel", _actionDoneLabel[actName] || actName);
            if (summary) blocks.setProperty(_liveActionIdx, "text", summary);
            _liveActionIdx = -1;
        } else {
            blocks.append(_row({
                key: "act:" + actName + ":" + Date.now(),
                kind: "action", text: summary || "",
                frozen: true,
                actionType: actName,
                actionLabel: _actionDoneLabel[actName] || actName
            }));
        }
    }
    function _freezeAction() {
        if (_liveActionIdx >= 0 && _liveActionIdx < blocks.count) {
            blocks.setProperty(_liveActionIdx, "live", false);
            blocks.setProperty(_liveActionIdx, "frozen", true);
            var act = blocks.get(_liveActionIdx).actionType || "";
            if (act && _actionDoneLabel[act])
                blocks.setProperty(_liveActionIdx, "actionLabel", _actionDoneLabel[act]);
            _liveActionIdx = -1;
        }
    }

    function _onToolCall(d) {
        if (!d || !d.tool_call_id) return;
        // 工具调用同样作为阶段边界，切分 reply。
        if (_liveThinkingIdx >= 0 && _liveThinkingIdx < blocks.count) {
            blocks.setProperty(_liveThinkingIdx, "live", false);
            blocks.setProperty(_liveThinkingIdx, "frozen", true);
            _liveThinkingIdx = -1;
        }
        _freezeReplyIfLive();
        var argText = "";
        if (d.arguments_preview != null) {
            argText = String(d.arguments_preview);
        } else if (d.arguments != null) {
            argText = (typeof d.arguments === "string")
                ? d.arguments : JSON.stringify(d.arguments);
        }
        blocks.append(_row({
            key: "tool:" + d.tool_call_id,
            kind: "tool",
            text: "",
            live: true, frozen: false,
            toolName: d.name || "tool",
            toolStatus: "running",
            toolCallId: d.tool_call_id,
            toolArgs: argText.replace(/\s+/g, " ").substring(0, 200)
        }));
        var idx = blocks.count - 1;
        var m = {};
        for (var k in _toolIdxMap) m[k] = _toolIdxMap[k];
        m[d.tool_call_id] = idx;
        _toolIdxMap = m;
    }
    function _onToolResult(d) {
        if (!d || !d.tool_call_id) return;
        var idx = _toolIdxMap[d.tool_call_id];
        var summary = d.summary != null ? String(d.summary)
                    : (d.content != null ? String(d.content) : "");
        var status = d.is_error ? "error" : "done";
        if (idx !== undefined && idx >= 0 && idx < blocks.count) {
            blocks.setProperty(idx, "live", false);
            blocks.setProperty(idx, "frozen", true);
            blocks.setProperty(idx, "toolStatus", status);
            blocks.setProperty(idx, "text", summary);
        } else {
            blocks.append(_row({
                key: "tool:" + d.tool_call_id,
                kind: "tool",
                text: summary,
                frozen: true,
                toolName: d.name || "tool",
                toolStatus: status,
                toolCallId: d.tool_call_id
            }));
        }
    }

    // ============================================================
    //                  HTTP 完成回调
    // ============================================================
    property Connections _conn: Connections {
        target: LianClawClient

        function onRequestFinished(token, ok, status, body) {
            if (token === "lc:sessions") {
                root.sessionsLoading = false;
                var isArr = Array.isArray(body) || (body && typeof body === "object" && typeof body.length === "number");
                if (ok && isArr) {
                    var arr = [];
                    for (var i = 0; i < body.length; ++i) {
                        var s = body[i];
                        if (!s) continue;
                        if (s.id === "_permanent" || s.type === "permanent") continue;
                        arr.push(s);
                    }
                    root.sessions = arr;
                    root.sessionsError = "";
                } else {
                    root.sessionsError = "GET /sessions failed (" + status + ")";
                }
                return;
            }
            if (token.indexOf("lc:meta:") === 0) {
                if (ok && body) { root.currentMeta = body; root.sessionLoading = false; }
                else { root.sessionError = "GET /sessions/{id} failed (" + status + ")"; root.sessionLoading = false; }
                return;
            }
            if (token.indexOf("lc:runtime:") === 0) {
                if (ok && body) root.currentRuntime = body;
                return;
            }
            if (token.indexOf("lc:history:") === 0) {
                var sid = token.substring("lc:history:".length);
                if (sid !== root.currentSid)
                    return;
                if (ok && body && body.messages) {
                    root.blocks.clear();
                    root._appendHistory(body.messages);
                    root.historyTotal = body.total || 0;
                    root.hasMoreHistory = !!body.has_more;
                    var seq = body.last_event_seq || 0;
                    root._lastEnvelopeSeq = Number(seq || 0);
                    if (sid && sid === root.currentSid) {
                        LianClawClient.openStream(sid, seq);
                    }
                }
                return;
            }
            if (token === "lc:create") {
                if (ok && body && body.id) {
                    root.setModeChoice(body.id, "fast");
                    root.refreshSessions();
                    root.enterSession(body.id);
                }
                return;
            }
            if (token.indexOf("lc:rename:") === 0) {
                if (ok) root.refreshSessions();
                return;
            }
            if (token.indexOf("lc:delete:") === 0) {
                var deletedSid = token.substring("lc:delete:".length);
                if (ok) {
                    if (root.currentSid === deletedSid) {
                        LianClawClient.closeStream();
                        root.currentSid = "";
                        root.currentMeta = {};
                        root.currentRuntime = {};
                        root.blocks.clear();
                    }
                    root.refreshSessions();
                }
                return;
            }
            if (token.indexOf("lc:mode:") === 0) {
                if (ok && body) {
                    var rt = {};
                    var src = root.currentRuntime || {};
                    for (var k in src) rt[k] = src[k];
                    for (var k2 in body) rt[k2] = body[k2];
                    root.currentRuntime = rt;
                }
                return;
            }
            if (token.indexOf("lc:wmode:") === 0) {
                if (ok && body) {
                    var m = {};
                    var src2 = root.currentMeta || {};
                    for (var k3 in src2) m[k3] = src2[k3];
                    if (body.work_mode !== undefined) m.work_mode = body.work_mode;
                    root.currentMeta = m;
                }
                return;
            }
            if (token.indexOf("lc:send:") === 0) {
                if (ok && body && body.intent_id) {
                    root.activeIntentId = body.intent_id;
                } else {
                    root.streamPhase = "error";
                    root.lastStreamError = "send failed (" + status + ")";
                }
                return;
            }
            if (token.indexOf("lc:cancel:") === 0) {
                if (!ok) console.warn("[lc] cancel failed status=" + status);
                return;
            }
            if (token.indexOf("lc:retry:") === 0) {
                if (ok && body && body.intent_id) {
                    root.activeIntentId = body.intent_id;
                    root.streamPhase = "accepted";
                }
                return;
            }
            if (token.indexOf("lc:confirm:") === 0) {
                if (!ok) console.warn("[lc] confirm failed status=" + status);
                return;
            }
            if (token.indexOf("lc:form:") === 0) {
                if (!ok) console.warn("[lc] form failed status=" + status);
                return;
            }
        }

        function onEnvelope(env) { root._onEnvelope(env); }

        function onStreamClosed(reason) {
            if (root.streamPhase !== "completed" && root.streamPhase !== "") {
                root.lastStreamError = "stream closed: " + reason;
            }
        }
    }

    Component.onCompleted: {
        if (!LianClawClient.serverReady) LianClawClient.resolveServerBase();
    }
}
