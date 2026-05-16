import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects 
import Quickshell
import Quickshell.Io          // 【新增】：必须引入 IO 模块以支持命令行 Process
import Quickshell.Wayland
import qs.Components
import qs.config

PanelWindow {
    id: root
    
    visible: false
    color: "transparent" 
    
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    
    WlrLayershell.namespace: "rofi-launcher-overlay"
    WlrLayershell.layer: WidgetState.shouldOverlayTransient(root.visible) ? WlrLayer.Overlay : WlrLayer.Top
    LayerSurfaceRemapper { window: root; active: WidgetState.shouldOverlayTransient(root.visible); remapSerial: WidgetState.overlayRemapSerial }
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive 
    WlrLayershell.exclusionMode: ExclusionMode.Ignore 

    property string previewImage: {
        const base = Colorscheme.currentWallpaperDisplayPreview !== "" ? Colorscheme.currentWallpaperDisplayPreview : "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current_preview";
        return base + "?v=" + Colorscheme.wallpaperPreviewVersion;
    }

    // ==========================================
    // 【全局壁纸强制同步引擎】
    // ==========================================
    readonly property string themeScriptPath: Qt.resolvedUrl("../../scripts/update_theme_from_wallpaper.sh").toString().replace("file://", "")

    Process {
        id: syncGlobalWallpaper
        command: ["bash", "-c", "wp=$(awww query | awk -F 'image: ' '{print $2}' | head -n 1 | sed 's/^\"//; s/\"$//'); if [ -n \"$wp\" ]; then bash '" + root.themeScriptPath.replace(/'/g, "'\\''") + "' \"$wp\" '" + Colorscheme.matugenMode.replace(/'/g, "'\\''") + "' >/dev/null 2>&1; fi; echo \"$wp\""]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (path) => {
                let currentPath = path.trim().replace(/^"|"$/g, '');
                if (currentPath !== "") {
                    // 壁纸真实路径用于列表定位，display preview 用于 UI 解码。
                    Colorscheme.currentWallpaperPreview = "file://" + currentPath;
                    Colorscheme.currentWallpaperDisplayPreview = "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current_preview";
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            syncGlobalWallpaper.running = false;
            syncGlobalWallpaper.running = true;
            appPage.forceSearchFocus()
            mainUI.opacity = 1.0
            uiTranslate.y = 0
        }
    }

    function requestClose() {
        // if (closeAnim.running || !root.visible) return
        // closeAnim.start()
        if (!root.visible) return
        root.visible = false
    }

    function toggleWindow() {
        if (root.visible) requestClose()
        else root.visible = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.requestClose()
    }

    // ==========================================
    // 主界面 UI
    // ==========================================
    Rectangle {
        id: mainUI
        width: 1008
        height: 567
        
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        
        opacity: 1.0 // 原来是0
        
        transform: Translate {
            id: uiTranslate
            y: 0 // 原来是300
        }
        
        // ParallelAnimation {
        //     id: openAnim
        //     NumberAnimation {
        //         target: mainUI
        //         property: "opacity"
        //         to: 1.0
        //         duration: 400
        //         easing.type: Easing.OutCubic
        //     }
        //     NumberAnimation {
        //         target: uiTranslate
        //         property: "y"
        //         to: 0
        //         duration: 700
        //         easing.type: Easing.OutBack
        //         easing.overshoot: 2.5
        //     }
        // }
        //
        // ParallelAnimation {
        //     id: closeAnim
        //     NumberAnimation {
        //         target: mainUI
        //         property: "opacity"
        //         to: 0.0
        //         duration: 300
        //         easing.type: Easing.InCubic
        //     }
        //     NumberAnimation {
        //         target: uiTranslate
        //         property: "y"
        //         to: 300
        //         duration: 300
        //         easing.type: Easing.InCubic
        //     }
        //     onFinished: root.visible = false 
        // }
        
        color: "transparent" 
        radius: Sizes.rounding.xxl 
        focus: true 
        
        // 全局键盘网关
        Keys.onUpPressed: (event) => { appPage.decrementCurrentIndex(); event.accepted = true }
        Keys.onDownPressed: (event) => { appPage.incrementCurrentIndex(); event.accepted = true }
        Keys.onReturnPressed: (event) => { appPage.runSelectedApp(); event.accepted = true }
        Keys.onEnterPressed: (event) => { appPage.runSelectedApp(); event.accepted = true }
        Keys.onEscapePressed: (event) => { root.requestClose(); event.accepted = true }
        
        MouseArea { anchors.fill: parent } 
        
        Rectangle {
            id: globalMask
            anchors.fill: parent
            radius: Sizes.rounding.xxl
            visible: false
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: globalMask
            }

            RowLayout {
                anchors.fill: parent
                spacing: Sizes.spacing.none
                
                // --- 左侧：海报区 ---
                Item {
                    Layout.preferredWidth: 640 
                    Layout.fillHeight: true
                    clip: true 
                    
                    Rectangle {
                        anchors.fill: parent
                        color: Colorscheme.shadow
                    }

                    Image {
                        id: rawPreviewForBlur
                        anchors.fill: parent
                        source: root.previewImage
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                        sourceSize.width: 640
                        sourceSize.height: 360
                    }

                    FastBlur {
                        anchors.fill: parent
                        source: rawPreviewForBlur
                        radius: Sizes.rounding.jumbo 
                        transparentBorder: false
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, 0.2)
                    }

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: root.previewImage
                        asynchronous: true
                        sourceSize.width: 960
                        sourceSize.height: 540
                    }


                }
                
                // --- 右侧：列表区 ---
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(Colorscheme.surface_container_high.r, Colorscheme.surface_container_high.g, Colorscheme.surface_container_high.b, 0.88)
                    }
                    
                    AppPage {
                        id: appPage
                        anchors.fill: parent
                        anchors.margins: 30
                        onRequestCloseLauncher: root.requestClose()
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
