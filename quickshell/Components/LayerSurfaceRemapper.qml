import QtQuick

Item {
    id: root

    width: 0
    height: 0
    visible: false

    property var window: null
    property bool active: false
    property int remapSerial: 0
    property bool _completed: false
    property bool _restoring: false

    Component.onCompleted: _completed = true

    onRemapSerialChanged: {
        if (_completed)
            remap()
    }

    function remap() {
        if (!window || !window.visible || _restoring)
            return

        _restoring = true
        window.visible = false
        restoreTimer.restart()
    }

    Timer {
        id: restoreTimer
        interval: 32
        repeat: false
        onTriggered: {
            if (root.window)
                root.window.visible = true
            root._restoring = false
        }
    }
}