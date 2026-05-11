import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.config
import qs.Modules.DynamicIsland.OverviewContent

Item {
    id: root
    readonly property var chargingProfiles: ["high_capacity", "balanced", "stationary"]
    property int pageIndex: 0

    function chargingProfileIcon(profile) {
        if (profile === "high_capacity")
            return ""
        if (profile === "balanced")
            return ""
        return ""
    }

    function chargingProfileLabel(profile) {
        if (profile === "high_capacity")
            return "高容量"
        if (profile === "balanced")
            return "均衡"
        return "常驻"
    }

    function chargingProfileShort(profile) {
        if (profile === "high_capacity")
            return "高"
        if (profile === "balanced")
            return "均"
        return "驻"
    }

    function nextChargingProfile(current) {
        const i = chargingProfiles.indexOf(current)
        const start = i < 0 ? 0 : i
        return chargingProfiles[(start + 1) % chargingProfiles.length]
    }

    function formatHour(value) {
        const h = Math.max(0, Math.min(23, Math.round(Number(value))))
        return (h < 10 ? "0" : "") + String(h) + ":00"
    }

    function iconVerticalOffset(icon) {
        const g = String(icon || "")
        if (g === "")
            return 1
        return 0
    }

    function iconHorizontalOffset(icon) {
        const g = String(icon || "")
        if (g === "")
            return 1
        return 0
    }

    component ControlTile : Rectangle {
        id: tile
        property string icon: ""
        property string title: ""
        property bool active: false
        property bool compact: false
        property color accentColor: Colorscheme.primary
        property color iconActiveColor: Colorscheme.on_primary

        signal clicked()

        radius: active ? Sizes.rounding.normalPlus : Sizes.rounding.pill
        color: active
            ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
            : Colorscheme.surface_container_highest
        border.width: active ? 1 : 0
        border.color: active
            ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.42)
            : "transparent"

        Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 220 } }
        Behavior on border.color { ColorAnimation { duration: 220 } }

        scale: tileArea.pressed ? 0.96 : (tileArea.containsMouse ? 1.01 : 1.0)
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        RowLayout {
            id: normalContent
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            spacing: Sizes.spacing.sm
            visible: !tile.compact
            opacity: tile.compact ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Sizes.rounding.full
                color: tile.active ? tile.accentColor : Colorscheme.surface_variant

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.iconHorizontalOffset(tile.icon)
                    anchors.verticalCenterOffset: root.iconVerticalOffset(tile.icon)
                    text: tile.icon
                    color: tile.active ? tile.iconActiveColor : Colorscheme.on_surface
                    font.family: Sizes.fontAwesome
                    font.pixelSize: Sizes.controlCenter.tileIconFont
                }
            }

            Text {
                Layout.fillWidth: true
                text: tile.title
                color: Colorscheme.on_surface
                font.pixelSize: Sizes.controlCenter.tileTitleFont
                font.bold: true
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        Item {
            anchors.fill: parent
            visible: tile.compact
            opacity: tile.compact ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Rectangle {
                anchors.centerIn: parent
                width: 34
                height: 34
                radius: Sizes.rounding.full
                color: tile.active ? tile.accentColor : Colorscheme.surface_variant

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.iconHorizontalOffset(tile.icon)
                    anchors.verticalCenterOffset: root.iconVerticalOffset(tile.icon)
                    text: tile.icon
                    color: tile.active ? tile.iconActiveColor : Colorscheme.on_surface
                    font.family: Sizes.fontAwesome
                    font.pixelSize: Sizes.controlCenter.tileIconFont
                }
            }
        }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    component ChargingProfileTile : Rectangle {
        id: tile
        property bool expanded: hoverArea.containsMouse

        readonly property string currentProfile: ControlBackend.chargingProfile

        radius: Sizes.rounding.pill
        color: Colorscheme.secondary_container

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: Sizes.spacing.xs

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Sizes.rounding.full
                color: Colorscheme.secondary

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.iconHorizontalOffset(root.chargingProfileIcon(tile.currentProfile))
                    anchors.verticalCenterOffset: root.iconVerticalOffset(root.chargingProfileIcon(tile.currentProfile))
                    text: root.chargingProfileIcon(tile.currentProfile)
                    color: Colorscheme.on_secondary
                    font.family: Sizes.fontAwesome
                    font.pixelSize: Sizes.controlCenter.chargingCurrentIconFont
                    renderType: Text.NativeRendering
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 34

                Text {
                    anchors.fill: parent
                    text: root.chargingProfileLabel(tile.currentProfile)
                    color: Colorscheme.on_secondary_container
                    font.pixelSize: Sizes.controlCenter.chargingLabelFont
                    font.bold: true
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    visible: !tile.expanded
                    opacity: tile.expanded ? 0.0 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Row {
                    id: expandedProfiles
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    spacing: 6
                    visible: tile.expanded
                    opacity: tile.expanded ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    Repeater {
                        model: root.chargingProfiles

                        delegate: Rectangle {
                            required property string modelData
                            readonly property bool active: tile.currentProfile === modelData

                            width: Math.max(28, Math.floor((expandedProfiles.width - expandedProfiles.spacing * 2) / 3))
                            height: expandedProfiles.height
                            radius: Sizes.rounding.normal
                            color: active ? Qt.alpha(Colorscheme.on_secondary_container, 0.20) : "transparent"
                            border.width: active ? 1 : 0
                            border.color: active ? Qt.alpha(Colorscheme.on_secondary_container, 0.34) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: root.iconHorizontalOffset(root.chargingProfileIcon(modelData))
                                anchors.verticalCenterOffset: root.iconVerticalOffset(root.chargingProfileIcon(modelData))
                                text: root.chargingProfileIcon(modelData)
                                font.family: Sizes.fontAwesome
                                font.pixelSize: Sizes.controlCenter.chargingExpandedIconFont
                                color: Colorscheme.on_secondary_container
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ControlBackend.setChargingProfile(parent.modelData)
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        MouseArea {
            anchors.fill: parent
            visible: !tile.expanded
            cursorShape: Qt.PointingHandCursor
            onClicked: ControlBackend.setChargingProfile(root.nextChargingProfile(tile.currentProfile))
        }
    }

    component PrefSwitchChip : Rectangle {
        id: chip
        property string icon: ""
        property string title: ""
        property bool checked: false
        property bool chipEnabled: true
        property color activeColor: Colorscheme.primary
        property bool compact: false
        property bool showStateText: true

        readonly property string stateText: checked ? "on" : "off"

        signal toggled()

        implicitHeight: 36
        radius: Sizes.rounding.chip
        color: checked ? Qt.alpha(activeColor, 0.16) : Qt.alpha(Colorscheme.on_surface, 0.08)
        opacity: chipEnabled ? 1.0 : 0.45
        scale: chipArea.pressed ? 0.94 : (chipArea.containsMouse ? 1.02 : 1.0)

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            Text {
                text: chip.icon
                color: chip.checked ? chip.activeColor : Colorscheme.on_surface
                font.family: Sizes.fontAwesome
                font.pixelSize: Sizes.controlCenter.prefsChipIconFont
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                Layout.fillWidth: true
                text: chip.title
                color: Colorscheme.on_surface
                font.pixelSize: Sizes.controlCenter.prefsChipLabelFont
                font.bold: true
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                visible: !chip.compact
            }

            Text {
                Layout.preferredWidth: 28
                text: chip.stateText
                color: chip.checked ? chip.activeColor : Qt.alpha(Colorscheme.on_surface, 0.62)
                font.pixelSize: Sizes.controlCenter.prefsHintFont
                font.bold: true
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                visible: chip.showStateText && !chip.compact
            }
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: chip.chipEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (chip.chipEnabled)
                    chip.toggled()
            }
        }
    }

    component PrefSliderRow : Item {
        id: row
        property string title: ""
        property int value: 0
        property int minValue: 0
        property int maxValue: 100
        property bool rowEnabled: true
        property string valueSuffix: "°"

        signal valueCommitted(int value)

        readonly property int displayValue: Math.round(value)

        implicitHeight: 36
        opacity: rowEnabled ? 1.0 : 0.45

        RowLayout {
            anchors.fill: parent
            spacing: 8

            Text {
                Layout.preferredWidth: 72
                text: row.title
                color: Colorscheme.on_surface
                font.pixelSize: Sizes.controlCenter.prefsSliderLabelFont
                font.bold: true
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 24

                Item {
                    anchors.fill: parent

                    Rectangle {
                        anchors.fill: parent
                        radius: Sizes.rounding.small
                        color: Colorscheme.surface_container_lowest

                        Rectangle {
                            id: sliderRail
                            x: 6
                            width: parent.width - 12
                            height: 4
                            y: parent.height / 2 - height / 2
                            radius: Sizes.rounding.xxs
                            color: Colorscheme.surface_container_highest

                            Rectangle {
                                width: Math.max(4, hSlider.visualPosition * sliderRail.width)
                                height: sliderRail.height
                                radius: Sizes.rounding.xxs
                                color: Colorscheme.primary
                            }
                        }
                    }
                }

                Slider {
                    id: hSlider
                    anchors.fill: parent
                    leftPadding: 6
                    rightPadding: 6
                    topPadding: 0
                    bottomPadding: 0
                    from: row.minValue
                    to: row.maxValue
                    stepSize: 1
                    enabled: row.rowEnabled
                    hoverEnabled: true
                    value: row.value
                    background: Item {}

                    onMoved: row.valueCommitted(Math.round(value))
                    onValueChanged: {
                        if (pressed)
                            row.valueCommitted(Math.round(value))
                    }

                    handle: Rectangle {
                        x: hSlider.leftPadding + hSlider.visualPosition * (hSlider.availableWidth - width)
                        y: hSlider.topPadding + hSlider.availableHeight / 2 - height / 2
                        width: 12
                        height: 12
                        radius: Sizes.rounding.sm
                        color: Colorscheme.primary

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 8
                            width: 46
                            height: 28
                            visible: hSlider.pressed || hSlider.hovered
                            opacity: visible ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Rectangle {
                                anchors.fill: parent
                                radius: Sizes.rounding.xl
                                color: Colorscheme.primary_container
                            }

                            Rectangle {
                                width: 10
                                height: 10
                                radius: Sizes.rounding.xxs
                                color: Colorscheme.primary_container
                                rotation: 45
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -5
                                z: -1
                            }

                            Text {
                                anchors.centerIn: parent
                                text: String(row.displayValue) + row.valueSuffix
                                color: Colorscheme.on_primary_container
                                font.pixelSize: Sizes.controlCenter.prefsSliderValueFont
                                font.bold: true
                                font.family: Sizes.fontFamilyMono
                            }
                        }
                    }
                }
            }

            Text {
                Layout.preferredWidth: 42
                text: String(row.displayValue) + row.valueSuffix
                color: Colorscheme.on_surface
                font.pixelSize: Sizes.controlCenter.prefsSliderValueFont
                font.bold: true
                font.family: Sizes.fontFamilyMono
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    component CornerBtn : Rectangle {
        property string icon: ""
        property color bgColor: "transparent"
        property color fgColor: "white"

        signal clicked()

        width: 48
        height: 48
        radius: Sizes.rounding.chip 
        color: bgColor
        
        scale: btnArea.pressed ? 0.85 : (btnArea.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: icon
            color: fgColor 
            font.family: Sizes.fontAwesome
            font.pixelSize: Sizes.controlCenter.cornerIconFont
        }

        MouseArea { 
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor 
            onClicked: parent.clicked()
        }
    }


    // ============================================================
    // 【网格布局】
    // ============================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: Sizes.spacing.md

        Item {
            id: rowTop
            Layout.fillWidth: true
            Layout.preferredHeight: 52

            property real gap: Sizes.spacing.sm
            property real tileWidth: Math.max(96, (width - gap) / 2)

            ControlTile {
                x: 0
                y: 0
                width: rowTop.tileWidth
                height: rowTop.height
                icon: ""
                title: "Wi-Fi"
                active: ControlBackend.wifiEnabled
                onClicked: ControlBackend.toggleWifi()
            }

            ControlTile {
                x: rowTop.tileWidth + rowTop.gap
                y: 0
                width: rowTop.tileWidth
                height: rowTop.height
                icon: ""
                title: "蓝牙"
                active: ControlBackend.bluetoothEnabled
                onClicked: ControlBackend.toggleBluetooth()
            }
        }

        Item {
            id: rowMid
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            clip: true

            property real gap: Sizes.spacing.sm
            property real minOtherWidth: 58
            property real collapsedChargeWidth: 126
            property real maxExpandedChargeWidth: Math.min(236, Math.max(collapsedChargeWidth, width - gap * 2 - minOtherWidth * 2))
            property real chargeWidth: chargingTile.expanded ? maxExpandedChargeWidth : collapsedChargeWidth
            property real otherWidth: Math.max(minOtherWidth, (width - gap * 2 - chargeWidth) / 2)

            ChargingProfileTile {
                id: chargingTile
                x: 0
                y: 0
                width: rowMid.chargeWidth
                height: rowMid.height

                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            ControlTile {
                x: rowMid.chargeWidth + rowMid.gap
                y: 0
                width: rowMid.otherWidth
                height: rowMid.height
                compact: rowMid.otherWidth < 88
                icon: ""
                title: "免打扰"
                active: ControlBackend.dndEnabled
                accentColor: Colorscheme.tertiary
                iconActiveColor: Colorscheme.on_tertiary
                onClicked: ControlBackend.toggleDnd()

                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            ControlTile {
                x: rowMid.chargeWidth + rowMid.gap + rowMid.otherWidth + rowMid.gap
                y: 0
                width: rowMid.otherWidth
                height: rowMid.height
                compact: rowMid.otherWidth < 88
                icon: ""
                title: "重载"
                accentColor: Colorscheme.secondary
                iconActiveColor: Colorscheme.on_secondary
                onClicked: Quickshell.execDetached(["qs", "reload"])

                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }
        }

        Item {
            id: pagerViewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 180
            clip: true

            Row {
                id: pageRow
                x: -root.pageIndex * pagerViewport.width
                width: pagerViewport.width * 2
                height: pagerViewport.height

                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: pagerViewport.width
                    height: pagerViewport.height
                    radius: Sizes.rounding.normalPlus
                    color: Qt.alpha(Colorscheme.surface_container_highest, 0.94)
                    border.width: 1
                    border.color: Qt.alpha(Colorscheme.on_surface, 0.08)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "控制中心"
                                color: Colorscheme.on_surface
                                font.pixelSize: Sizes.controlCenter.prefsHeaderFont
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Rectangle {
                            id: openPrefsBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 74
                            radius: Sizes.rounding.chip
                            color: openPrefsArea.containsMouse
                                ? Qt.alpha(Colorscheme.primary, 0.16)
                                : Qt.alpha(Colorscheme.on_surface, 0.08)
                            scale: openPrefsArea.pressed ? 0.97 : (openPrefsArea.containsMouse ? 1.01 : 1.0)

                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Item {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: root.iconHorizontalOffset("")
                                        anchors.verticalCenterOffset: root.iconVerticalOffset("")
                                        text: ""
                                        color: Colorscheme.primary
                                        font.family: Sizes.fontAwesome
                                        font.pixelSize: Sizes.controlCenter.tileIconFont
                                        renderType: Text.NativeRendering
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "灵动岛事件设置"
                                        color: Colorscheme.on_surface
                                        font.pixelSize: Sizes.controlCenter.tileTitleFont
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: "通知开关、阈值与静默时段"
                                        color: Qt.alpha(Colorscheme.on_surface, 0.65)
                                        font.pixelSize: Sizes.controlCenter.prefsHintFont
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    text: ""
                                    color: Colorscheme.primary
                                    font.family: Sizes.fontAwesome
                                    font.pixelSize: Sizes.controlCenter.prefsChipIconFont
                                }
                            }

                            MouseArea {
                                id: openPrefsArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pageIndex = 1
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                Rectangle {
                    id: eventPrefsCard
                    width: pagerViewport.width
                    height: pagerViewport.height
                    radius: Sizes.rounding.normalPlus
                    color: Qt.alpha(Colorscheme.surface_container_highest, 0.94)
                    border.width: 1
                    border.color: Qt.alpha(Colorscheme.on_surface, 0.08)
                    clip: true

                    Flickable {
                        id: prefsScroll
                        anchors.fill: parent
                        anchors.margins: 10
                        contentWidth: width
                        contentHeight: prefsColumn.implicitHeight
                        interactive: contentHeight > height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: prefsColumn
                            width: prefsScroll.width
                            spacing: 8

                            RowLayout {
                                width: parent.width
                                spacing: 6

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: Sizes.rounding.chip
                                    color: Qt.alpha(Colorscheme.on_surface, 0.08)
                                    scale: backArea.pressed ? 0.92 : (backArea.containsMouse ? 1.03 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: ""
                                        color: Colorscheme.on_surface
                                        font.family: Sizes.fontAwesome
                                        font.pixelSize: Sizes.controlCenter.prefsChipIconFont
                                    }

                                    MouseArea {
                                        id: backArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.pageIndex = 0
                                    }
                                }

                                Text {
                                    text: "灵动岛事件"
                                    color: Colorscheme.on_surface
                                    font.pixelSize: Sizes.controlCenter.prefsHeaderFont
                                    font.bold: true
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Flow {
                                width: parent.width
                                spacing: 6

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "总开关"
                                    checked: DynamicIslandPrefs.enabled
                                    onToggled: DynamicIslandPrefs.enabled = !DynamicIslandPrefs.enabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "连接态"
                                    activeColor: Colorscheme.secondary
                                    checked: DynamicIslandPrefs.connectionEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled
                                    onToggled: DynamicIslandPrefs.connectionEnabled = !DynamicIslandPrefs.connectionEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "LianClaw"
                                    activeColor: Colorscheme.tertiary
                                    checked: DynamicIslandPrefs.lianclawEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled
                                    onToggled: DynamicIslandPrefs.lianclawEnabled = !DynamicIslandPrefs.lianclawEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "资源告警"
                                    activeColor: Colorscheme.primary
                                    checked: DynamicIslandPrefs.resourcesEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled
                                    onToggled: DynamicIslandPrefs.resourcesEnabled = !DynamicIslandPrefs.resourcesEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "电源/存储"
                                    activeColor: Colorscheme.secondary
                                    checked: DynamicIslandPrefs.powerStorageEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled
                                    onToggled: DynamicIslandPrefs.powerStorageEnabled = !DynamicIslandPrefs.powerStorageEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "静默时段"
                                    activeColor: Colorscheme.tertiary
                                    checked: DynamicIslandPrefs.quietHoursEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled
                                    onToggled: DynamicIslandPrefs.quietHoursEnabled = !DynamicIslandPrefs.quietHoursEnabled
                                }
                            }

                            Text {
                                width: parent.width
                                text: "连接子项"
                                color: Qt.alpha(Colorscheme.on_surface, 0.72)
                                font.pixelSize: Sizes.controlCenter.prefsSectionFont
                                font.bold: true
                            }

                            Flow {
                                width: parent.width
                                spacing: 6

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "Wi-Fi"
                                    activeColor: Colorscheme.secondary
                                    checked: DynamicIslandPrefs.wifiEventEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.connectionEnabled
                                    onToggled: DynamicIslandPrefs.wifiEventEnabled = !DynamicIslandPrefs.wifiEventEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "蓝牙"
                                    activeColor: Colorscheme.secondary
                                    checked: DynamicIslandPrefs.bluetoothEventEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.connectionEnabled
                                    onToggled: DynamicIslandPrefs.bluetoothEventEnabled = !DynamicIslandPrefs.bluetoothEventEnabled
                                }
                            }

                            Text {
                                width: parent.width
                                text: "LianClaw 子项"
                                color: Qt.alpha(Colorscheme.on_surface, 0.72)
                                font.pixelSize: Sizes.controlCenter.prefsSectionFont
                                font.bold: true
                            }

                            Flow {
                                width: parent.width
                                spacing: 6

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "等待确认"
                                    activeColor: Colorscheme.tertiary
                                    checked: DynamicIslandPrefs.lianclawConfirmEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.lianclawEnabled
                                    onToggled: DynamicIslandPrefs.lianclawConfirmEnabled = !DynamicIslandPrefs.lianclawConfirmEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "等待表单"
                                    activeColor: Colorscheme.tertiary
                                    checked: DynamicIslandPrefs.lianclawFormEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.lianclawEnabled
                                    onToggled: DynamicIslandPrefs.lianclawFormEnabled = !DynamicIslandPrefs.lianclawFormEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "回复完成"
                                    activeColor: Colorscheme.tertiary
                                    checked: DynamicIslandPrefs.lianclawDoneEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.lianclawEnabled
                                    onToggled: DynamicIslandPrefs.lianclawDoneEnabled = !DynamicIslandPrefs.lianclawDoneEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "回复失败"
                                    activeColor: Colorscheme.error
                                    checked: DynamicIslandPrefs.lianclawFailEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.lianclawEnabled
                                    onToggled: DynamicIslandPrefs.lianclawFailEnabled = !DynamicIslandPrefs.lianclawFailEnabled
                                }
                            }

                            Text {
                                width: parent.width
                                text: "资源子项"
                                color: Qt.alpha(Colorscheme.on_surface, 0.72)
                                font.pixelSize: Sizes.controlCenter.prefsSectionFont
                                font.bold: true
                            }

                            Flow {
                                width: parent.width
                                spacing: 6

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "CPU 占用"
                                    checked: DynamicIslandPrefs.cpuUsageEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.resourcesEnabled
                                    onToggled: DynamicIslandPrefs.cpuUsageEnabled = !DynamicIslandPrefs.cpuUsageEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "内存占用"
                                    checked: DynamicIslandPrefs.memoryUsageEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.resourcesEnabled
                                    onToggled: DynamicIslandPrefs.memoryUsageEnabled = !DynamicIslandPrefs.memoryUsageEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "GPU 占用"
                                    checked: DynamicIslandPrefs.gpuUsageEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.resourcesEnabled
                                    onToggled: DynamicIslandPrefs.gpuUsageEnabled = !DynamicIslandPrefs.gpuUsageEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "CPU 温度"
                                    checked: DynamicIslandPrefs.cpuTempEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.resourcesEnabled
                                    onToggled: DynamicIslandPrefs.cpuTempEnabled = !DynamicIslandPrefs.cpuTempEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "GPU 温度"
                                    checked: DynamicIslandPrefs.gpuTempEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.resourcesEnabled
                                    onToggled: DynamicIslandPrefs.gpuTempEnabled = !DynamicIslandPrefs.gpuTempEnabled
                                }
                            }

                            PrefSliderRow {
                                width: parent.width
                                title: "CPU阈值"
                                minValue: 65
                                maxValue: 110
                                valueSuffix: "°"
                                rowEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.resourcesEnabled && DynamicIslandPrefs.cpuTempEnabled
                                value: DynamicIslandPrefs.cpuTempTrigger
                                onValueCommitted: DynamicIslandPrefs.setCpuTempTrigger(value)
                            }

                            PrefSliderRow {
                                width: parent.width
                                title: "GPU阈值"
                                minValue: 65
                                maxValue: 110
                                valueSuffix: "°"
                                rowEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.resourcesEnabled && DynamicIslandPrefs.gpuTempEnabled
                                value: DynamicIslandPrefs.gpuTempTrigger
                                onValueCommitted: DynamicIslandPrefs.setGpuTempTrigger(value)
                            }

                            Text {
                                width: parent.width
                                text: "电源/存储子项"
                                color: Qt.alpha(Colorscheme.on_surface, 0.72)
                                font.pixelSize: Sizes.controlCenter.prefsSectionFont
                                font.bold: true
                            }

                            Flow {
                                width: parent.width
                                spacing: 6

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "低电量"
                                    activeColor: Colorscheme.secondary
                                    checked: DynamicIslandPrefs.lowBatteryEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.powerStorageEnabled
                                    onToggled: DynamicIslandPrefs.lowBatteryEnabled = !DynamicIslandPrefs.lowBatteryEnabled
                                }

                                PrefSwitchChip {
                                    width: (parent.width - parent.spacing) / 2
                                    icon: ""
                                    title: "磁盘高占用"
                                    activeColor: Colorscheme.secondary
                                    checked: DynamicIslandPrefs.diskUsageEnabled
                                    chipEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.powerStorageEnabled
                                    onToggled: DynamicIslandPrefs.diskUsageEnabled = !DynamicIslandPrefs.diskUsageEnabled
                                }
                            }

                            Text {
                                width: parent.width
                                text: "防打扰"
                                color: Qt.alpha(Colorscheme.on_surface, 0.72)
                                font.pixelSize: Sizes.controlCenter.prefsSectionFont
                                font.bold: true
                            }

                            PrefSliderRow {
                                width: parent.width
                                title: "冷却间隔"
                                minValue: 10
                                maxValue: 600
                                valueSuffix: "s"
                                rowEnabled: DynamicIslandPrefs.enabled
                                value: DynamicIslandPrefs.duplicateCooldownSec
                                onValueCommitted: DynamicIslandPrefs.setDuplicateCooldownSec(value)
                            }

                            PrefSliderRow {
                                width: parent.width
                                title: "静默开始"
                                minValue: 0
                                maxValue: 23
                                valueSuffix: "h"
                                rowEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.quietHoursEnabled
                                value: DynamicIslandPrefs.quietStartHour
                                onValueCommitted: DynamicIslandPrefs.setQuietStartHour(value)
                            }

                            PrefSliderRow {
                                width: parent.width
                                title: "静默结束"
                                minValue: 0
                                maxValue: 23
                                valueSuffix: "h"
                                rowEnabled: DynamicIslandPrefs.enabled && DynamicIslandPrefs.quietHoursEnabled
                                value: DynamicIslandPrefs.quietEndHour
                                onValueCommitted: DynamicIslandPrefs.setQuietEndHour(value)
                            }

                            Text {
                                width: parent.width
                                text: "静默区间：" + root.formatHour(DynamicIslandPrefs.quietStartHour) + " - " + root.formatHour(DynamicIslandPrefs.quietEndHour)
                                color: Qt.alpha(Colorscheme.on_surface, 0.65)
                                font.pixelSize: Sizes.controlCenter.prefsHintFont
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Sizes.spacing.sm

            CornerBtn {
                icon: ""
                bgColor: WidgetState.leftSidebarOpen ? Qt.alpha(Colorscheme.primary, 0.15) : Qt.alpha(Colorscheme.on_surface, 0.08)
                fgColor: WidgetState.leftSidebarOpen ? Colorscheme.primary : Colorscheme.on_surface
                onClicked: WidgetState.leftSidebarOpen = !WidgetState.leftSidebarOpen
            }

            CornerBtn {
                icon: ""
                bgColor: WidgetState.notifOpen ? Qt.alpha(Colorscheme.primary, 0.15) : Qt.alpha(Colorscheme.on_surface, 0.08)
                fgColor: WidgetState.notifOpen ? Colorscheme.primary : Colorscheme.on_surface
                onClicked: WidgetState.notifOpen = !WidgetState.notifOpen
            }

            CornerBtn {
                icon: ""
                bgColor: Qt.alpha(Colorscheme.on_surface, 0.08)
                fgColor: Colorscheme.on_surface
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "clipboard", "toggle"])
            }

            Item { Layout.fillWidth: true }

            CornerBtn {
                icon: ""
                bgColor: Qt.alpha(Colorscheme.error, 0.12)
                fgColor: Colorscheme.error
                onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/wlogout/scripts/logoutlaunch.sh"])
            }
        }
    }
}
