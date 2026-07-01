# qsl — Quickshell Lian

> 个人桌面 Shell 第二代。从 `quickshell/` 重构而来。
> 核心原则：自己设计架构，不继承别人的思维。

---

## 架构哲学

### Import 铁律（不可违反）

```
ui ← data ← core
 │      │
 └── component (被 ui 消费)
 └── asset (被 ui 消费)
 └── script (被 data 消费)

规则：
1. data/ 绝不 import ui/
2. ui/ 可以 import data/, component/, asset/
3. core/ (C++ 插件) 只能被 data/ import
4. 同级模块不应互相依赖
5. shell.qml 只做组装，不写逻辑
```

### ui/ 和 component/ 的边界（待最终确认）

当前定义：
- **ui/** = 屏幕/窗口/面板，应用级组件。每个套一个 `PanelWindow`，在 `shell.qml` 中实例化一次。
- **component/** = 可复用 QML 组件。不创建窗口，可以在一处或多处使用。

性能考量：
- QML 文件拆分开销极小（每个 ~1ms 解析）
- 真正的性能瓶颈是 `Item` 树深度、绑定链长度、属性变更通知风暴
- **拆分文件不会带来显著性能损失，深度嵌套 Item + 过多活跃 Binding 才会**

### 命名约定

- QML 类型文件（Singleton/Component）：PascalCase（`Time.qml`, `SvgIcon.qml`）— QML 要求类型名首字母大写
- 非 QML 文件 / 根文档：kebab-case（`shell.qml`, `weather.py`）
- 目录名：全小写（`quicksettings/`, `data/service/`）
- QML id：camelCase，有意义（`volumeSlider` 而非 `vs`）

### 数据模块注释规范

每个 `data/` 下的模块必须在文件头包含"对外接口一览"：

```qml
-- ============================================================
-- 模块名 — EnglishName
-- ============================================================
-- 一句话职责描述。
-- 关键实现细节（依赖、精度、更新频率）。
-- ============================================================
-- 对外接口一览：
--
-- 属性（readonly）：
--   propName  type     说明          例值
--
-- 方法：
--   funcName(params)   说明
-- ============================================================
```
- 属性/函数：camelCase
- 注释：中文 + 关键说明

### 从 quickshell/ 迁移过来的变化

| 旧 | 新 | 理由 |
|---|---|---|
| import qs.xxx | import qsl.xxx | 命名空间统一 |
| Clavis.Sysmon 等 | Clavis.* (不变) | C++ 插件保持 |
| `// 【新增】` `// FIXME` | 无这类注释 | 代码即文档，不留开发笔记 |
| `pragma Singleton` QML | data/ 下的 Singleton | 明确单例范围 |
| 混用的 `Item` / `Singleton` | data 层全用 Singleton，ui 层全用 PanelWindow | 类型明确 |

---

## 目录结构

```
qsl/
├── shell.qml                  # 入口，组装所有 ui/ 模块
│
├── data/                      # 数据层：纯逻辑，零 UI，零 import ui/
│   ├── state/                 #   全局状态（配色、尺寸、开关）
│   │   ├── Color.qml           #     Colorscheme
│   │   ├── Size.qml            #     Sizes
│   │   └── Widget.qml          #     WidgetState
│   │
│   └── service/               #   数据服务（Quickshell 原生 D-Bus 绑定 + 薄封装）
│       ├── Time.qml            #     时钟
│       ├── Volume.qml          #     音量 + 静音
│       ├── Media.qml           #     媒体播放器管理
│       ├── Notification.qml    #     通知管理
│       ├── Network.qml         #     网络状态 + WiFi（Quickshell.Networking）
│       ├── Bluetooth.qml       #     蓝牙设备（Quickshell.Bluetooth）
│       ├── Battery.qml         #     电池/电源（Quickshell.UPower）★ 新
│       └── # PowerProfiles      #     电源模式——TUXEDO 笔记本走 tuxedo-control-center，
│                                #     台式机未来可用 Quickshell.UPower PowerProfiles
│
├── ui/                        # UI 层：所有窗口/面板
│   ├── bar/                   #   顶栏
│   ├── island/                #   灵动岛（Hub/Switcher/Lyrics...）
│   ├── launcher/              #   启动器（应用 + Emoji）
│   ├── lock/                  #   锁屏
│   ├── sidebar/               #   左侧栏（系统 + 天气）
│   ├── quicksettings/         #   右侧快捷设置
│   ├── clipboard/             #   剪贴板
│   ├── capture/               #   截图/录制菜单
│   └── notif/                 #   通知弹出
│
├── component/                 # 可复用 QML 组件
│   ├── svg-icon.qml
│   ├── widget-panel.qml
│   └── ...
│
├── backend/                   # 编译型数据源（Quickshell 无原生 D-Bus 绑定的）
│   ├── cava/                  #   音频频谱（将来 Rust）
│   └── sysmon/                #   系统监控（原 Clavis.Sysmon，留待研究）
│
├── script/                    # 外部脚本（UI 辅助，非数据源）
│   ├── capture.sh
│   ├── weather.py
│   └── ...
│
└── asset/                     # 静态资源
    ├── icon/                  #   图标
    ├── font/                  #   字体
    └── app-logo/              #   应用 logo
```

---

## 迁移路线

按复杂度递增：

| 优先级 | 模块 | 估计工作量 | 状态 |
|---|---|---|---|
| 1 | data/service/Time | ✅ 已完成 |
| 2 | data/service/Volume | ✅ 已完成 |
| 3 | data/service/Media | ✅ 已完成 |
| 4 | data/service/Notification | ✅ 已完成 |
| ~~5~~ | ~~data/service/Package~~ | — | **删除** |
| 6 | data/service/Network | 30 分钟 | 使用 Quickshell.Networking |
| 7 | data/service/Bluetooth | 30 分钟 | 使用 Quickshell.Bluetooth |
| 8 | data/service/Battery | 20 分钟 | ★ 新，使用 Quickshell.UPower |
| 9 | data/service/PowerProfiles | 20 分钟 | ★ 新 |
| 10 | data/state/* | 15 分钟 | 待开始 |
| 11 | component/* | 30 分钟 | 待开始 |
| 12 | backend/* | 待定 | Cava / Sysmon |
| 11 | core/ | 2 小时 | 待开始（改构建路径） |
| 12 | ui/bar | 2 小时 | 待开始 |
| 13 | ui/island | 4 小时 | 待开始 |
| 14 | ui/sidebar | 6 小时 | 待开始（最大模块） |
| 15 | ui/lock | 3 小时 | 待开始 |
| 16 | ui/launcher | 2 小时 | 待开始 |
| 17 | ui/其他 | 各 1~2 小时 | 待开始 |
| 18 | script → Rust | 按需 | 待讨论 |
