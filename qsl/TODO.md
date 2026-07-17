# qsl 待办清单

> 给记性差的自己：按模块慢慢打磨，做完一项勾一项。
> 生产：`~/.config/quickshell` → `~/.lian/qsl`，直接 `qs` 即可。
> 切链（若尚未）：`bash ~/.lian/qsl/scripts/switch-default-config.sh`（需写 `~/.config`；链属 root 时加 sudo）
> 对照旧壳：`qs -p ~/.lian/quickshell`。

---

## IPC 速查

前缀：`qs ipc call <target> <fn> [args…]`

| target | 命令 | 说明 |
|---|---|---|
| `free-window-app` | `toggle` / `open` / `close` | 启动器 Super+A |
| `free-window-clipboard` | `toggle` / `open` / `close` | 剪贴板 Super+Z |
| `notif` | `toggle` / `open` / `close` / `dnd` | 通知中心 Super+N；`dnd` 切换免打扰 |
| `rightbar` | `toggle` | 右侧栏开关 Super+V |
| `rightbar` | `open <view>` | `network` / `bluetooth` / `audio` / `updates` |
| `rightbar` | `next` / `prev` | Tab 切换 |
| `rightbar` | `close` | 关栏 |
| `sidebar` | `toggle` | 左侧栏开关 Super+C |
| `sidebar` | `open <view>` | `time` / `sys` / `keys` |
| `sidebar` | `next` / `prev` | Tab 切换 |
| `sidebar` | `close` | 关栏 |
| `island` | `hub` | Alt+Tab：toggle Hub |
| `island` | `switcher` | Super+Tab：打开 Switcher |
| `island` | `wallpaper` | 打开 Wallpaper 页 |
| `island` | `media` | 打开 Media 页 |
| `island` | `mediatoggle` / `mediaprevious` / `medianext` | 媒体控制 |
| `island` | `close` | 关 Hub |

示例：

```bash
qs ipc call notif toggle
qs ipc call rightbar open network
qs ipc call sidebar open sys
qs ipc call island hub
qs ipc call free-window-app toggle
```

---

## 已完成

- [x] FreeWindow App（Super+A）
- [x] FreeWindow Clipboard（Super+Z）
- [x] 截图脚本（Ctrl+Alt+A/Q）
- [x] 通知中心 NotifCenter（Super+N / IPC `notif`）
- [x] Bar 左：工作区（缺口甜甜圈）+ 窗口名
- [x] Rightbar（Super+V）四页 + Bar 右 Tray/芯片
- [x] Leftbar 壳 + Time / System / Keys（Super+C）
- [x] Island **壳**（耳朵 + morph + Hub 占位 + IPC）

---

## 接下来：Dynamic Island

详见 [`ui/island/README.md`](ui/island/README.md)。

### 壳（已做）

- [x] `data/state/Island` 单例状态机（多屏共享 IPC）
- [x] 耳朵 + DropShadow + 尺寸 morph；无 L2 / 无一级点击
- [x] Hub 五 Tab + 单 Loader 占位页；Tab 与 `Island` 双向同步
- [x] 耳朵抽成 `EarCanvas`；一级时钟按需 Loader
- [x] IPC：`hub` / `switcher` / `wallpaper` / media* / `close`

### 页面（一个一个打磨）

- [x] **Overview** — 身份/时钟/天气入口 + 三格轮转日历
- [x] **Media** — 瘦身 Hub 页 + Media/Cava/Lyrics 服务（IPC 已通）
- [x] **Wallpaper** — next/prev/mode + 网格（LianWall thumb）+ 齿轮开 gui
- [x] **Weather** — weatherd + Island 页；Overview 图标/温度预览
- [x] **Switcher** — 视口静帧 + 焦点 live；ListView 定位；hyprctl eval + hl.dsp 跳转
- [x] 一级：歌词条（播放中封面+歌词+cava；悬停还原时钟）
- [x] 一级：通知 toast（≤3 堆叠 / 进度条 / DnD / Hub·手动歌词 > toast > 自动歌词）

---

## 更后面（先别做）

- [ ] Lock / HotCorner / 录制菜单等

---

## 刻意不做 / 已砍

| 项 | 原因 |
|---|---|
| light/dark 主题切换与状态机 | 几乎不用、切换卡、占逻辑；matugen 挂了用硬编码兜底即可 |
| Rightbar 电源页 | Tuxedo 管策略；左栏 system 可看电量 |
| Updates 后台定时轮询 | 旧实现太重；改为打开/手动刷新 |
| Rightbar / Leftbar gooey blur | 岛也不做真 gooey；岛灵魂是耳朵 + morph + 阴影 |
| **LianClaw 整棵**（会话/消息/RPC） | 左栏只要时间/一言展示；AI 会话另议 |
| System 曲线 / 双弧 / 进程展开 | 重且收益低；htop 齿轮兜底 |
| Leftbar Weather | 太重；留给 Island |
| Island L2 媒体卡 / 一级点击 / 音量 OSD | 状态机瘦身；媒体只走 Hub + IPC |

---

## 数据层备忘

| 能力 | 状态 |
|---|---|
| Network / Bluetooth / Volume / Battery / Media / Time / Calendar / Notification | service 已有 |
| Color | 只跟 matugen JSON；换色有渐变 |
| Updates | `updatesctl` + `data/service/Updates`；按需拉取 |
| Sysmon | `sysmond` + `data/service/Sysmon`；开 System 页自启 daemon |
| Weather | `weatherd` + `data/service/Weather`；Island 页 + Overview peek |
| Media / Cava / Lyrics | MPRIS + cava-relay + lyrics-fetch；Hub MediaPage；L1 歌词 UI 待做 |
| Hotkeys | `asset/hotkeys.json` + `Hotkeys.qml` |
| Island | `data/state/Island` 状态机；壳在 `ui/island/` |
