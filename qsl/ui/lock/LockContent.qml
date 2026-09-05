// LockContent — 锁屏（媒体优先）
//
// 有媒体：歌词浮在左，cava 沉在下半屏当背景，控件在左下
// （随机 / 上一 / 播放 / 下一 / 循环 + 音量）。时钟收到顶上，
// 待办跟时钟走（一行下一件；点开大钟才列出）。
// 通知是右上 toast；密码独占右下。没媒体时大钟回到左边。
// 天气不要了。不铺实色卡。
//
// 性能：Cava 只在有媒体时 acquire；歌词随 surface 生命周期；
// 通知 hydrate 一次，不设 uiActive；封面 sourceSize 小；无 FastBlur
//
// 第 10 轮拆分（原 932 行）：七个分区各自成文件，本文件只剩
//   ① 派生数据（时间/日期/节气/通知行/待办/歌词窗/音量图标）
//   ② 跨区状态（clockPeek / seekPos / seeking / expandedNotif / _cavaHeld）
//   ③ 编排与转接
// 子件**不回引页根**，要什么由这里显式传。锁屏那三档 ink 被引用二十几次，
// 走回引的话每个绑定在 page 赋值前都要报一次 null，日志就没法看了。
//
//   LockCava / LockClockMini / LockClockHero / LockLyrics /
//   LockMediaControls / LockToasts / LockPassword

import QtQuick
import qs.data.service

