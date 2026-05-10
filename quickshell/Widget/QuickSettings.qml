import QtQuick
import QtQuick.Layouts
import qs.config
import qs.Widget.common

Item {
    id: root

    Loader {
        id: contentLoader
        anchors.fill: parent
        sourceComponent: WidgetState.qsView === "audio"
            ? audioContentComponent
            : (WidgetState.qsView === "bluetooth"
                ? bluetoothContentComponent
                : (WidgetState.qsView === "updates"
                    ? updatesContentComponent
                    : networkContentComponent))
    }

    Component {
        id: networkContentComponent

        NetworkContent {
            anchors.fill: parent
        }
    }

    Component {
        id: audioContentComponent

        AudioContent {
            anchors.fill: parent
        }
    }

    Component {
        id: bluetoothContentComponent

        BluetoothContent {
            anchors.fill: parent
        }
    }

    Component {
        id: updatesContentComponent

        UpdatesContent {
            anchors.fill: parent
        }
    }
}
