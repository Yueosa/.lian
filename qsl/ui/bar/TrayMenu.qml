// TrayMenu — 托盘右键菜单（无 MultiEffect；保留 submenu hydrator）

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.data.state
import qs.data.service

PopupWindow {
    id: root

    property var rootMenuHandle: null
    property string trayName: ""
    property var trayItem: null
    property string trayKey: ""

    signal pinToggled

    readonly property bool itemPinned: {
        const _ = TrayService.pinSignature
        if (root.trayItem)
            return TrayService.isPinned(root.trayItem)
        return TrayService.isPinnedKey(root.trayKey)
    }

    function resolveMenuIconSource(iconValue) {
        const raw = iconValue || ""
        const lower = raw.toLowerCase()
        if (!raw)
            return ""
        if (raw.startsWith("/") || raw.startsWith("file://") || raw.startsWith("image://"))
            return raw
        if (lower === "input-keyboard" || lower === "input-keyboard-symbolic")
            return ""
        if (lower === "view-refresh" || lower === "application-exit")
            return ""
        return "image://icon/" + raw
    }

    function menuIconGlyph(iconValue) {
        const lower = (iconValue || "").toLowerCase()
        if (lower === "input-keyboard" || lower === "input-keyboard-symbolic")
            return "keyboard"
        if (lower === "view-refresh")
            return "refresh"
        if (lower === "application-exit")
            return "logout"
        return ""
    }

    implicitWidth: 240

    // 高度上限按屏幕算，超出就滚。
    //
    // 这里原来写死 `Math.min(600, …)` 而且**没有滚动**：Cursor 这类把最近项目/会话
    // 全列进托盘菜单的应用，条目轻松超过 600px，超出的部分既看不到也到不了
    // （用户报「右键菜单被截断」）。菜单是从顶栏往下掉的，所以留出栏高加一点余量
    readonly property int maxHeight: Math.max(200, Screen.height - 96)
    implicitHeight: Math.min(root.maxHeight, mainLayout.implicitHeight + 20)
    color: "transparent"

    onVisibleChanged: {
        if (visible)
            menuStack.clear()
    }

    ListModel { id: menuStack }

    property var currentSubMenuHandle: {
        if (menuStack.count === 0)
            return null
        return menuStack.get(menuStack.count - 1).handle
    }

    // 菜单关着的时候**必须**解除订阅。给 menu 赋值就是向对方的 dbusmenu 订阅：
    // 对方每发一次 LayoutUpdated，Quickshell 就回一次 GetLayout，回复到达时整棵
    // QsMenuEntry 树重建一遍——而菜单当时根本不可见。
    //
    // 隔离测量（只翻转框窗的焦点抓取，面板不开、动画不跑、水波不动；20 次一进
    // 一出取主线程 CPU）：
    //   无条件订阅   397 / 412 / 407 ms 每次
    //   关着不订阅   45 / 30 / 29 ms 每次 —— 等于空闲基线（67ms/s × 0.44s ≈ 29ms）
    // 也就是每次焦点变化约 185ms，gate 住之后完全免费。
    //
    // 这条曾经是壳里最大的卡顿源，而且现场极具误导性：托盘应用会跟着**我们的
    // 键盘焦点**变化重发 LayoutUpdated（焦点一进一出各一次），于是每次开合面板
    // 或岛都恰好挨两发。它看起来像是「拿键盘焦点很贵」——查了很久才发现贵的是
    // 这个闭着的菜单，不是焦点本身（见 plan.md 第 6 轮）。
    //
    // 代价烧在 **Quickshell 内部**，不在我们的委托里：把下面那个 Repeater 的 model
    // 从数组换成数量（委托因此不再整树重建）之后，上面这个数字一点没动。现场是
    // Cursor 的托盘菜单——27 个条目、13 个带**内嵌 icon-data**（是图像字节，不是
    // 图标名）、还有一层子菜单，而它每次会话列表变化或焦点变化都重发一遍布局
    QsMenuOpener {
        id: rootOpener
        menu: root.visible ? root.rootMenuHandle : null
    }

    QsMenuOpener {
        id: subOpener
        menu: root.currentSubMenuHandle
    }

    QsMenuAnchor {
        id: hydrator
        anchor.window: root
        anchor.item: mainLayout
        anchor.rect.x: root.width / 2
        anchor.rect.y: root.height / 2
        anchor.rect.width: 1
        anchor.rect.height: 1
    }

    function navigateToSubmenu(menuHandle, menuText) {
        if (!menuHandle)
            return
        menuStack.append({ "handle": menuHandle, "title": menuText })
        try {
            if (typeof menuHandle.aboutToShow === "function")
                menuHandle.aboutToShow()
            if (typeof menuHandle.updateLayout === "function")
                menuHandle.updateLayout()
            hydrator.menu = menuHandle
            hydrator.open()
            Qt.callLater(() => {
                if (hydrator.menu === menuHandle)
                    hydrator.close()
            })
        } catch (e) {
            console.warn("TrayMenu hydrator:", e)
        }
    }

    function navigateBack() {
        if (menuStack.count > 0)
            menuStack.remove(menuStack.count - 1, 1)
    }

    Rectangle {
        anchors.fill: parent
        color: Color.surfaceContainerHigh
        radius: Size.rounding.md
        border.width: 1
        border.color: Color.outlineVariant
        clip: true

        ColumnLayout {
            id: mainLayout
            // 必须给确定高度（不是只给宽度）：下面的列表要靠 Layout.fillHeight
            // 拿到「窗口夹完之后还剩多少」才知道自己该不该滚。只给宽度的话它会
            // 按 implicitHeight 铺满，然后被背景那个 clip 硬切——就是截断本身。
            // 底边留 20 与窗口 implicitHeight 里那个 +20 对齐
            anchors.fill: parent
            anchors.bottomMargin: 20
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "transparent"

                Text {
                    text: (menuStack.count === 0)
                        ? (root.trayName || "Menu")
                        : menuStack.get(menuStack.count - 1).title
                    anchors.centerIn: parent
                    font.bold: true
                    color: Color.primary
                    font.pixelSize: Size.fontSize.md
                    width: parent.width - 60
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: menuStack.count > 0
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: Size.rounding.sm
                    color: "transparent"

                    QslStateLayer { source: backMa; tint: Color.primary; accent: true }

                    Text {
                        text: "arrow_back"
                        anchors.centerIn: parent
                        color: Color.text
                        font.family: Size.fontIcon
                        font.pixelSize: Size.fontSize.lg
                    }
                    MouseArea {
                        id: backMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigateBack()
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Color.primary
                    opacity: 0.2
                }
            }

            ColumnLayout {
                id: listCol
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 6
                spacing: Size.spacing.xs

                // pin / unpin — 不依赖应用菜单
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Size.rounding.sm
                    color: "transparent"
                    visible: root.trayKey.length > 0

                    QslStateLayer { source: pinMa; tint: Color.primary; accent: true }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: Size.spacing.md

                        Text {
                            text: "push_pin"
                            font.family: Size.fontIcon
                            font.pixelSize: Size.fontSize.md
                            color: pinMa.containsMouse ? Color.primary : Color.secondary
                        }
                        Text {
                            text: root.itemPinned ? "从栏上收起" : "固定到栏上"
                            Layout.fillWidth: true
                            color: pinMa.containsMouse ? Color.primary : Color.text
                            font.pixelSize: Size.fontSize.md
                        }
                    }

                    MouseArea {
                        id: pinMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // 用 pressed 更稳：部分 PopupWindow 上 clicked 会被吃掉
                        onPressed: event => {
                            event.accepted = true
                            const item = root.trayItem
                            const key = root.trayKey
                            // 按「当前是否在栏上」显式 set，避免 toggle 方向反了
                            const wantPinned = item
                                ? !TrayService.isPinned(item)
                                : !TrayService.isPinnedKey(key)
                            let ok = false
                            if (item)
                                ok = TrayService.setItemPinned(item, wantPinned)
                            else if (key.length)
                                ok = TrayService.setPinned(key, wantPinned)
                            if (ok)
                                root.pinToggled()
                            root.visible = false
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    visible: root.trayKey.length > 0
                    color: Color.outlineVariant
                    opacity: 0.5
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 2
                }

                property var currentModel: (menuStack.count === 0)
                    ? (rootOpener.children ? rootOpener.children.values : [])
                    : (subOpener.children ? subOpener.children.values : [])

                Text {
                    visible: listCol.currentModel.length === 0
                    text: (menuStack.count > 0) ? "Loading..." : "No Items"
                    color: Color.secondary
                    font.italic: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.margins: 10
                }

                Flickable {
                    id: flick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // 想要多高就报多高；窗口那边用 maxHeight 夹住之后，这里拿到的
                    // 实际高度小于 contentHeight，Flickable 自然就能滚了
                    Layout.preferredHeight: itemCol.implicitHeight
                    contentWidth: width
                    contentHeight: itemCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    // 条目上那些 MouseArea 不收滚轮，所以滚轮会落到这里；按下拖动
                    // 超过阈值时 Flickable 会把鼠标夺过来，所以点击和拖动都正常
                    ScrollBar.vertical: ScrollBar {
                        policy: flick.contentHeight > flick.height
                            ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    }

                    ColumnLayout {
                        id: itemCol
                        width: flick.width
                        spacing: Size.spacing.xs

                        Repeater {
                            // model 绑**数量**，不是那个数组。
                            //
                            // `.values` 每次求值都返回一个**新**数组，Repeater 只能
                            // 理解成「整个模型换了」，于是把所有委托销毁重建，每个
                            // 条目的 Text 再走一遍 HarfBuzz 排版——代价正比于菜单的
                            // 规模，而不是变化的规模，而变化通常是零。
                            //
                            // 绑数量之后，数量没变则 Repeater 一动不动，只有委托里的
                            // entry 绑定重算一遍（很便宜）；Text 收到一模一样的字符串
                            // 会在 QQuickText::setText 里提前返回，一次排版都不发生。
                            // 数量变了也只增删尾部那几个。
                            //
                            // 但要说清适用范围：这一层**不是**焦点停顿的解药。那笔账
                            // 在 Quickshell 内部（见上面 rootOpener 的注释），实测换成
                            // 这个写法数字一点没动。它管的是**菜单正开着**时应用重发
                            // 布局：那时订阅必然是活的，委托要是整树重建，正在看的
                            // 菜单会跳一下、悬停状态也会丢
                            model: listCol.currentModel.length

                            delegate: Rectangle {
                                id: menuItem
                                required property int index
                                readonly property var entry: listCol.currentModel[menuItem.index] ?? null
                                property bool isSeparator: !entry || entry.isSeparator === true || entry.text === ""
                                property bool hasSubMenu: (entry && entry.hasChildren === true)
                                property var effectiveHandle: (entry && entry.menu) ? entry.menu : entry

                                Layout.fillWidth: true
                                Layout.preferredHeight: isSeparator ? 9 : 36
                                radius: Size.rounding.sm
                                color: "transparent"

                                QslStateLayer {
                                    source: itemMa
                                    active: !menuItem.isSeparator
                                    tint: Color.primary
                                    accent: true
                                }

                                Rectangle {
                                    visible: menuItem.isSeparator
                                    anchors.centerIn: parent
                                    width: parent.width - 20
                                    height: 1
                                    color: Color.outlineVariant
                                    opacity: 0.5
                                }

                                RowLayout {
                                    visible: !menuItem.isSeparator
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: Size.spacing.md

                                    Item {
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                        visible: (menuItem.entry && menuItem.entry.icon) ? true : false
                                        property string glyph: root.menuIconGlyph(menuItem.entry ? menuItem.entry.icon : "")

                                        Image {
                                            id: iconRaw
                                            anchors.fill: parent
                                            source: root.resolveMenuIconSource(menuItem.entry ? menuItem.entry.icon : "")
                                            fillMode: Image.PreserveAspectFit
                                            visible: status === Image.Ready && parent.glyph === ""
                                            asynchronous: true
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: parent.glyph !== "" || iconRaw.status === Image.Error
                                            text: parent.glyph !== "" ? parent.glyph : "apps"
                                            font.family: Size.fontIcon
                                            font.pixelSize: Size.fontSize.md
                                            color: itemMa.containsMouse ? Color.primary : Color.secondary
                                        }
                                    }

                                    Text {
                                        visible: menuItem.entry ? menuItem.entry.toggleState === 1 : false
                                        text: "check"
                                        font.family: Size.fontIcon
                                        color: Color.primary
                                        font.pixelSize: Size.fontSize.md
                                    }

                                    Text {
                                        text: menuItem.entry ? (menuItem.entry.text || "") : ""
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        color: {
                                            if (menuItem.entry && menuItem.entry.enabled === false)
                                                return Color.outline
                                            if (itemMa.containsMouse)
                                                return Color.primary
                                            return Color.text
                                        }
                                        font.pixelSize: Size.fontSize.md
                                        font.weight: itemMa.containsMouse ? Font.DemiBold : Font.Normal
                                    }

                                    Text {
                                        visible: menuItem.hasSubMenu
                                        text: "chevron_right"
                                        font.family: Size.fontIcon
                                        font.pixelSize: Size.fontSize.lg
                                        color: itemMa.containsMouse ? Color.primary : Color.tertiary
                                    }
                                }

                                MouseArea {
                                    id: itemMa
                                    visible: !menuItem.isSeparator
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !menuItem.entry || menuItem.entry.enabled !== false
                                    onClicked: {
                                        if (menuItem.hasSubMenu) {
                                            root.navigateToSubmenu(menuItem.effectiveHandle, menuItem.entry.text)
                                        } else {
                                            menuItem.entry.triggered()
                                            root.visible = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
