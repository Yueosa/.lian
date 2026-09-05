pragma Singleton

// ============================================================
// 一言 — Hitokoto
// ============================================================
// https://v1.hitokoto.cn 的一句话 + 出处。
//
// 第 9 轮从 ui/leftbar/TimeClockCard.qml 收上来的。那是全树**唯一**一处 UI
// 组件自己发 HTTP 请求的地方——别的外部数据（天气、媒体、系统、通知）早就
// 都在服务层了，只有这 48 行裸 XMLHttpRequest 长在一张显示时间的卡片里。
//
// 逻辑本身没毛病（去重、超时、兜底都想到了），纯粹是位置不对：它跟那张卡绑死，
// 换个地方想显示一言就得把这段抄一遍。
//
// 对外接口：
//   text / from   当前这句话和出处
//   refresh()     重新取一句
//   abort()       放弃在途请求（面板关掉时调，别让没人看的请求挂着）
// ============================================================

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string endpoint: "https://v1.hitokoto.cn/?encode=json"
    readonly property int timeoutMs: 4000

    property string text: ""
    property string from: ""

    // 取不到就从这儿随机挑一句。断网时显示「……」比显示一句话更像坏了。
    readonly property var fallbackPool: [
        { text: "敲下回车，世界就开始改变。", from: "本地" },
        { text: "今天也要做温柔的人。", from: "本地" },
        { text: "Stay hungry, stay foolish.", from: "Steve Jobs" },
        { text: "代码是写给人看的，顺便能跑。", from: "本地" },
        { text: "山有顶峰，湖有彼岸，人间总值得。", from: "本地" },
        { text: "不要温和地走进那个良夜。", from: "Dylan Thomas" },
        { text: "热爱可抵岁月漫长。", from: "本地" }
    ]

    // 在途的那一个。每个回调都先核对 root._xhr === xhr 才动数据——
    // 连点刷新时旧请求可能后到，不核对就会用旧结果盖掉新结果。
    property var _xhr: null

    function useFallback() {
        const p = root.fallbackPool[Math.floor(Math.random() * root.fallbackPool.length)]
        root.text = p.text
        root.from = p.from
    }

    function abort() {
        const x = root._xhr
        root._xhr = null
        if (!x)
            return
        // 先摘掉回调再 abort：abort() 自己会触发一次 readyState 变更，
        // 不摘的话会走进 onreadystatechange 里当成一次失败去兜底
        try {
            x.onreadystatechange = function() {}
            x.ontimeout = function() {}
            x.abort()
        } catch (e) {}
    }

    function refresh() {
        root.abort()

        const xhr = new XMLHttpRequest()
        root._xhr = xhr
        xhr.open("GET", root.endpoint)
        xhr.timeout = root.timeoutMs

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            if (root._xhr !== xhr)
                return
            root._xhr = null
            if (xhr.status !== 200) {
                root.useFallback()
                return
            }
            try {
                const j = JSON.parse(xhr.responseText)
                root.text = j.hitokoto || ""
                // from_who 是作者、from 是作品；两个都有就拼起来，
                // 都没有就写「一言」，别留空字符串（UI 那边靠非空决定要不要显示这行）
                root.from = j.from_who && j.from_who.length > 0
                    ? (j.from_who + (j.from ? "·" + j.from : ""))
                    : (j.from || "一言")
                if (!root.text)
                    root.useFallback()
            } catch (e) {
                root.useFallback()
            }
        }

        xhr.ontimeout = function() {
            if (root._xhr !== xhr)
                return
            root._xhr = null
            root.useFallback()
        }

        try {
            xhr.send()
        } catch (e) {
            root._xhr = null
            root.useFallback()
        }
    }
}
