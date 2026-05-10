# quickshell_lian

> Sakurine 个人 Quickshell 桌面 Shell 配置。运行于 Hyprland + Wayland。

本仓库已经成为 Quickshell 在我的系统上的**单一交互层真源**：Bar、灵动岛、左/右侧栏、Launcher、剪贴板、锁屏、通知、系统更新等全部由这套 QML 实现，配合 `core/` 下自建的 Qt/C++ 插件提供系统监控与天气数据。Waybar / swaync / rofi（含 cliphist 入口）已经全部被替换，可在 Phase F 安装阶段统一卸载或停用。

---

## 接入方式

> 本目录设计为 `~/.lian/quickshell/` 的真源仓库；通过软链接被 Quickshell 加载。

```bash
# 1. 将仓库定位到真源
mv quickshell_lian ~/.lian/quickshell

# 2. Quickshell 配置入口指向真源
ln -snf ~/.lian/quickshell ~/.config/quickshell

# 3. 脚本通过 install.sh 软链到 ~/.local/bin/qs_*（详见 MIGRATION.md）
bash ~/.lian/quickshell/install.sh    # Phase F 完成后提供

# 4. 启动
qs
```

Hyprland 自启可在 `~/.lian/hypr/hyprland.conf` 中加：
```ini
exec-once = qs
```

---

## 系统依赖

**必需**：
- `quickshell`（Qt 6，Wayland 环境）
- `hyprland`
- `nmcli`（网络）、`bluetoothctl`（蓝牙）、`playerctl`（媒体）、`cliphist` + `wl-clipboard`（剪贴板）
- `sqlite`（剪贴板/通知/媒体/课表/更新等数据层后端单一存储于 `~/.local/state/lian/lian.db`）
- `pacman` + `checkupdates` + `paru`（系统更新检查）
- `python3`（脚本依赖）、`bash`、`jq`、`grim`、`slurp`
- 字体：`Material Symbols Outlined`、`JetBrainsMono Nerd Font`、`Font Awesome 6 Free Solid`
- 图标：`papirus-icon-theme` 通过 `~/.config/qt6ct/qt6ct.conf` 中 `icon_theme=Papirus-Dark` 暴露给 Quickshell

**可选**：
- `blueman`（蓝牙面板齿轮调起 `blueman-manager`）
- `kitty`（网络面板齿轮调起 `kitty -e nmtui`）
- `matugen`（壁纸→主题色派生，Colorscheme.qml 调用）

---

## 快捷键约定

| 按键 | 行为 |
|---|---|
| `Super+A` | 启动器开关 |
| `Super+Z` | 剪贴板开关 |
| `Super+Tab` | 灵动岛 Switcher |
| `Alt+Tab` | 灵动岛 Hub（默认 Overview） |
| `Alt+Space` | 通知面板开关 |
| `Super+Space` | wlogout 电源菜单 |
| `Ctrl+Alt+A` | 区域截图（grim+slurp，外部链路） |
| `Ctrl+Alt+Q` | 全屏截图（grim，外部链路） |

---

## 仓库布局

```
shell.qml                 # 入口
config/                   # 单例配置（Colorscheme/Sizes/WidgetState/Typography 等）
Services/                 # 单例服务（Network/Bluetooth/Updates/MediaManager 等）
Modules/
  Bar/                    # 顶栏
  DynamicIsland/          # 灵动岛 + Hub 4 Tab + Switcher + Lyrics + Volume
  Clipboard/              # 独立剪贴板窗口
  Launcher/               # 应用启动器
  Lock/                   # 锁屏
  HotCorner/              # 通知热角
Widget/                   # 右侧 QuickSettings 面板 + 左侧 Sidebar + 通知组件
  left_sidebar/           # 系统视图 + 天气视图（含完整气象图表）
scripts/                  # 所有外部脚本（Phase F 软链到 ~/.local/bin/qs_*）
core/                     # Qt/C++ 插件源（sysmon、weather）
assets/                   # 图标、应用 logo、meteocons、字体回退资源
```

---

## 文档

- `MIGRATION.md` — 从旧栈（Waybar / swaync / rofi）迁移到本仓库的完整步骤、软链映射、清理清单。
- `EXTERNAL_CHANGES.md` — 仓库外的系统级改动登记（图标主题、qt6ct、Hyprland bind 等）。

---

## 致谢

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) — 提供成熟的 Quickshell 模板。
- [caelestia-dots/shell](https://github.com/caelestia-dots/shell) — 锁屏样式参考。
