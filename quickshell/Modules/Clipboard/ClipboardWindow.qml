import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Modules.Clipboard

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

    WlrLayershell.namespace: "clipboard-overlay"
    WlrLayershell.layer: WidgetState.shouldOverlayTransient(root.visible) ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    function openWindow()  { visible = true; }
    function closeWindow() { visible = false; }
    function toggleWindow(){ visible = !visible; }

    onVisibleChanged: {
        if (visible) {
            clipboardPage.searchQuery = "";
            ClipboardStore.searchKeyword = "";
            ClipboardStore.refresh();
            clipboardPage.scheduleRebuildRows();
            clipboardPage.selectedGlobalIndex = 0;
            clipboardPage.expandedTextMode = false;
            clipboardPage.forceSearchFocus();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeWindow()
    }

    ClipboardPage {
        id: clipboardPage
        width: 1008
        height: 567
        anchors.centerIn: parent
        onRequestClosePage: root.closeWindow()
    }
}
