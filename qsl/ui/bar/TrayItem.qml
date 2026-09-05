// TrayItem — 托盘图标；左键 activate，右键自定义菜单
// 图标怎么挑在 TrayService.iconFor / glyphFor，这里只负责画和转发点击

import QtQuick
import qs.data.state
import qs.data.service

MouseArea {
    id: root
    // 非 required：Tray Loader 先实例化再注入，避免 required 卡死
    property var modelData: null

    signal pinChanged
    // 供 overflow 窗口感知菜单开合：全屏 mask 期间 popup 收不到指针事件
    signal menuToggled(bool open)

    readonly property string trayKey: root.modelData ? TrayService.itemKey(root.modelData) : ""
    readonly property string iconSource: TrayService.iconFor(root.modelData)

    implicitWidth: 20
    implicitHeight: 20

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    function closeMenu() {
        if (trayMenu.visible)
            trayMenu.visible = false
    }

    function closeOtherMenus() {
        const siblings = root.parent.children
        for (let i = 0; i < siblings.length; i++) {
            const sibling = siblings[i]
            if (sibling === root)
                continue
            if (typeof sibling.closeMenu === "function")
                sibling.closeMenu()
        }
    }

    onClicked: (event) => {
        if (event.button === Qt.LeftButton) {
            modelData.activate()
            trayMenu.visible = false
        } else if (event.button === Qt.RightButton) {
            if (!trayMenu.visible) {
                closeOtherMenus()
                trayMenu.visible = true
            } else {
                trayMenu.visible = false
            }
        }
    }

    TrayMenu {
        id: trayMenu
        rootMenuHandle: root.modelData ? root.modelData.menu : null
        trayName: root.modelData
            ? (root.modelData.tooltipTitle || root.modelData.title || root.modelData.id || "Menu")
            : "Menu"
        trayItem: root.modelData
        trayKey: root.trayKey
        anchor.item: root
        anchor.rect.y: (root.mapToItem(null, 0, 0).y > 500)
            ? -trayMenu.implicitHeight - 5
            : root.height + 5
        anchor.rect.x: 0
        onPinToggled: root.pinChanged()
        onVisibleChanged: root.menuToggled(trayMenu.visible)
    }

    // 菜单开着就被拆掉时补一次关闭，避免上层计数漏账
    Component.onDestruction: {
        if (trayMenu.visible)
            root.menuToggled(false)
    }

    Image {
        id: iconImg
        anchors.fill: parent
        cache: true
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: false
        sourceSize.width: 40
        sourceSize.height: 40
        opacity: root.containsMouse ? 1.0 : 0.88
        Behavior on opacity { Anim { type: Anim.EffectsFast } }

        // 原先这里还挂着一个 onStatusChanged 回退：bundled 图标加载失败就换回
        // 系统图标。删了——那条回退是给「bundled 路径指向一个不存在的目录」
        // 兜底的，路径修好之后每次都能加载到，回退再没触发过。
        source: root.iconSource
    }

    Text {
        anchors.centerIn: parent
        // iconFor 交白卷（三级都没命中）或者图片确实加载失败，才显示字形
        visible: !root.iconSource || iconImg.status === Image.Error
        text: TrayService.glyphFor(root.modelData)
        color: Color.text
        font.family: Size.fontIcon
        font.pixelSize: Size.iconSize.xl
    }
}
