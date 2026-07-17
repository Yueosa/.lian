# qsl 待办清单

> 给记性差的自己：按模块慢慢打磨，做完一项勾一项。
> 开发用 `qs -p ~/.lian/qsl`；生产仍是默认 `qs`，IPC 名对齐即可。

---

## IPC 速查（开发）

前缀一律：`qs -p ~/.lian/qsl ipc call <target> <fn> [args…]`  
（生产去掉 `-p ~/.lian/qsl`，target/fn 相同。）

| target | 命令 | 说明 |
|---|---|---|
| `free-window-app` | `toggle` / `open` / `close` | 启动器 Super+A |
| `free-window-clipboard` | `toggle` / `open` / `close` | 剪贴板 Super+Z |
| `notif` | `toggle` / `open` / `close` | 通知中心 Super+N |
| `rightbar` | `toggle` | 右侧栏开关 Super+V |
| `rightbar` | `open <view>` | `network` / `bluetooth` / `audio` / `updates` |
| `rightbar` | `next` / `prev` | Tab 切换 |
| `rightbar` | `close` | 关栏 |
| `sidebar` | `toggle` | 左侧栏开关 Super+C |
| `sidebar` | `open <view>` | `time` / `sys` / `keys` |
| `sidebar` | `next` / `prev` | Tab 切换 |
| `sidebar` | `close` | 关栏 |

示例：

```bash
qs -p ~/.lian/qsl ipc call notif toggle
qs -p ~/.lian/qsl ipc call rightbar open network
qs -p ~/.lian/qsl ipc call sidebar open sys
qs -p ~/.lian/qsl ipc call free-window-app toggle
```

---

## 已完成

- [x] FreeWindow App（Super+A）
- [x] FreeWindow Clipboard（Super+Z）
- [x] 截图脚本（Ctrl+Alt+A/Q）
- [x] 通知中心 NotifCenter（Super+N / IPC `notif`）
- [x] Bar 左：工作区（缺口甜甜圈）+ 窗口名
- [x] Rightbar（Super+V）四页 + Bar 右 Tray/芯片
- [x] Leftbar 壳 + Time 页（Super+C）

---

## 接下来：Leftbar（Super+C）

原则：

- **先写壳，再一页一页打磨**（与 Rightbar 同套路）
- 无 gooey；关窗 `Loader.active=false` 销毁页面
- IPC：`sidebar`（对齐生产 `qs ipc call sidebar …` / hypr Super+C）
- **整棵 LianClaw 砍掉**（会话列表 / 消息 / RPC / SessionDrawer）
- 原 LianClaw 欢迎页只留：**时间环 + 日期问候 + 一言**

### Leftbar 壳

- [x] `ui/leftbar/` 面板壳（左滑、Esc、IPC toggle/open/close/next/prev）
- [x] `view`：`time` / `sys` / `keys`（Weather 已砍）
- [x] 单 Loader + 页切换淡出/滑入；关窗销毁
- [x] 挂到 `shell.qml`；hypr 仍用 `qs("sidebar", …)`，不改 `-p`

### 页面（一个一个打磨）

- [x] **Time** — 环形时钟 / 日期问候 / 一言（点卡片刷新）；无会话 UI
- [x] **System** — 条形仪表盘 + 轻量进程表（CPU/MEM 排序、杀进程、齿轮 htop）；`sysmond` 开页自启
- [x] **Keys** — `asset/hotkeys.json` 速查；分组芯片 + 列表（hypr 条目待填）
- [ ] ~~Weather~~ → 留给 Island，Leftbar 不做

### System 首版范围（已砍）

- 无双弧 Canvas、无 Net/RAM/Load 曲线
- 无进程展开 / smaps / 复制全家桶
- 进程列仅 CPU + MEM（无进程级 NET）
- 电池用 UPower `Battery`；监控用 `sysmond` → `Sysmon.qml`

### 调查备忘

| 页 | 策略 |
|---|---|
| Time / System | 已做 |
| Keys | 页已做；JSON 条目按表填写 |
| Weather | **不做**（Island） |

---

## 更后面（先别做）

- [ ] Dynamic Island
- [ ] Lock / HotCorner / 录制菜单等

---

## 刻意不做 / 已砍

| 项 | 原因 |
|---|---|
| light/dark 主题切换与状态机 | 几乎不用、切换卡、占逻辑；matugen 挂了用硬编码兜底即可 |
| Rightbar 电源页 | Tuxedo 管策略；左栏 system 可看电量 |
| Updates 后台定时轮询 | 旧实现太重；改为打开/手动刷新 |
| Rightbar / Leftbar gooey blur | 只留给 Island |
| **LianClaw 整棵**（会话/消息/RPC） | 左栏只要时间/一言展示；AI 会话另议 |
| System 曲线 / 双弧 / 进程展开 | 重且收益低；htop 齿轮兜底 |
| Leftbar Weather | 太重；留给 Island |

---

## 数据层备忘

| 能力 | 状态 |
|---|---|
| Network / Bluetooth / Volume / Battery / Media / Time / Calendar / Notification | service 已有 |
| Color | 只跟 matugen JSON；换色有渐变 |
| Updates | `updatesctl` + `data/service/Updates`；按需拉取 |
| Sysmon | `sysmond` + `data/service/Sysmon`；开 System 页自启 daemon |
| Hotkeys | `asset/hotkeys.json` + `Hotkeys.qml` |
| Weather | Leftbar 不做；Island 再说 |
