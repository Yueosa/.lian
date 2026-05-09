import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root
    signal unlocked()
    signal failed()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false

    // 输入变化时隐藏错误提示
    onCurrentTextChanged: showFailure = false;

    function tryUnlock() {
        if (currentText === "") return;
        root.unlockInProgress = true;
        pam.start();
    }

    PamContext {
        id: pam
        // 指向 pam 文件夹的绝对路径
        configDirectory: Quickshell.env("HOME") + "/.config/quickshell/Modules/Lock/pam"
        config: "password.conf"

        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentText);
            }
        }

        onCompleted: result => {
            if (result == PamResult.Success) {
                root.unlocked();
            } else {
                root.currentText = ""; // 清空密码
                root.showFailure = true;
            }
            root.unlockInProgress = false;
        }
    }
}
