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
| `sidebar` | `open <view>` | `time` / `sys` / `weather` |
| `sidebar` | `next` / `prev` | Tab 切换 |
| `sidebar` | `close` | 关栏 |

示例：

```bash
qs -p ~/.lian/qsl ipc call notif toggle
qs -p ~/.lian/qsl ipc call rightbar open network
qs -p ~/.lian/qsl ipc call sidebar open time
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
- [x] `view`：`time` / `sys` / `weather`
- [x] 单 Loader + 页切换淡出/滑入；关窗销毁
- [x] 挂到 `shell.qml`；hypr 仍用 `qs("sidebar", …)`，不改 `-p`

### 页面（一个一个打磨）

- [x] **Time** — 环形时钟 / 日期问候 / 一言（点卡片刷新）；无会话 UI
- [ ] **System** — 占位 → 再拆（见下调查）
- [ ] **Weather** — 占位 → 再拆（见下调查）

### 调查备忘（先别深挖实现）

| 页 | 旧实现体量 | 数据 | 首版策略 |
|---|---|---|---|
| Time | `LcWelcomeView` ~258 行 | `Time` service + hitokoto XHR | 已搬；全高栏；分钟节流 + 关页 abort |
| System | `SystemView` ~1400 行 + Canvas | `SysmonPlugin` | 太重；先占位，再按块迁（表盘→图→进程） |
| Weather | `WeatherView` ~940 + 背景 ~1240 + 一堆卡片 | `WeatherPlugin` + geocode | 最重；先占位，再定「只要当前+日预报」还是全量 |

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

---

## 数据层备忘

| 能力 | 状态 |
|---|---|
| Network / Bluetooth / Volume / Battery / Media / Time / Calendar / Notification | service 已有 |
| Color | 只跟 matugen JSON；换色有渐变 |
| Updates | `updatesctl` + `data/service/Updates`；按需拉取 |
| Battery | 有 service，但不进 Rightbar |
| Sysmon / Weather | 旧在 Clavis 插件；qsl 未迁，System/Weather 页再说 |
