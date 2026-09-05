pragma Singleton

// ============================================================
// 剪贴板数据 — Clipboard
// ============================================================
// 真源仍是 cliphist（磁盘 DB）；本层只缓存 list 元数据 JSON，
// 给 UI 秒开，不复制原图/全文。
//
//   ~/.cache/qsl/clipboard-list.json  ← clipboardctl list 写出
//   ~/.cache/qsl/clipboard-thumbs/    ← 图片缩略图
// ============================================================
// 属性（readonly）：
//   entries    array   全部条目（id/kind/mime/preview/thumb/width/height）
//   filtered   array   当前 query 过滤后的条目
//   rows       model   打包成行的结果，**增量** ListModel（角色 row）
//   revision   int     rows 内容版本（条数没变但内容变了也会加一）
//   bulkChange bool    上一次同步是不是大改（视图靠它决定要不要播行级过渡）
//   loading    bool    list 进程在跑
//   empty      bool    磁盘上是不是真的没有历史
//
// 属性（可写）：
//   query      string  搜索词，视图直接写
//   columns    int     连续图片一行摆几张，视图按卡片宽度算出来告诉这一层
//
// 方法：
//   hydrate()      从 JSON 缓存灌入内存（打开时立刻有数据）
//   refresh()      跑 clipboardctl list，更新缓存 + 内存
//   paste(id,mime) 把历史项重新写入 selection
//   remove(id)     删一条（含缩略图）
//   clear()        清空历史
//   release()      关窗后清内存，减轻 Image/delegate
// ============================================================
// 「行」不等于「条目」：文本一条一行，连续的图片打包成一行多列。打包放在这一层
// 而不是视图里，为的是列表模型仍归服务持有（架构约定 4：列表要能播动画就必须是
// 增量模型，而增量模型的主人是服务层）。视图只交上来一个数——一行摆几张——那
// 是个分组参数，不是版式细节。

import QtQuick
import Quickshell
import Quickshell.Io
import "../service/rowsync.js" as RowSync

