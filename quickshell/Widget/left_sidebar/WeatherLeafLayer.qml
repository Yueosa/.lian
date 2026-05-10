import QtQuick

Item {
    id: root

    property var model
    signal leafFinished(int leafId)

    Repeater {
        model: root.model

        delegate: LeafItem {
            leafId: model.leafId
            leafColor: model.color
            leafScale: model.scale
            x0: model.x0
            y0: model.y0
            x1: model.x1
            y1: model.y1
            x2: model.x2
            y2: model.y2
            startRotation: model.startRotation
            endRotation: model.endRotation
            onFinished: root.leafFinished(leafId)
        }
    }
}
