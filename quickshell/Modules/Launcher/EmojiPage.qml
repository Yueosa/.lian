import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config

Item {
    id: root
    implicitWidth: 0
    implicitHeight: 0

    signal requestClosePage()

    property string searchQuery: ""
    property var favoriteMap: ({})
    property var filteredEntries: []
    readonly property int gridColumns: width >= 900 ? 5 : (width >= 640 ? 4 : 3)

    readonly property string favoritesFile: Quickshell.env("HOME") + "/.cache/quickshell/emoji_favorites.json"
    readonly property var allEntries: [
        { char: "😀", name: "grinning face", kind: "emoji", tags: ["happy", "smile", "face", "grin", "高兴", "笑脸"] },
        { char: "😂", name: "tears of joy", kind: "emoji", tags: ["laugh", "funny", "joy", "cry", "笑哭"] },
        { char: "🥹", name: "pleading face", kind: "emoji", tags: ["cute", "please", "beg", "委屈"] },
        { char: "😍", name: "heart eyes", kind: "emoji", tags: ["love", "like", "heart", "喜欢"] },
        { char: "🥰", name: "smiling hearts", kind: "emoji", tags: ["love", "sweet", "heart", "甜"] },
        { char: "🤔", name: "thinking face", kind: "emoji", tags: ["think", "hmm", "思考"] },
        { char: "🫠", name: "melting face", kind: "emoji", tags: ["melt", "awkward", "尴尬"] },
        { char: "😭", name: "loudly crying", kind: "emoji", tags: ["sad", "cry", "崩溃"] },
        { char: "😡", name: "pouting face", kind: "emoji", tags: ["angry", "rage", "生气"] },
        { char: "😴", name: "sleeping face", kind: "emoji", tags: ["sleep", "tired", "困"] },
        { char: "🤯", name: "mind blown", kind: "emoji", tags: ["shock", "explode", "震惊"] },
        { char: "😎", name: "cool face", kind: "emoji", tags: ["cool", "sunglasses", "酷"] },
        { char: "🙏", name: "folded hands", kind: "emoji", tags: ["thanks", "pray", "please", "拜托"] },
        { char: "👍", name: "thumbs up", kind: "emoji", tags: ["ok", "good", "赞"] },
        { char: "👀", name: "eyes", kind: "emoji", tags: ["look", "watch", "偷看"] },
        { char: "✨", name: "sparkles", kind: "emoji", tags: ["sparkle", "shine", "闪"] },
        { char: "🔥", name: "fire", kind: "emoji", tags: ["hot", "fire", "燃"] },
        { char: "💀", name: "skull", kind: "emoji", tags: ["dead", "lol", "骷髅"] },
        { char: "💔", name: "broken heart", kind: "emoji", tags: ["sad", "heartbreak", "心碎"] },
        { char: "❤️", name: "red heart", kind: "emoji", tags: ["love", "heart", "爱心"] },
        { char: "🎉", name: "party popper", kind: "emoji", tags: ["party", "celebrate", "庆祝"] },
        { char: "🚀", name: "rocket", kind: "emoji", tags: ["launch", "fast", "起飞"] },
        { char: "🍜", name: "ramen", kind: "emoji", tags: ["food", "eat", "拉面"] },
        { char: "🐱", name: "cat", kind: "emoji", tags: ["pet", "cat", "猫"] },
        { char: "Ծ‸Ծ", name: "pout face", kind: "kaomoji", tags: ["kaomoji", "颜文字", "sad", "pout", "委屈", "喜欢"] },
        { char: "(╥﹏╥)", name: "crying face", kind: "kaomoji", tags: ["kaomoji", "颜文字", "cry", "难过"] },
        { char: "(っ˘̩╭╮˘̩)っ", name: "hug please", kind: "kaomoji", tags: ["kaomoji", "颜文字", "hug", "抱抱"] },
        { char: "(๑•̀ㅂ•́)و✧", name: "fighting", kind: "kaomoji", tags: ["kaomoji", "颜文字", "fight", "加油"] },
        { char: "(￣▽￣)", name: "happy smug", kind: "kaomoji", tags: ["kaomoji", "颜文字", "happy", "得意"] },
        { char: "(¬_¬)", name: "side eye", kind: "kaomoji", tags: ["kaomoji", "颜文字", "look", "无语"] },
        { char: "¯\\_(ツ)_/¯", name: "shrug", kind: "kaomoji", tags: ["kaomoji", "颜文字", "shrug", "摊手"] },
        { char: "(づ｡◕‿‿◕｡)づ", name: "big hug", kind: "kaomoji", tags: ["kaomoji", "颜文字", "hug", "贴贴"] }
    ]

    FileView {
        id: favoritesFileView
        path: root.favoritesFile
        onLoaded: {
            try {
                const parsed = JSON.parse(text())
                if (parsed && typeof parsed === "object")
                    root.favoriteMap = parsed
            } catch (e) {}
            root.refreshEntries()
        }
        onLoadFailed: {
            root.refreshEntries()
            Quickshell.execDetached(["bash", "-c",
                "mkdir -p \"$(dirname '" + root.favoritesFile.replace(/'/g, "'\\''") + "')\" && " +
                "[ -e '" + root.favoritesFile.replace(/'/g, "'\\''") + "' ] || echo '{}' > '" + root.favoritesFile.replace(/'/g, "'\\''") + "'"])
        }
    }

    Process {
        id: saveFavoritesProcess
        running: false
    }

    function forceSearchFocus() {
        searchField.forceActiveFocus()
    }

    function currentEntry() {
        if (gridView.currentIndex < 0 || gridView.currentIndex >= filteredEntries.length)
            return null
        return filteredEntries[gridView.currentIndex]
    }

    function setCurrentIndex(index) {
        if (filteredEntries.length === 0) {
            gridView.currentIndex = -1
            return
        }
        const nextIndex = Math.max(0, Math.min(index, filteredEntries.length - 1))
        gridView.currentIndex = nextIndex
        gridView.positionViewAtIndex(nextIndex, GridView.Contain)
    }

    function moveSelection(horizontalStep, verticalStep) {
        if (filteredEntries.length === 0)
            return
        const baseIndex = gridView.currentIndex >= 0 ? gridView.currentIndex : 0
        const step = horizontalStep + (verticalStep * gridColumns)
        setCurrentIndex(baseIndex + step)
    }

    function toggleCurrentFavorite() {
        const entry = currentEntry()
        if (entry)
            toggleFavorite(entry)
    }

    function isFavorite(char) {
        return !!favoriteMap[char]
    }

    function persistFavorites() {
        const json = JSON.stringify(favoriteMap)
        const dir = favoritesFile.replace(/\/[^/]*$/, "")
        saveFavoritesProcess.command = ["bash", "-c",
            "mkdir -p " + JSON.stringify(dir) + " && printf '%s' " + JSON.stringify(json) + " > " + JSON.stringify(favoritesFile)]
        saveFavoritesProcess.running = true
    }

    function toggleFavorite(entry) {
        const next = Object.assign({}, favoriteMap)
        if (next[entry.char])
            delete next[entry.char]
        else
            next[entry.char] = true
        favoriteMap = next
        persistFavorites()
        refreshEntries()
    }

    function copyEntry(entry) {
        Quickshell.execDetached(["bash", "-lc", "printf '%s' " + JSON.stringify(entry.char) + " | wl-copy"])
        requestClosePage()
    }

    function filterMatches(entry, query) {
        if (!query)
            return true
        const lower = query.toLowerCase()
        if (entry.char.indexOf(query) !== -1)
            return true
        if (entry.name.toLowerCase().indexOf(lower) !== -1)
            return true
        for (let i = 0; i < entry.tags.length; ++i) {
            if (String(entry.tags[i]).toLowerCase().indexOf(lower) !== -1)
                return true
        }
        return false
    }

    function refreshEntries() {
        const previousChar = currentEntry() ? currentEntry().char : ""
        const next = []
        for (let i = 0; i < allEntries.length; ++i) {
            const entry = allEntries[i]
            if (!filterMatches(entry, searchQuery))
                continue
            next.push({
                char: entry.char,
                name: entry.name,
                kind: entry.kind,
                tags: entry.tags,
                favorite: isFavorite(entry.char)
            })
        }

        next.sort((a, b) => {
            if (a.favorite !== b.favorite)
                return a.favorite ? -1 : 1
            if (a.kind !== b.kind)
                return a.kind === "emoji" ? -1 : 1
            return a.name.localeCompare(b.name)
        })
        filteredEntries = next

        let preferredIndex = 0
        if (previousChar) {
            const foundIndex = next.findIndex(entry => entry.char === previousChar)
            if (foundIndex >= 0)
                preferredIndex = foundIndex
        }
        Qt.callLater(() => setCurrentIndex(next.length === 0 ? -1 : preferredIndex))
    }

    Component.onCompleted: refreshEntries()
    onSearchQueryChanged: refreshEntries()
    onFavoriteMapChanged: refreshEntries()

    ColumnLayout {
        anchors.fill: parent
        spacing: Sizes.spacing.md

        Rectangle {
            Layout.minimumWidth: 0
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Sizes.rounding.normal
            color: Qt.rgba(Colorscheme.surface_container_high.r, Colorscheme.surface_container_high.g, Colorscheme.surface_container_high.b, 0.7)
            border.width: searchField.activeFocus ? 1 : 0
            border.color: Colorscheme.primary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: "search"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Sizes.font.lg
                    color: Colorscheme.on_surface_variant
                }

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: "搜索 emoji 或颜文字…"
                    background: null
                    color: Colorscheme.on_surface
                    text: root.searchQuery
                    onTextChanged: if (text !== root.searchQuery) root.searchQuery = text
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => {
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                            root.toggleCurrentFavorite()
                            event.accepted = true
                            return
                        }

                        if (event.modifiers !== Qt.NoModifier)
                            return

                        if (event.key === Qt.Key_Left) {
                            root.moveSelection(-1, 0)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Right) {
                            root.moveSelection(1, 0)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.moveSelection(0, -1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            root.moveSelection(0, 1)
                            event.accepted = true
                        }
                    }
                    Keys.onReturnPressed: event => {
                        const entry = root.currentEntry()
                        if (entry) {
                            root.copyEntry(entry)
                            event.accepted = true
                        }
                    }
                    Keys.onEscapePressed: event => {
                        if (root.searchQuery.length > 0) {
                            root.searchQuery = ""
                            event.accepted = true
                            return
                        }
                        requestClosePage()
                        event.accepted = true
                    }
                }
            }
        }

        GridView {
            id: gridView
            Layout.minimumWidth: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: Math.floor(width / root.gridColumns)
            cellHeight: 98
            clip: true
            model: root.filteredEntries
            currentIndex: root.filteredEntries.length > 0 ? 0 : -1
            boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: gridView.cellWidth - 10
                    height: gridView.cellHeight - 10
                    radius: Sizes.rounding.normal
                    color: GridView.isCurrentItem
                        ? Qt.rgba(Colorscheme.primary_container.r, Colorscheme.primary_container.g, Colorscheme.primary_container.b, 0.75)
                        : (modelData.favorite
                            ? Qt.rgba(Colorscheme.primary_container.r, Colorscheme.primary_container.g, Colorscheme.primary_container.b, 0.26)
                            : Qt.rgba(Colorscheme.surface_container_high.r, Colorscheme.surface_container_high.g, Colorscheme.surface_container_high.b, 0.55))
                    border.width: GridView.isCurrentItem ? 1 : 0
                    border.color: Colorscheme.primary

                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        width: parent.width - 12

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.char
                            font.pixelSize: modelData.kind === "kaomoji" ? 18 : 30
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: modelData.kind === "kaomoji" ? (modelData.name + " · 颜文字") : modelData.name
                            font.pixelSize: Sizes.font.sm
                            color: GridView.isCurrentItem ? Colorscheme.on_primary_container : Colorscheme.on_surface_variant
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 22
                        height: 22
                        radius: 11
                        color: modelData.favorite
                            ? Qt.rgba(Colorscheme.primary_container.r, Colorscheme.primary_container.g, Colorscheme.primary_container.b, 0.95)
                            : Qt.rgba(Colorscheme.surface_container_highest.r, Colorscheme.surface_container_highest.g, Colorscheme.surface_container_highest.b, 0.75)
                        border.width: modelData.favorite ? 1 : 0
                        border.color: modelData.favorite ? Colorscheme.primary : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.favorite ? "star" : "star_outline"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 14
                            color: modelData.favorite ? Colorscheme.on_primary_container : Colorscheme.on_surface_variant
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleFavorite(parent.parent.modelData)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            gridView.currentIndex = index
                            root.copyEntry(modelData)
                        }
                    }
                }
        }

        Text {
            Layout.alignment: Qt.AlignRight
            text: "方向键选择 · Enter 复制 · Ctrl+S 收藏"
            font.pixelSize: Sizes.font.sm
            color: Colorscheme.on_surface_variant
        }
    }
}