import QtQuick
import QtQuick.Layouts
import QtQuick.Effects 
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config 
import qs.Services 

Item {
    id: root
    
    required property var player
    property bool active: false
    property var lyricsModel: []
    property int currentLineIndex: 0
    property bool lastFetchSuccessful: false
    
    readonly property string trackTitle: player ? player.trackTitle : ""
    readonly property string trackArtist: player ? player.trackArtist : ""
    readonly property string playerName: player ? (player.identity || player.busName || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property string trackUrl: player ? (player.metadata["xesam:url"] || "") : ""

    // 非音乐播放器（浏览器、视频）仅显示标题，不调用 lyrics_fetcher
    readonly property bool isMusic: MediaManager.isMusicPlayer(player)
    
    property string currentLoadedTitle: ""

    function isFallbackLyrics(list) {
        if (!list || list.length <= 0) return true
        if (list.length !== 1) return false
        const line = list[0]
        if (!line || !line.text) return true
        return line.text === "暂无歌词" || line.text === "歌词错误"
    }

    // ============================================================
    // 【动态自适应宽度引擎】
    // ============================================================
    property int defaultTextWidth: Sizes.lyricsCapsule.defaultTextWidth
    property int currentTextWidth: defaultTextWidth 

    readonly property int horizontalPadding: Sizes.lyricsCapsule.horizontalPadding
    readonly property int coverWidth: Sizes.lyricsCapsule.coverWidth
    readonly property int spectrumWidth: Sizes.lyricsCapsule.spectrumWidth
    readonly property int sectionGap: Sizes.lyricsCapsule.sectionGap
    readonly property int fixedChromeWidth: (horizontalPadding * 2) + coverWidth + spectrumWidth + (sectionGap * 2)

    // 左右区域固定预留，歌词仅吃中间剩余宽度
    implicitWidth: fixedChromeWidth + currentTextWidth

    Connections {
        target: root
        function onActiveChanged() {
            if (root.active) CavaService.refCount++;
            else CavaService.refCount = Math.max(0, CavaService.refCount - 1);
        }
    }

    // ================= 1. 歌词获取逻辑 =================
    Process {
        id: lyricsFetcher
        command: ["python3", Quickshell.shellDir + "/scripts/lyrics_fetcher.py",
                  root.trackTitle, root.trackArtist, root.playerName, root.trackUrl]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var json = JSON.parse(data)
                    if (json.length > 0 && !root.isFallbackLyrics(json)) {
                        root.lyricsModel = json
                        root.currentLineIndex = 0
                        root.currentLoadedTitle = root.trackTitle
                        root.lastFetchSuccessful = true
                    } else {
                        root.lyricsModel = [{time: 0, text: "暂无歌词"}]
                        root.currentLineIndex = 0
                        root.lastFetchSuccessful = false
                    }
                } catch (e) {
                    root.lyricsModel = [{time: 0, text: "歌词错误"}]
                    root.currentLineIndex = 0
                    root.lastFetchSuccessful = false
                }
            }
        }
    }

    onTrackTitleChanged: triggerReload()
    onTrackArtistChanged: triggerReload()
    onTrackUrlChanged: triggerReload()
    onActiveChanged: {
        if (active && (root.trackTitle !== root.currentLoadedTitle || !root.lastFetchSuccessful)) {
            triggerReload()
        }
    }
    onIsMusicChanged: triggerReload()

    function triggerReload() {
        if (!root.active) return
        if (lyricsFetcher.running) lyricsFetcher.running = false
        debounceTimer.restart()
    }

    Timer {
        id: debounceTimer
        interval: Sizes.lyricsCapsule.reloadDebounceMs
        repeat: false
        onTriggered: {
            if (!root.isMusic) {
                // 非音乐：直接把标题作为单行展示，跳过歌词抓取
                root.lyricsModel = root.trackTitle !== ""
                    ? [{time: 0, text: root.trackTitle}]
                    : []
                root.currentLineIndex = 0
                root.currentLoadedTitle = root.trackTitle
                root.lastFetchSuccessful = true
                return
            }
            if (root.trackTitle !== "") { 
                root.lyricsModel = [{time: 0, text: "🎵 正在搜寻歌词..."}]
                root.currentLineIndex = 0
                root.lastFetchSuccessful = false
                lyricsFetcher.running = true 
            }
        }
    }

    // ================= 2. 极简同步逻辑 =================
    function syncLyrics() {
        if (!root.player || root.lyricsModel.length === 0) return
        var rawPos = root.player.position
        var currentSec = (rawPos > 100000) ? (rawPos / 1000000) : rawPos
        var activeIdx = 0
        for (var i = 0; i < root.lyricsModel.length; i++) {
            if (root.lyricsModel[i].time <= (currentSec + 0.5)) activeIdx = i; else break
        }
        if (activeIdx !== root.currentLineIndex) {
            root.currentLineIndex = activeIdx
        }
    }

    // 轮询（正常播放时逐行推进）
    Timer {
        interval: Sizes.lyricsCapsule.syncPollMs
        running: root.active && root.lyricsModel.length > 1 && root.player
        repeat: true
        onTriggered: root.syncLyrics()
    }

    // 拖动进度条时 positionChanged 立即触发，无需等待轮询
    Connections {
        target: root.player
        enabled: root.active && root.lyricsModel.length > 1
        function onPositionChanged() { root.syncLyrics() }
    }

    // ================= 3. 界面层 =================
    Item {
        anchors.fill: parent
        clip: true

        Item {
            id: albumCoverContainer
            anchors.left: parent.left
            anchors.leftMargin: root.horizontalPadding
            anchors.verticalCenter: parent.verticalCenter
            width: root.coverWidth
            height: root.coverWidth

            Image {
                id: coverImg; anchors.fill: parent
                source: root.artUrl; visible: root.artUrl !== ""; fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: ShaderEffectSource { sourceItem: Rectangle { width: coverImg.width; height: coverImg.height; radius: Sizes.rounding.xsm; color: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, 1.0) } }
                }
            }
            Text {
                visible: root.artUrl === ""; anchors.centerIn: parent
                text: "\uf001"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: Sizes.font.lg
                color: Qt.rgba(Colorscheme.on_surface_variant.r, Colorscheme.on_surface_variant.g, Colorscheme.on_surface_variant.b, 0.78)
            }
        }

        Item {
            id: spectrumContainer
            anchors.right: parent.right
            anchors.rightMargin: root.horizontalPadding
            anchors.verticalCenter: parent.verticalCenter
            width: root.spectrumWidth
            height: Sizes.lyricsCapsule.spectrumHeight

            property var smoothValues: [0, 0, 0, 0, 0, 0]

            Timer {
                interval: Sizes.lyricsCapsule.spectrumTickMs
                running: root.active && CavaService.cavaAvailable
                repeat: true
                onTriggered: {
                    let s = spectrumContainer.smoothValues;
                    let r = CavaService.values;
                    if (!r || r.length < 30) return;
                
                    // 核心1：频段聚合函数 (找出该区间的能量最大值，绝不遗漏)
                    let getRegionMax = (start, end) => {
                        let maxV = 0;
                        for (let i = start; i <= end; i++) {
                            if (r[i] > maxV) maxV = r[i];
                        }
                        return maxV;
                    };

                    let targets = [0, 0, 0, 0, 0, 0];
                
                    // 核心2：对称式频率分布映射
                    // 柱 0, 5 (最外侧)：高频 (人声唇齿音、镲片)，高频能量天生弱，乘以 1.5 倍补偿
                    targets[0] = getRegionMax(16, 22) * 1.5;
                    targets[5] = getRegionMax(23, 29) * 1.5;
                
                    // 柱 1, 4 (内侧)：中频 (吉他、主唱)，乘以 1.2 倍补偿
                    targets[1] = getRegionMax(6, 10) * 1.2;
                    targets[4] = getRegionMax(11, 15) * 1.2;
                
                    // 柱 2, 3 (正中间)：重低频 (底鼓、贝斯)，音乐动力的心脏
                    targets[2] = getRegionMax(0, 2);
                    targets[3] = getRegionMax(3, 5);

                    // 核心3：提取全局重音节拍
                    let globalBeat = Math.max(targets[2], targets[3]);

                    for (let i = 0; i < 6; i++) {
                        // 核心4：混合共振引擎
                        // 自身频段占 80%，全局重低音占 20%。让即使没有高频的鼓点，也能带动旁边柱子微微颤动
                        let finalTarget = Math.min(100, targets[i] * 0.8 + globalBeat * 0.2);
                    
                        let diff = finalTarget - s[i];
                    
                        // 物理阻尼优化：攻击(Attack)极快，释放(Release)像果冻一样粘滞
                        if (diff > 0) s[i] += 0.85 * diff; // 爆发速度提升，完美卡点
                        else s[i] += 0.08 * diff;          // 下落拖影加长，增强顺滑感
                    }
                
                    spectrumContainer.smoothValues = s;
                    spectrumCanvas.requestPaint();
                }
            }

            Canvas {
                id: spectrumCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    let s = parent.smoothValues;
                
                    ctx.beginPath();
                    ctx.lineCap = "round"; 
                    ctx.lineWidth = 2.5;   
                    ctx.strokeStyle = String(Colorscheme.primary); 

                    for(let i = 0; i < 6; i++) {
                        let val = Math.min(1.0, s[i] / 100.0);
                        let h = Math.max(3, val * height); // 最低保持 3px 圆点
                    
                        let x = 1.25 + i * 3.7; 
                    
                        ctx.moveTo(x, height / 2 - h / 2);
                        ctx.lineTo(x, height / 2 + h / 2);
                    }
                    ctx.stroke();
                }
            }
        }

        Item {
            id: lyricsSection
            anchors.left: albumCoverContainer.right
            anchors.leftMargin: root.sectionGap
            anchors.right: spectrumContainer.left
            anchors.rightMargin: root.sectionGap
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            clip: true

            ListView {
                id: lyricsView
                anchors.fill: parent

                interactive: false
                model: root.lyricsModel
                currentIndex: root.currentLineIndex

                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: 0
                highlightMoveDuration: 400

                delegate: Item {
                    id: delegateItem
                    width: ListView.view.width
                    height: Sizes.lyricsCapsule.lyricRowHeight
                    clip: true
                    property bool isCurrent: ListView.isCurrentItem
                    property real scrollDistance: Math.max(0, lyricText.implicitWidth - delegateItem.width)

                    onIsCurrentChanged: {
                        lyricText.x = 0
                        scrollAnim.stop()
                        if (isCurrent) {
                            root.currentTextWidth = Math.max(root.defaultTextWidth, Math.min(Math.ceil(lyricText.implicitWidth / Sizes.islandScale) + 16, 600))
                            if (scrollDistance > 0) marqueeDelay.restart()
                        } else {
                            marqueeDelay.stop()
                        }
                    }

                    Timer {
                        id: marqueeDelay
                        interval: Sizes.lyricsCapsule.marqueeDelayMs
                        repeat: false
                        onTriggered: {
                            if (delegateItem.isCurrent && delegateItem.scrollDistance > 0)
                                scrollAnim.restart()
                        }
                    }

                    SequentialAnimation {
                        id: scrollAnim; loops: Animation.Infinite
                        NumberAnimation {
                            target: lyricText; property: "x"
                            to: -delegateItem.scrollDistance
                            duration: delegateItem.scrollDistance * 22
                            easing.type: Easing.Linear
                        }
                        PauseAnimation { duration: 800 }
                        NumberAnimation { target: lyricText; property: "x"; to: 0; duration: 350; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: 600 }
                    }

                    Text {
                        id: lyricText
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text
                        color: Colorscheme.on_background
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.font.body
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignLeft
                    }
                }
            }
        }
    }
}