Item {
    id: root

    property bool unlocking: false
    property bool failed: false
    property bool dismissing: false
    property bool clockPeek: false

    signal submit()

    readonly property color ink: Qt.rgba(1, 1, 1, 0.96)
    readonly property color inkDim: Qt.rgba(1, 1, 1, 0.62)
    readonly property color inkFaint: Qt.rgba(1, 1, 1, 0.38)

    // 取值全部走 Media 的公开面。这里只留「没播放器时显示什么」——那是呈现决定，
    // 媒体页同一份数据显示的是「未知曲目」
    readonly property bool hasMedia: Media.hasActive
    readonly property bool showMedia: root.hasMedia && !root.clockPeek
    readonly property bool showHero: !root.hasMedia || root.clockPeek
    readonly property string trackTitle: Media.hasActive
        ? (Media.trackTitle || "未知曲目")
        : ""
    readonly property string trackArtist: Media.trackArtist
    readonly property string artUrl: Media.trackArtUrl
    readonly property real trackLength: Media.trackLength

    property real seekPos: 0
    property bool seeking: false
    property int expandedNotif: -1
    property bool _cavaHeld: false

    readonly property string timeStr: Qt.formatDateTime(Time.rawDate, "HH:mm")
    readonly property string dateStr: {
        void Time.rawDate
        const d = Time.rawDate
        return Qt.formatDateTime(d, "dddd") + " · "
            + (d.getMonth() + 1) + "月" + d.getDate() + "日"
    }
    readonly property string holidayLine: {
        const lunar = Calendar.todayLunar || ""
        const h = Calendar.nextHoliday
        let extra = ""
        if (h && h.name) {
            extra = h.daysAway <= 0
                ? (h.name + "中")
                : (h.name + "还有 " + h.daysAway + " 天")
        }
        if (lunar.length && extra.length)
            return "农历" + lunar + " · " + extra
        if (lunar.length)
            return "农历" + lunar
        return extra
    }

    readonly property var notifRows: {
        const list = Notification.entries || []
        const out = []
        const n = Math.min(list.length, 3)
        for (let i = 0; i < n; i++) {
            const e = list[i]
            if (!e)
                continue
            // id 必须带上。Notification.dismiss() 拿 id 分流：有行号的按行号
            // 精确关，没有的当成「刚到还没入库的临时行」退回按协议 id 找最新一条。
            // 而协议 id 是会被不同应用复用的——漏掉 id 就等于把第 9 轮修掉的
            // 「关一条连带关一批」从锁屏这个侧门放回来
            out.push({
                id: e.id,
                notifId: e.notifId,
                appName: e.appName || "",
                summary: e.summary || "",
                body: e.body || ""
            })
        }
        return out
    }

    readonly property var openTodos: {
        void Todo.revision
        const src = Todo.items || []
        const starred = []
        const rest = []
        for (let i = 0; i < src.length; i++) {
            const it = src[i]
            if (!it || it.done)
                continue
            if (it.starred)
                starred.push(it)
            else
                rest.push(it)
        }
        return starred.concat(rest)
    }
    readonly property var todoRows: {
        const t = root.openTodos
        return t.length > 4 ? t.slice(0, 4) : t
    }

    readonly property var lyricWindow: {
        const lines = Lyrics.lines || []
        const cur = Lyrics.currentIndex
        const out = []
        for (let i = cur - 2; i <= cur + 2; i++) {
            out.push({
                text: (i >= 0 && i < lines.length) ? String(lines[i].text || "") : " ",
                current: i === cur && i >= 0 && i < lines.length
            })
        }
        return out
    }

    readonly property string volIcon: {
        if (!Volume.hasSink || Volume.sinkMuted)
            return "volume_off"
        const v = Volume.sinkVolume || 0
        if (v >= 0.66)
            return "volume_up"
        if (v >= 0.33)
            return "volume_down"
        return "volume_mute"
    }

    // ---- 对 LockSurface 的公开面：原样转发给密码框 ----
    function focusInput() { pwd.forceFocus() }
    function clearInput() { pwd.clear() }
    function passwordText() { return pwd.text() }
    function shakePassword() { pwd.shake() }

    function _holdCava(want) {
        if (want === root._cavaHeld)
            return
        root._cavaHeld = want
        if (want)
            Cava.acquire()
        else
            Cava.release()
    }

    onHasMediaChanged: {
        if (!hasMedia)
            clockPeek = false
        root._holdCava(hasMedia && !dismissing)
        Media.syncLyrics()
    }

    onDismissingChanged: root._holdCava(hasMedia && !dismissing)

    // 换播放器或换曲目都由 Media.trackChanged 一个信号覆盖
    Connections {
        target: Media
        function onTrackChanged() { Media.syncLyrics() }
    }

    // ---- cava：下半屏背景，不是控件 ----
    LockCava {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        hasMedia: root.hasMedia
        cavaHeld: root._cavaHeld
    }

    // ---- 顶：有媒体时的小钟 + 下一件待办 ----
    LockClockMini {
        visible: root.showMedia
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 26
        ink: root.ink
        inkDim: root.inkDim
        timeStr: root.timeStr
        dateStr: root.dateStr
        openTodos: root.openTodos
        onPeekRequested: root.clockPeek = true
    }

    // ---- 大钟（没媒体，或点小钟 peek）+ 待办列表 ----
    LockClockHero {
        visible: root.showHero
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Math.round(parent.width * 0.07)
        width: Math.min(560, parent.width * 0.5)
        ink: root.ink
        inkDim: root.inkDim
        inkFaint: root.inkFaint
        timeStr: root.timeStr
        dateStr: root.dateStr
        holidayLine: root.holidayLine
        openTodos: root.openTodos
        todoRows: root.todoRows
        hasMedia: root.hasMedia
        onPeekDismissed: root.clockPeek = false
        onFocusWanted: root.focusInput()
    }

    // ---- 左：歌词 ----
    LockLyrics {
        visible: root.showMedia
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 56
        anchors.verticalCenterOffset: -20
        width: Math.min(520, parent.width * 0.46)
        ink: root.ink
        inkFaint: root.inkFaint
        lyricWindow: root.lyricWindow
    }

    // ---- 左下：媒体控件 ----
    LockMediaControls {
        visible: root.showMedia
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 56
        anchors.bottomMargin: 36
        width: Math.min(560, parent.width * 0.5)
        ink: root.ink
        inkDim: root.inkDim
        artUrl: root.artUrl
        trackTitle: root.trackTitle
        trackArtist: root.trackArtist
        trackLength: root.trackLength
        volIcon: root.volIcon
        seekPos: root.seekPos
        seeking: root.seeking
        onSeekPosChangeRequested: (pos) => root.seekPos = pos
        onSeekingChangeRequested: (active) => root.seeking = active
        onFocusWanted: root.focusInput()
    }

    // ---- 右上：通知 toast ----
    LockToasts {
        visible: root.notifRows.length > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 28
        anchors.rightMargin: 36
        ink: root.ink
        inkDim: root.inkDim
        inkFaint: root.inkFaint
        notifRows: root.notifRows
        expandedNotif: root.expandedNotif
        onExpandRequested: (notifId) => root.expandedNotif = notifId
        onFocusWanted: root.focusInput()
    }

    // ---- 右下：密码 ----
    LockPassword {
        id: pwd
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 36
        anchors.bottomMargin: 36
        ink: root.ink
        inkFaint: root.inkFaint
        failed: root.failed
        unlocking: root.unlocking
        dismissing: root.dismissing
        clockPeek: root.clockPeek
        onSubmit: root.submit()
        onPeekDismissed: root.clockPeek = false
    }

    Timer {
        interval: 500
        running: root.hasMedia && !root.dismissing
        repeat: true
        onTriggered: {
            if (!root.seeking)
                root.seekPos = Media.position()
            if (Media.isMusic)
                Lyrics.syncPosition(root.seekPos)
        }
    }

    Component.onCompleted: {
        Notification.hydrate()
        Qt.callLater(() => Notification.refresh())
        Lyrics.acquire()
        root._holdCava(root.hasMedia && !root.dismissing)
        Media.syncLyrics()
        pwd.forceFocus()
    }

    Component.onDestruction: {
        Lyrics.release()
        root._holdCava(false)
        if (!Notification.uiActive)
            Notification.release()
    }
}
