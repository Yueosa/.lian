import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.Modules.Clipboard

PanelWindow {
    id: root

    visible: true
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "qs-unified-launcher-overlay"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.windowOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    readonly property var tabs: [
        { id: "apps", label: "应用", hint: "Super+A", icon: "apps" },
        { id: "clipboard", label: "剪贴板", hint: "Super+Z", icon: "content_paste" },
        { id: "emoji", label: "Emoji", hint: "Super+X", icon: "sentiment_satisfied" }
    ]
    readonly property int frameHeight: Math.min(700, Math.max(620, height - 120))
    readonly property int frameWidth: Math.min(width - 80, Math.max(1100, Math.round(frameHeight * 16 / 9)))
    readonly property int previewPaneWidth: Math.round(frameWidth * 0.6)
    readonly property int closedSlideOffset: Math.round(height * 0.5 + frameHeight * 0.5 + 48)

    property int contentCacheDurationMs: 15000
    property bool windowOpen: false
    readonly property bool contentActive: root.windowOpen || contentCacheTimer.running || animController.slideOffset < root.closedSlideOffset
    property string currentTab: "apps"
    property string previewImage: {
        const base = Colorscheme.currentWallpaperDisplayPreview !== "" ? Colorscheme.currentWallpaperDisplayPreview : "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current_preview"
        return base + "?v=" + Colorscheme.wallpaperPreviewVersion
    }

    Item {
        id: animController
        property int slideOffset: root.closedSlideOffset

        state: root.windowOpen ? "open" : "closed"

        states: [
            State { name: "open"; PropertyChanges { target: animController; slideOffset: 0 } },
            State { name: "closed"; PropertyChanges { target: animController; slideOffset: root.closedSlideOffset } }
        ]

        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation {
                    target: animController
                    property: "slideOffset"
                    duration: 500
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.3
                }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation {
                    target: animController
                    property: "slideOffset"
                    duration: 350
                    easing.type: Easing.InBack
                    easing.overshoot: 0.1
                }
            }
        ]
    }

    function openTab(tab) {
        contentCacheTimer.stop()
        currentTab = tab || "apps"
        windowOpen = true
        Qt.callLater(focusCurrentTab)
    }

    function toggleTab(tab) {
        const target = tab || "apps"
        if (windowOpen && currentTab === target) {
            closeWindow()
            return
        }
        openTab(target)
    }

    function closeWindow() {
        if (!windowOpen) return
        windowOpen = false
        contentCacheTimer.restart()
    }

    function cycleTab(step) {
        let currentIndex = 0
        for (let i = 0; i < tabs.length; ++i) {
            if (tabs[i].id === currentTab) {
                currentIndex = i
                break
            }
        }
        currentTab = tabs[(currentIndex + step + tabs.length) % tabs.length].id
        Qt.callLater(focusCurrentTab)
    }

    function focusCurrentTab() {
        if (contentLoader.item && contentLoader.item.focusPage)
            contentLoader.item.focusPage()
    }

    onWindowOpenChanged: {
        if (windowOpen)
            Qt.callLater(focusCurrentTab)
    }

    Item {
        id: inputMask
        x: 0
        y: 0
        width: root.windowOpen ? root.width : 0
        height: root.windowOpen ? root.height : 0
    }

    mask: Region { item: inputMask }

    Timer {
        id: contentCacheTimer
        interval: root.contentCacheDurationMs
        repeat: false
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.windowOpen
        onClicked: root.closeWindow()
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        enabled: root.windowOpen
        focus: root.windowOpen

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeWindow()
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Tab) {
                root.cycleTab((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
                event.accepted = true
            }
        }

        Loader {
            id: contentLoader
            width: root.frameWidth
            height: root.frameHeight
            anchors.centerIn: parent
            anchors.verticalCenterOffset: animController.slideOffset
            active: root.contentActive
            sourceComponent: mainUiComponent
        }
    }

    Component {
        id: mainUiComponent

        Rectangle {
            width: parent ? parent.width : root.frameWidth
            height: parent ? parent.height : root.frameHeight
            color: "transparent"
            radius: Sizes.rounding.xxl
            focus: root.windowOpen
            visible: root.contentActive

            function focusPage() {
                if (pageLoader.item && pageLoader.item.forceSearchFocus)
                    pageLoader.item.forceSearchFocus()
            }

            RowLayout {
                anchors.fill: parent
                spacing: Sizes.spacing.none

                Item {
                    Layout.preferredWidth: root.previewPaneWidth
                    Layout.maximumWidth: root.previewPaneWidth
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.fill: parent
                        color: Colorscheme.surface_container_high
                        topLeftRadius: Sizes.rounding.xxl
                        bottomLeftRadius: Sizes.rounding.xxl
                        clip: true

                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: root.previewImage
                            asynchronous: false
                            cache: true
                            smooth: true
                            sourceSize.width: root.previewPaneWidth
                            sourceSize.height: root.frameHeight
                        }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, 0.08) }
                                GradientStop { position: 0.45; color: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, 0.18) }
                                GradientStop { position: 1.0; color: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, 0.48) }
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 26
                            spacing: 8

                            Text {
                                text: root.currentTab === "apps" ? "启动器" : (root.currentTab === "clipboard" ? "剪贴板" : "Emoji")
                                font.pixelSize: 32
                                font.bold: true
                                color: Colorscheme.on_primary
                            }

                            Text {
                                width: parent.width
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                text: root.currentTab === "apps"
                                    ? "搜索并启动应用，沿用当前启动器的数据与排序逻辑。"
                                    : (root.currentTab === "clipboard"
                                        ? "搜索、预览并快速粘贴最近的剪贴板内容。"
                                        : "统一搜索 emoji 和颜文字，方向键选中，Enter 直接复制。")
                                font.pixelSize: Sizes.font.lg
                                color: Qt.rgba(Colorscheme.on_primary.r, Colorscheme.on_primary.g, Colorscheme.on_primary.b, 0.86)
                            }
                        }
                    }
                }

                Item {
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: root.frameWidth - root.previewPaneWidth
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(Colorscheme.surface_container_high.r, Colorscheme.surface_container_high.g, Colorscheme.surface_container_high.b, 0.9)
                        topRightRadius: Sizes.rounding.xxl
                        bottomRightRadius: Sizes.rounding.xxl
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 18

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Repeater {
                                    model: root.tabs
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.preferredWidth: 42
                                        Layout.minimumWidth: 42
                                        Layout.maximumWidth: 42
                                        radius: Sizes.rounding.large
                                        color: root.currentTab === modelData.id
                                            ? Qt.rgba(Colorscheme.primary_container.r, Colorscheme.primary_container.g, Colorscheme.primary_container.b, 0.78)
                                            : Qt.rgba(Colorscheme.surface_container_highest.r, Colorscheme.surface_container_highest.g, Colorscheme.surface_container_highest.b, 0.45)
                                        border.width: root.currentTab === modelData.id ? 1 : 0
                                        border.color: Colorscheme.primary
                                        implicitHeight: 42

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: Sizes.font.xl
                                            color: root.currentTab === modelData.id ? Colorscheme.on_primary_container : Colorscheme.on_surface
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.openTab(parent.modelData.id)
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "Tab 切页 · Esc 关闭"
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: Sizes.font.sm
                                    color: Colorscheme.on_surface_variant
                                }
                            }

                            Loader {
                                id: pageLoader
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumWidth: 0
                                sourceComponent: root.currentTab === "apps"
                                    ? appPageComponent
                                    : (root.currentTab === "clipboard" ? clipboardPageComponent : emojiPageComponent)
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Colorscheme.secondary_fixed
                border.width: 2
                radius: Sizes.rounding.xxl
            }
        }
    }

    Component {
        id: appPageComponent

        AppPage {
            anchors.fill: parent
            onRequestCloseLauncher: root.closeWindow()
        }
    }

    Component {
        id: clipboardPageComponent

        ClipboardPage {
            anchors.fill: parent
            onRequestClosePage: root.closeWindow()
        }
    }

    Component {
        id: emojiPageComponent

        EmojiPage {
            anchors.fill: parent
            onRequestClosePage: root.closeWindow()
        }
    }
}