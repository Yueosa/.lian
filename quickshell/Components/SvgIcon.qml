pragma Singleton
import QtQuick
import Quickshell

QtObject {
    readonly property string basePath: Quickshell.env("HOME") + "/.config/quickshell/assets/icons/"

    // 注册图标值
    property string previous: basePath + "previous.svg"
    property string play: basePath + "play.svg"
    property string pause: basePath + "pause.svg"
    property string next: basePath + "next.svg"
}
