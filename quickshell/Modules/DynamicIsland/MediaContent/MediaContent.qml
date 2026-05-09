import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Mpris
import qs.config 

import "../../../Services"

Item {
    id: root
    property real uiScale: 0.86
    
    readonly property bool isActive: root.visible && MediaManager.active
    property bool isPlaying: isActive && MediaManager.active && MediaManager.active.isPlaying

    property string artUrl: (isActive && MediaManager.active.trackArtUrl) 
        ? MediaManager.active.trackArtUrl 
        : ""
        
    property string title: (isActive && MediaManager.active.trackTitle) 
        ? MediaManager.active.trackTitle 
        : "No Media"
        
    property string artist: (isActive && MediaManager.active.trackArtist) 
        ? MediaManager.active.trackArtist 
        : "Unknown Artist"
    
    property double currentPos: 0
    
    Timer {
        interval: 100
        running: root.isActive
        repeat: true
        onTriggered: {
            if (MediaManager.active && !seekMa.pressed) {
                root.currentPos = MediaManager.active.position;
            }
        }
    }
    
    property double progress: (isActive && MediaManager.active.length > 0) 
        ? (root.currentPos / MediaManager.active.length) 
        : 0

    // 对播放器列表进行重排序，让当前播放器排在第一位
    property var sortedPlayerList: {
        let activeP = MediaManager.active;
        let allP = [];

        if (MediaManager.list && MediaManager.list.length !== undefined) {
            for (let i = 0; i < MediaManager.list.length; i++) {
                const p = MediaManager.list[i];
                if (p !== undefined && p !== null) allP.push(p);
            }
        }
        
        if (!activeP || allP.length <= 1) return allP;
        
        // 创建副本并排序：将 active 移到最前
        let sorted = allP.slice();
        sorted.sort((a, b) => {
            if (a === activeP) return -1;
            if (b === activeP) return 1;
            return 0;
        });
        return sorted;
    }

    // ==========================================
    // 全局布局
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 4
        anchors.bottomMargin: 10
        spacing: Sizes.spacing.lg

        // 左侧：封面容器
        Item {
            Layout.preferredWidth: Math.round(120 * root.uiScale)
            Layout.preferredHeight: Math.round(120 * root.uiScale)
            Layout.alignment: Qt.AlignTop 
            Layout.topMargin: 2 

            Item {
                id: scaleWrapper
                anchors.centerIn: parent
                width: 120
                height: 120
                scale: root.isPlaying ? 1.0 : 0.8
                
                Behavior on scale { 
                    NumberAnimation { 
                        duration: 400
                        easing.type: Easing.OutQuint 
                    } 
                }



                DropShadow {
                    anchors.fill: coverContainer
                    source: coverContainer
                    color: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, 0.85) 
                    radius: Sizes.rounding.xlarge
                    samples: 49
                    verticalOffset: 8 
                    opacity: root.isPlaying ? 1.0 : 0.0
                    
                    Behavior on opacity { 
                        NumberAnimation { 
                            duration: 400
                            easing.type: Easing.OutQuint 
                        } 
                    }
                }

                Item {
                    id: coverContainer
                    anchors.fill: parent
                    
                    Rectangle {
                        id: fallbackBg
                        anchors.fill: parent
                        radius: Sizes.rounding.large 
                        color: Colorscheme.surface_container_high
                        visible: root.artUrl === ""
                        
                        Text { 
                            anchors.centerIn: parent
                            text: "🎵"
                            font.pixelSize: Sizes.font.h5c
                        }
                    }
                    
                    Image {
                        id: rawImg
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false 
                    }
                    
                    Rectangle { 
                        id: maskRect
                        anchors.fill: parent
                        radius: Sizes.rounding.large
                        visible: false 
                    }
                    
                    OpacityMask {
                        anchors.fill: parent
                        source: rawImg
                        maskSource: maskRect
                    }
                }
            }
        }

        // 右侧：信息与控制区 
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Sizes.spacing.md

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Sizes.spacing.xs
                    
                    Text {
                        text: root.title
                        color: Colorscheme.on_surface
                        font.bold: true
                        font.pixelSize: Sizes.font.title
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                  
                    Text {
                        text: root.artist
                        color: Colorscheme.on_surface_variant
                        font.pixelSize: Sizes.font.lg
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
                
                // 【核心修改】：预留空间进一步增加到 90，确保标题在更短的长度内省略
                Item {
                    Layout.preferredWidth: 90
                    Layout.fillHeight: true
                }
            }

            Item { Layout.fillHeight: true } 

            // 中间：平移波浪引擎
            Item {
                id: waveContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                
                property real targetX: root.progress * waveContainer.width
                property real activeX: seekMa.pressed 
                    ? Math.max(0, Math.min(seekMa.mouseX, waveContainer.width)) 
                    : targetX
                property real visualX: activeX
                
                Behavior on visualX {
                    enabled: root.visible && !seekMa.pressed
                    SmoothedAnimation { 
                        velocity: 500
                        duration: 400 
                    } 
                }
                
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    radius: Sizes.rounding.xs
                    color: Colorscheme.surface_variant
                }
                
                Canvas {
                    id: waveCanvas
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(6, waveContainer.visualX) 
                    
                    property real phase: 0
                    
                    NumberAnimation on phase { 
                        loops: Animation.Infinite
                        from: 0
                        to: Math.PI * 2
                        duration: 1200
                        easing.type: Easing.Linear
                        running: root.isActive && MediaManager.active && MediaManager.active.isPlaying 
                    }
                    
                    onPhaseChanged: requestPaint()
                    
                    Connections { 
                        target: waveContainer
                        function onVisualXChanged() { waveCanvas.requestPaint() } 
                    }
                    
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        
                        let trackHeight = 6;
                        let radius = 3;
                        let centerY = height / 2;
                        let w = width;
                        
                        if (w < radius * 2) return;
                        
                        ctx.beginPath();
                        ctx.moveTo(w, centerY + trackHeight / 2); 
                        ctx.lineTo(radius, centerY + trackHeight / 2);
                        ctx.arcTo(0, centerY + trackHeight / 2, 0, centerY, radius); 
                        ctx.arcTo(0, centerY - trackHeight / 2, radius, centerY - trackHeight / 2, radius);
                        
                        let freq1 = 0.05;
                        let maxAmp = 6;
                        let fadeLen = 30;
                        
                        for (let x = radius; x <= w; x++) {
                            let leftDist = x - radius;
                            let rightDist = w - x;
                            let envelope = 1.0;
                            
                            if (leftDist < fadeLen) {
                                envelope = Math.sin((leftDist / fadeLen) * (Math.PI / 2));
                            }
                            if (rightDist < fadeLen) { 
                                let envRight = Math.sin((rightDist / fadeLen) * (Math.PI / 2));
                                if (envRight < envelope) {
                                    envelope = envRight; 
                                }
                            }
                            
                            let wave1 = Math.sin(x * freq1 - phase);
                            let wave2 = Math.sin(x * freq1 * 1.5 - phase * 2.0) * 0.3;
                            let combined = (wave1 + wave2 + 1.3) / 2.6;
                            
                            if (combined < 0) combined = 0; 
                            if (combined > 1) combined = 1;
                            
                            let y = (centerY - trackHeight / 2) - (combined * maxAmp * envelope); 
                            ctx.lineTo(x, y);
                        }
                        
                        ctx.lineTo(w, centerY - trackHeight / 2);
                        ctx.lineTo(w, centerY + trackHeight / 2); 
                        ctx.closePath(); 
                        ctx.fillStyle = String(Colorscheme.primary); 
                        ctx.fill();
                    }
                }
                
                Rectangle {
                    id: progressThumb
                    width: 12
                    height: 12
                    radius: Sizes.rounding.splus
                    color: Colorscheme.primary
                    anchors.verticalCenter: parent.verticalCenter
                    x: waveContainer.visualX - width / 2
                }
                
                MouseArea { 
                    id: seekMa
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    
                    onReleased: (mouse) => { 
                        if (MediaManager.active && MediaManager.active.length > 0) { 
                            let clampedX = Math.max(0, Math.min(mouse.x, waveContainer.width));
                            let targetPos = (clampedX / waveContainer.width) * MediaManager.active.length;
                            MediaManager.active.position = targetPos; 
                            root.currentPos = targetPos; 
                        } 
                    } 
                }
            }

            // 底部控制按钮区
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: Sizes.spacing.sectionPlus
  
                component CtrlBtn : Text { 
                    property bool active: false
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: Sizes.font.h1
                    color: active ? Colorscheme.primary : Colorscheme.on_surface
                    opacity: active ? 1.0 : 0.7
                    scale: ma.pressed ? 0.8 : (ma.containsMouse ? 1.1 : 1.0)
                    
                    Behavior on scale { NumberAnimation { duration: 150 } } 
                    
                    MouseArea { 
                        id: ma
                        anchors.fill: parent
                        anchors.margins: -10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.triggered() 
                    } 
                    signal triggered() 
                }
                
                CtrlBtn { 
                    text: "shuffle"
                    active: MediaManager.active && MediaManager.active.shuffle
                    onTriggered: {
                        if(MediaManager.active && MediaManager.active.shuffleSupported) {
                            MediaManager.active.shuffle = !MediaManager.active.shuffle
                        }
                    }
                } 
                
                CtrlBtn { 
                    text: "skip_previous"
                    font.pixelSize: Sizes.font.h3
                    onTriggered: if(MediaManager.active) MediaManager.active.previous() 
                } 
                
                // 使用一层 Item 作为占位箱，这样内部 Rect 变形时可以严格从中心点向两侧扩张
                Item {
                    Layout.preferredWidth: 62
                    Layout.preferredHeight: 48
                    
                    Rectangle { 
                        id: playBtn
                        // 始终锁定在容器正中心，保证形变重心不变
                        anchors.centerIn: parent
                        
                        width: 54 + (playMa.pressed ? 18 : ((MediaManager.active && MediaManager.active.isPlaying) ? 10 : 0))
                        height: 46
                        // 当按下时变成小圆角矩形(Squircle)，播放时变成中等尺寸圆角矩形，暂停时恢复完美正圆形
                        radius: playMa.pressed ? 11 : ((MediaManager.active && MediaManager.active.isPlaying) ? 14 : 23)
                        
                        // 暂停时为浅色/低对比度，播放时为深色/高对比度 (Primary)
                        color: (MediaManager.active && MediaManager.active.isPlaying) 
                            ? Colorscheme.primary 
                            : Colorscheme.surface_container_high
                        
                        // expressiveFastSpatial: 350ms, bezier(0.42, 1.67, 0.21, 0.9, 1, 1)
                        Behavior on width { 
                            NumberAnimation { duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 1.67, 0.21, 0.9, 1, 1] } 
                        }
                        Behavior on radius { 
                            NumberAnimation { duration: 350; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 1.67, 0.21, 0.9, 1, 1] } 
                        }
                        // standard: 400ms, bezier(0.2, 0, 0, 1)
                        Behavior on color { 
                            ColorAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } 
                        }
                        
                        // StateLayer 涟漪层
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: (MediaManager.active && MediaManager.active.isPlaying) ? Colorscheme.on_primary : Colorscheme.on_surface
                            opacity: playMa.pressed ? 0.2 : (playMa.containsMouse ? 0.12 : 0.0)
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                        
                        Text { 
                            id: playIcon
                            anchors.centerIn: parent
                            text: (MediaManager.active && MediaManager.active.isPlaying) ? "pause" : "play_arrow"
                            
                            // 暂停时图标为深色，播放时为浅白
                            color: (MediaManager.active && MediaManager.active.isPlaying) 
                                ? Colorscheme.on_primary 
                                : Colorscheme.on_surface
                            
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: Sizes.font.h3b
                            
                            // standard: 400ms
                            Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                            
                            // Caelestia StyledText: animateDuration=400ms (每半200ms)
                            // standardAccel: bezier(0.3, 0, 1, 1) -> 收缩阶段
                            // standardDecel: bezier(0, 0, 0, 1) -> 展开阶段
                            Behavior on text {
                                SequentialAnimation {
                                    NumberAnimation { target: playIcon; property: "scale"; to: 0.0; duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 0, 1, 1, 1, 1] }
                                    PropertyAction { target: playIcon; property: "text" }
                                    NumberAnimation { target: playIcon; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0, 1, 1, 1] }
                                }
                            }
                        } 
                        
                        MouseArea { 
                            id: playMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if(MediaManager.active) MediaManager.active.togglePlaying() 
                        } 
                    }
                }
                
                CtrlBtn { 
                    text: "skip_next"
                    font.pixelSize: Sizes.font.h3
                    onTriggered: if(MediaManager.active) MediaManager.active.next() 
                } 
                
                CtrlBtn { 
                    active: MediaManager.active && MediaManager.active.loopState !== MprisLoopState.None
                    text: (!MediaManager.active) 
                        ? "repeat" 
                        : (MediaManager.active.loopState === MprisLoopState.Track ? "repeat_one" : "repeat")
                    onTriggered: { 
                        if(!MediaManager.active || !MediaManager.active.loopSupported) return;
                        
                        if (MediaManager.active.loopState === MprisLoopState.None) {
                            MediaManager.active.loopState = MprisLoopState.Playlist;
                        } else if (MediaManager.active.loopState === MprisLoopState.Playlist) {
                            MediaManager.active.loopState = MprisLoopState.Track;
                        } else {
                            MediaManager.active.loopState = MprisLoopState.None;
                        }
                    } 
                } 
            }
        }
    }

    // ==========================================
    // 重构的形变药丸 (Morphing Pill)
    // ==========================================
    Rectangle {
        id: pillRect
        
        anchors.top: root.top
        anchors.right: root.right
        anchors.topMargin: 4
        anchors.rightMargin: 10

        property bool menuExpanded: false
        
        // 【核心修改】：替换为明亮且对比度高的 tertiary 颜色 (柔和紫色)
        color: Colorscheme.tertiary
        
        width: menuExpanded ? 120 : Math.min(140, pillText.paintedWidth + 44)
        height: menuExpanded ? (28 * MediaManager.list.length + 10) : 24
        radius: menuExpanded ? 12 : 13
        
        scale: (!menuExpanded && pillMa.pressed) 
            ? 0.94 
            : (!menuExpanded && pillMa.containsMouse ? 1.08 : 1.0)
        z: 999 
        
        Behavior on width { 
            NumberAnimation { duration: 300; easing.type: Easing.OutQuint } 
        }
        Behavior on height { 
            NumberAnimation { duration: 300; easing.type: Easing.OutQuint } 
        }
        Behavior on radius { 
            NumberAnimation { duration: 300; easing.type: Easing.OutQuint } 
        }
        Behavior on scale { 
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic } 
        }

        // 状态一：折叠状态显示的文字
        RowLayout {
            anchors.centerIn: parent
            width: parent.width - 10
            spacing: Sizes.spacing.xs
            opacity: pillRect.menuExpanded ? 0.0 : 1.0

            Text {
                text: MediaManager.getIdentityIcon(MediaManager.active)
                color: Colorscheme.on_tertiary
                font.family: "Material Symbols Outlined"
                font.pixelSize: Sizes.font.sm
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                id: pillText
                Layout.fillWidth: true
                text: MediaManager.getIdentity(MediaManager.active) || "No Player"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                color: Colorscheme.on_tertiary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Sizes.font.xs
                font.weight: Font.DemiBold
            }

            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // 触触发按钮
        MouseArea {
            id: pillMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            visible: !pillRect.menuExpanded
            
            onClicked: {
                if (MediaManager.list.length > 1) {
                    pillRect.menuExpanded = true;
                }
            }
        }

        // 状态二：展开后显示的音源列表
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: Sizes.spacing.none
            visible: pillRect.menuExpanded
            opacity: pillRect.menuExpanded ? 1.0 : 0.0
            
            Behavior on opacity { 
                NumberAnimation { duration: 250; easing.type: Easing.InQuad } 
            }
            
            Repeater {
                model: root.sortedPlayerList.length
                delegate: Rectangle {
                    property var playerItem: (index >= 0 && index < root.sortedPlayerList.length)
                        ? root.sortedPlayerList[index]
                        : null

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: Sizes.rounding.small
                    
                    // 【核心修改】：鼠标悬浮时显示淡淡的黑色遮罩作为高亮，其余状态透明
                    color: itemMa.containsMouse 
                        ? Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, 0.08) 
                        : "transparent"
                    
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: Sizes.spacing.sm

                        Text {
                            text: MediaManager.getIdentityIcon(playerItem)
                            color: Colorscheme.on_tertiary
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: Sizes.font.sm
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (playerItem !== undefined && playerItem !== null)
                                ? (MediaManager.getIdentity(playerItem) || "Unknown")
                                  : "Unknown"
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            color: Colorscheme.on_tertiary
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Sizes.font.xs
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (playerItem !== undefined && playerItem !== null) {
                                MediaManager.manualActive = playerItem;
                            }
                            pillRect.menuExpanded = false;
                        }
                    }
                }
            }
        }
        
        // 点击外部区域自动收起菜单
        MouseArea {
            parent: root
            anchors.fill: parent
            z: -1
            visible: pillRect.menuExpanded
            onClicked: pillRect.menuExpanded = false
        }
    }
}