Singleton {
    id: root

    readonly property string ctlPath:
        Quickshell.shellDir + "/backend/clipboard/build/clipboardctl"
    readonly property string listCachePath:
        Quickshell.env("HOME") + "/.cache/qsl/clipboard-list.json"

    property var entries: []
    property var filtered: []
    property string query: ""
    property bool loading: false

    // 内容版本。条数不变但内容换了（删掉一条又来了一条）时绑定也要重算，
    // 而 filtered 是整体替换的数组，绑它的地方拿不到"内容变了"这件事
    readonly property int revision: _rev
    property int _rev: 0

    // 以磁盘 JSON 为准：无文件或 [] 才算空（不靠瞬时内存）
    readonly property bool empty: entries.length === 0

    // ---- 行模型 ----
    // 增量的：搜索时留下来的行滑动、走掉的行淡出（同 Apps / Network，算法见
    // data/service/rowsync.js）。行的键取「类型 + 首个条目 id + 条目数」：图片组
    // 的成员变了（删掉一张）就算新的一行，让它整行重建——组里少一张，后面的图
    // 会从下一行挤上来，按成员算键才对得上
    readonly property var rows: _rowsModel
    readonly property int rowCount: _rowsModel.count
    // 一行摆几张图，视图按卡片宽度算好写进来
    property int columns: 3
    // 上一次同步是不是"回灌"：一次增很多行时不该播行级过渡（增删的代价不
    // 对称，理由见 rowsync.js 的 delta）
    property bool bulkChange: false
    readonly property int incrementalBudget: 6

    ListModel {
        id: _rowsModel
        dynamicRoles: true
    }

    onQueryChanged: applyFilter()
    onColumnsChanged: buildRows()

    // 进来的列表一律过一遍"待删集合"：删一条要跑 list+delete+list，一趟一百多
    // 毫秒，这中间任何一份先发的旧列表回来都会把刚删的条目重新灌进内存（表现是
    // 已经消失的行又自己冒出来）。反过来，某个 id 在新列表里已经没了就说明后端
    // 确实删干净了，标记可以撤掉
    function applyParsed(parsed) {
        const list = Array.isArray(parsed) ? parsed : []
        const pend = _pendingRemove
        const keys = Object.keys(pend)
        if (keys.length === 0) {
            entries = list
        } else {
            const seen = {}
            const out = []
            for (let i = 0; i < list.length; i++) {
                const e = list[i]
                if (pend[e.id])
                    seen[e.id] = true
                else
                    out.push(e)
            }
            for (let k = 0; k < keys.length; k++) {
                if (!seen[keys[k]])
                    delete pend[keys[k]]
            }
            entries = out
        }
        applyFilter()
    }

    function applyCacheText(raw) {
        try {
            const t = (raw || "").trim()
            applyParsed(t.length > 0 ? JSON.parse(t) : [])
        } catch (e) {
            console.warn("Clipboard: parse cache failed", e)
            applyParsed([])
        }
    }

    // 打开窗口：先读缓存（同步观感），再后台 refresh
    function hydrate() {
        listCache.reload()
    }

    function refresh() {
        if (loading)
            return
        loading = true
        listProc.running = true
    }

    function applyFilter() {
        const q = query.trim().toLowerCase()
        if (q === "") {
            filtered = entries
        } else {
            const out = []
            for (let i = 0; i < entries.length; i++) {
                const e = entries[i]
                if ((e.preview || "").toLowerCase().indexOf(q) >= 0)
                    out.push(e)
            }
            filtered = out
        }
        buildRows()
    }

    // 条目 → 行：文本一条一行，连续的图片按 columns 切块
    function buildRows() {
        const items = filtered || []
        const out = []
        let i = 0
        while (i < items.length) {
            if (items[i].kind === "image") {
                const group = []
                while (i < items.length && items[i].kind === "image") {
                    group.push(items[i])
                    i++
                }
                for (let j = 0; j < group.length; j += columns)
                    out.push({ type: "images",
                               entries: group.slice(j, j + columns) })
            } else {
                out.push({ type: "text", entries: [items[i]] })
                i++
            }
        }

        bulkChange = RowSync.delta(_rowsModel, out, "row", rowKey).added
            > incrementalBudget
        if (bulkChange)
            RowSync.overwrite(_rowsModel, out, "row")
        else
            RowSync.sync(_rowsModel, out, "row", rowKey)
        _rev++
    }

    function rowKey(r) {
        return r.type + ":" + r.entries[0].id + ":" + r.entries.length
    }

    function rowAt(i) {
        return (i >= 0 && i < _rowsModel.count) ? _rowsModel.get(i).row : null
    }

    function paste(id, mime) {
        if (!id)
            return
        Quickshell.execDetached([root.ctlPath, "paste", String(id), mime || ""])
    }

    // 删一条。
    //
    // 先在内存里就地删掉再去调进程：cliphist 那边要跑 list + delete + list，
    // 一趟一百来毫秒，等它回来行才消失的话手感是"按了没反应"。删错的代价也小
    // ——进程回吐的是删后的真列表，会把内存覆盖回去。
    //
    // 动模型要**等下一拍**：删除的触发点通常就是那一行自己的叉，同一个调用栈里
    // 把行从模型里摘掉，等于在 delegate 自己的点击处理器里把这个 delegate 拆了
    // ——处理器回到一半就没了 this，后面每条绑定都报「Cannot read property of
    // null」。callLater 让这一栈先走完，行再消失。
    // 每次都是新的箭头函数，所以连按不会被 callLater 合并成一次
    //
    // 排队而不是每次新建 Process：连按 Delete 会叠在一起，同一个 Process 重复
    // 改 command 再 running=true 的行为没保证
    property var _removeQueue: []
    // id -> true，从提交到后端确认删干净这段时间的挡板（见 applyParsed）。
    // 同一个 id 重复提交也在这儿挡掉：按住 Delete 的自动重复一拍能发好几个，
    // 而内存要等下一拍才更新，那几拍里 selectedEntry() 拿到的还是同一条
    property var _pendingRemove: ({})

    function remove(id) {
        const me = String(id || "")
        if (!me || _pendingRemove[me])
            return
        _pendingRemove[me] = true
        _removeQueue = _removeQueue.concat([me])
        _kickRemove()
        Qt.callLater(() => {
            root.entries = root.entries.filter(e => e.id !== me)
            root.applyFilter()
        })
    }

    function _kickRemove() {
        if (removeProc.running || _removeQueue.length === 0)
            return
        const next = _removeQueue[0]
        _removeQueue = _removeQueue.slice(1)
        removeProc.command = [root.ctlPath, "remove", next]
        removeProc.running = true
    }

    function clear() {
        Quickshell.execDetached([root.ctlPath, "clear"])
        applyParsed([])
    }

    // 关窗后清内存，减轻 Image/delegate；JSON 仍在磁盘供下次 hydrate。
    // 行模型也清掉：那些缩略图 Image 挂在行的 delegate 上
    function release() {
        entries = []
        filtered = []
        query = ""
        _rowsModel.clear()
        _rev++
    }

    FileView {
        id: listCache
        path: root.listCachePath
        // 只在 hydrate() 时读盘；不 watch，避免 list 写缓存后重复 parse
        watchChanges: false
        onLoaded: root.applyCacheText(text())
        onLoadFailed: {
            if (root.entries.length === 0)
                root.applyParsed([])
        }
    }

    Process {
        id: listProc
        command: [root.ctlPath, "list", "--limit", "100"]
        stdout: StdioCollector {
            onStreamFinished: {
                // stdout 与落盘 JSON 同内容；先用 stdout 更新，避免等 FileView
                root.applyCacheText(this.text)
            }
        }
        onExited: root.loading = false
    }

    Process {
        id: removeProc
        // remove 删完会**回吐删后的整份列表**，所以不用再补一次 list
        stdout: StdioCollector {
            onStreamFinished: {
                const t = (this.text || "").trim()
                if (t.length > 0)
                    root.applyCacheText(t)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = (this.text || "").trim()
                if (t.length > 0)
                    console.warn("clipboardctl remove: " + t)
            }
        }
        // 队列里还有就接着删
        onExited: root._kickRemove()
    }
}
