// UpdListCard — updates 页包列表卡
//
// 照 ~/Documents/qsl-v-designs.html：包名（等宽）+ 旧→新版本（等宽），不带图标
//   AUR                                            2
//   yay                                 12.4.2 → 12.5.0
//   官方仓库                                       10
//   linux                               6.16.1 → 6.17.2
// AUR / 官方分节保留（设计说 updates「结构基本不变」），空节连标题一起不出现
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
// 模型是 Updates 的增量 ListModel，新包才有 add/displaced 过渡可播

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: col.implicitHeight + Size.spacing.lg * 2

    // 首次填充不播行动画：那一拍容器自己的派生动画正在跑。一次性，触发完自己停
    property bool rowAnim: false
    Timer {
        interval: Size.anim.durNormal + 400
        running: true
        onTriggered: root.rowAnim = true
    }

    // 吃掉点击，避免穿透到 RailPage 点空白关闭层
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    // 一节 = 标题 + 列表；两节共用同一套排版
    component PkgSection: ColumnLayout {
        id: sec

        required property string title
        required property var rowModel
        // 分节色：标题和本节各行的新版本号都用它，所以一眼能看出这包打哪来
        required property color accent

        spacing: Size.spacing.xs
        visible: sec.rowModel.count > 0

        QslSectionHeader {
            Layout.fillWidth: true
            title: sec.title
            titleColor: sec.accent
            note: String(sec.rowModel.count)
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(320, contentHeight)
            clip: true
            spacing: 0
            reuseItems: true
            interactive: contentHeight > height
            model: sec.rowModel
            boundsBehavior: Flickable.StopAtBounds

            // **不要 add / remove**：那两条动的是透明度，被打断就冻在中途不回来
            // ——屏幕上是一行半透明的东西叠在别的行上，滚两下才消失。delegate 根
            // QslRow 上还挂着 Behavior on opacity，和过渡抢同一个属性，更容易断。
            // 完整证据见 ui/clipboard/ClipCard.qml 同一处。
            // 位置类的 displaced/move 留着：打断了下一次布局会自己纠正
            // 首次填充不播，见 root.rowAnim
            displaced: Transition {
                enabled: root.rowAnim
                Anim { properties: "x,y"; type: Anim.SpatialFast }
            }

            delegate: QslRow {
                required property var pkg

                width: list.width
                height: implicitHeight

                // 包行不带图标（设计如此），包名和版本都走等宽
                title: pkg ? (pkg.name || "") : ""
                titleMono: true

                // 旧 → 新拆成三段上色：旧版本压成灰色，箭头再暗一档（它只是标点），
                // 新版本吃分节色。要看的就是"要升到几"，让它是这行里最亮的
                Row {
                    id: ver
                    spacing: 0

                    readonly property string fromVer: pkg ? (pkg.from || "") : ""
                    readonly property string toVer: pkg ? (pkg.to || "") : ""

                    Text {
                        visible: text !== ""
                        text: ver.fromVer
                        font.family: Size.fontMono
                        font.pixelSize: Size.fontSize.labelSmall
                        color: Color.textMuted
                    }
                    Text {
                        visible: ver.fromVer !== "" && ver.toVer !== ""
                        text: " → "
                        font.family: Size.fontMono
                        font.pixelSize: Size.fontSize.labelSmall
                        color: Color.outline
                    }
                    Text {
                        visible: text !== ""
                        text: ver.toVer
                        font.family: Size.fontMono
                        font.pixelSize: Size.fontSize.labelSmall
                        color: sec.accent
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Size.spacing.lg
        spacing: Size.spacing.md

        // AUR 置顶（通常更少）；官方仓在后
        // 配色都取自主题（跟着壁纸走），不写死绿橙：tertiary 淡紫给 AUR，
        // primary 青给官方仓——官方是"常规"，所以用面板到处在用的那个主色
        PkgSection {
            Layout.fillWidth: true
            title: "AUR"
            accent: Color.tertiary
            rowModel: Updates.aurRows
        }

        PkgSection {
            Layout.fillWidth: true
            title: "官方仓库"
            accent: Color.primary
            rowModel: Updates.officialRows
        }

        Text {
            Layout.fillWidth: true
            visible: !Updates.loading
                && Updates.aurRows.count === 0
                && Updates.officialRows.count === 0
            horizontalAlignment: Text.AlignHCenter
            text: Updates.ok ? "暂无可用更新" : "检查失败，点上面的检查重试"
            color: Color.textMuted
            font.pixelSize: Size.fontSize.bodySmall
        }
    }
}
