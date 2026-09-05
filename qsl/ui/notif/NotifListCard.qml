// NotifListCard — 应用列表 ↔ 应用详情 横向滑动双 ListView（N 页两容器之二）
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
//
// 两页横向滑动：左=应用列表，右=某应用的通知。
// 两个 ListView 都常驻，切页只动 x——重建 delegate 会丢滚动位置，
// 而且回收池要重新填充，来回切几次就明显卡。
// 清空：两级列表的行都有退出动画（onClearingChanged → exitDelay → 右滑淡出），
// 只让前 clearAnimMax 条错开滑出，其余随 dismissAll 消失
// 无空态文案（关窗 release 时不闪「没有新通知」）
//
// 性能：清空最多 5 路并行动画且不清行高；单条才收 height；ListView reuseItems
//
// 第 10 轮拆分（原 536 行，两个 delegate 各吃掉 163 / 287 行）：
//   NotifAppRow    应用列表页的一行
//   NotifEntryRow  详情页的一条通知
// 本文件只剩两页的编排，外加两个 delegate 共用的那几个尺寸——它们留在这儿是
// 因为不属于任何单独一页，子件通过 `card` 回引取用，不各自复制一份。
// 两个子件互不引用：应用行点开是直接调 sharedState.openApp()，详情页的行也只跟
// sharedState 打交道，切页这件事从头到尾由 currentApp 一个属性驱动。

import QtQuick
import qs.data.state

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    // 固定吃屏高 72%（旧版 640 封顶太矮）；高度不随内容变，清空/过滤不跳高
    implicitHeight: sharedState ? sharedState.listHeight : 0

    // 指向 NotifCenter.notifState（currentApp / clearing / 分组聚合 / 图标回退）
    // 不叫 state：Item 自带同名属性（状态机当前态），避免遮蔽
    property QtObject sharedState

    // 收起态行高。展开态由正文实际行数决定，见 NotifEntryRow 的 expandedH。
    readonly property int rowHeight: 84
    readonly property int rowIconSize: 44
    // 展开时正文最多显示多少行；再长就 elide，避免一条通知吃满整个列表
    readonly property int expandedBodyLines: 12
    readonly property int appRowHeight: 68

    // 吃掉点击，避免穿透到 RailPage 点空白关闭层
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    Item {
        id: listSlide
        anchors.fill: parent
        anchors.margins: Size.spacing.lg
        clip: true

        property real pageShift: root.sharedState.currentApp === "" ? 0 : -width
        Behavior on pageShift {
            Anim { type: Anim.Spatial }
        }

        // ---------- 应用列表页 ----------
        ListView {
            id: appListView
            width: parent.width
            height: parent.height
            x: listSlide.pageShift
            clip: true
            spacing: Size.spacing.xs
            model: root.sharedState.appGroups
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            // 滑出去之后别再吃事件
            enabled: root.sharedState.currentApp === ""

            // modelData / index 必须在实例化处声明成 required：delegate 换成独立
            // 文件之后，文件内部看不见外面这层创建上下文，得显式接进来再往下传。
            delegate: NotifAppRow {
                required property var modelData
                required property int index

                card: root
                group: modelData
                rowIndex: index
            }
        }

        // ---------- 单应用通知页 ----------
        ListView {
            id: listView
            width: parent.width
            height: parent.height
            x: listSlide.pageShift + parent.width
            clip: true
            spacing: Size.spacing.sm
            model: root.sharedState.currentAppEntries
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            enabled: root.sharedState.currentApp !== ""

            // 无空态文案：关窗 release() 会清空 entries，避免闪「没有新通知」

            delegate: NotifEntryRow {
                required property var modelData
                required property int index

                card: root
                entry: modelData
                rowIndex: index
            }
        }
    }
}
