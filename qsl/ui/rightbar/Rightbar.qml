// Rightbar — V 面板壳（Super+V / IPC rightbar），进入模式容器版
// 页面 = 从 rightrail 顶部派生的一组 RailContainer（RailPage 编排：级联派生/收回、Esc/点空白关闭、Tab 循环）
// 无页面级 Tab 条；对外 API 与旧卡片版一致：
//   toggle() / openWindow(v) / openView(v) / view / next() / prev() / closeWindow()
//
// 共享状态：网络/蓝牙的行内遗忘确认目标上移到本文件（同页多卡各持一半 UI，经 sharedState 属性共用）
// 详情档生命周期：原各 Page 进/出页开关，现按 open && page===X 驱动；
//   关窗等容器收回播完再 detailActive=false（收回期间内容照旧，不闪空列表，对齐 NotifCenter 语义）

import QtQuick
import qs.Components
import qs.data.state
import qs.data.service

RailPage {
    id: root

    edge: "right"
    valign: "top"
    shellNamespace: "qsl-rightbar"
    // 互斥组：V：rightrail 上，和 N=通知同区
    panelGroup: "right"
    containerWidth: Size.panel.vWidth

    order: ["network", "bluetooth", "audio", "updates"]
    page: "network"

    // 旧对外属性名，直通 RailPage.page
    property alias view: root.page

    readonly property var views: ["network", "bluetooth", "audio", "updates"]

    pages: ({
        network:   { title: "网络", icon: "\uf1eb", containers: [netToggleCard, netAvailCard, netSavedCard] },
        bluetooth: { title: "蓝牙", icon: "\uf293", containers: [btToggleCard, btPairedCard, btNearbyCard] },
        audio:     { title: "声音", icon: "\uf028", containers: [audioOutputCard, audioInputCard, audioAppsCard] },
        updates:   { title: "更新", icon: "\uf019", containers: [updStatusCard, updListCard] }
    })

    function normalizeView(v) {
        if (!v)
            return views[0]
        const key = String(v).toLowerCase()
        for (let i = 0; i < views.length; i++) {
            if (views[i] === key)
                return views[i]
        }
        return views[0]
    }

    function openWindow(v) {
        const has = v !== undefined && v !== null && String(v).length > 0
        openPage(has ? normalizeView(v) : page)
    }

    // 与旧 IPC 对齐：指定页打开；同页再开则关闭
    // 关窗时不能走 switchTo（目标页 == 当前页会被它跳过，窗开不起来）
    function openView(v) {
        const target = normalizeView(v)
        if (open && page === target) {
            closeWindow()
            return
        }
        if (open)
            switchTo(target)
        else
            openPage(target)
    }

    function next() { cycle(1) }
    function prev() { cycle(-1) }

    // ---- 详情档生命周期（原各 Page 的 Component.onCompleted/onDestruction）----
    // 全部走基类 detailPage（双边滞后）：开窗等派生播完才启服务（扫描/轮询的
    // 启动是同步大活，砸在动画第一帧上就是开面板卡顿），关窗等收回播完才撤
    // （收回期间内容照旧，不闪空列表）。本文件原先手写的 _detailHold 只做了
    // 关窗那一半，开窗那一半没有
    onOpenChanged: {
        if (!open)
            _resetInline()
    }

    readonly property bool netDetail: detailPage === "network"
    onNetDetailChanged: Network.setDetailActive(netDetail)
    readonly property bool btDetail: detailPage === "bluetooth"
    onBtDetailChanged: Bluetooth.setDetailActive(btDetail)
    readonly property bool audioDetail: detailPage === "audio"
    onAudioDetailChanged: Volume.setDetailActive(audioDetail)
    readonly property bool updDetail: detailPage === "updates"
    onUpdDetailChanged: Updates.setDetailActive(updDetail)

    // 换页/关窗清行内确认态（原页面销毁时清 forgetTarget）
    onPageChanged: _resetInline()

    function _resetInline() {
        netState.forgetTarget = null
        btState.forgetTarget = null
    }

    // ---- 页内多卡共享状态 ----

    // network：遗忘确认目标（首卡摘要与两张列表卡共用；等价旧 NetworkPage.forgetTarget）
    QtObject {
        id: netState

        property var forgetTarget: null
    }

    // bluetooth：遗忘确认目标（两张设备列表卡共用；等价旧 BluetoothPage.forgetTarget）
    QtObject {
        id: btState

        property var forgetTarget: null
    }

    // ---- 容器装配（顺序即派生顺序）----
    Component { id: netToggleCard; NetToggleCard { sharedState: netState } }
    Component { id: netAvailCard; NetListCard { section: "nearby"; sharedState: netState } }
    Component { id: netSavedCard; NetListCard { section: "saved"; sharedState: netState } }
    Component { id: btToggleCard; BtToggleCard {} }
    Component { id: btPairedCard; BtListCard { mode: "paired"; sharedState: btState } }
    Component { id: btNearbyCard; BtListCard { mode: "nearby"; sharedState: btState } }
    Component { id: audioOutputCard; AudioOutputCard {} }
    Component { id: audioInputCard; AudioInputCard {} }
    Component { id: audioAppsCard; AudioAppsCard {} }
    Component { id: updStatusCard; UpdStatusCard {} }
    Component { id: updListCard; UpdListCard {} }
}
