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

示例：

```bash
qs -p ~/.lian/qsl ipc call notif toggle
qs -p ~/.lian/qsl ipc call rightbar open network
qs -p ~/.lian/qsl ipc call free-window-app toggle
```

---

## 已完成

- [x] FreeWindow App（Super+A）
- [x] FreeWindow Clipboard（Super+Z）
- [x] 截图脚本（Ctrl+Alt+A/Q）
- [x] 通知中心 NotifCenter（Super+N / IPC `notif`）
- [x] Bar 左：工作区（缺口甜甜圈）+ 窗口名

---

## 接下来：Rightbar（Super+V）+ Bar 右

原则：

- **先做右侧栏页面，再挂 Bar 芯片**（芯片只是入口 + 摘要）
- 无 gooey；关窗停扫描 / `release` 清展示数据
- IPC：`rightbar`（对齐生产 `qs ipc call rightbar …`）
- **不做** light/dark 主题切换；配色只吃 matugen，挂了用硬编码兜底
- **不做** Rightbar 电源页（Tuxedo + 左栏 system 已够）

### Rightbar 壳

- [x] `ui/rightbar/` 面板壳（右滑、Esc、IPC toggle/open/close/next/prev）
- [x] `view` 状态：`network` / `bluetooth` / `audio` / `updates`
- [x] 单 Loader + 旧页淡出/新页滑入；关窗销毁页面
- [x] 挂到 `shell.qml`；hypr 仍用 `qs("rightbar", …)`，不改 `-p`

### 页面（一个一个打磨）

- [x] **Network** — 接 `data/service/Network`（开关 / 扫描 / 列表 / 密码展开 / nmtui）
- [x] **Bluetooth** — 接 `data/service/Bluetooth`（开关 / 扫描 / 已连接·已配对·附近 / 忘记 / blueman）
- [x] **Audio** — 接 `data/service/Volume`（总输出/麦克风/应用混音；设备路由 → pavucontrol）
- [x] **Updates** — `updatesctl` + 缓存 JSON；开页/手动刷新拉取；列表 repo/AUR；齿轮 `tcr`→Syu

### Bar 右侧（Rightbar 页面可用后再做）

- [ ] Tray（SystemTray）
- [ ] WiFi / BT / Volume / Updates 芯片 → 打开对应 `qsView`
- [ ] ~~主题按钮~~（已砍）

---

## 更后面（先别做）

- [ ] Dynamic Island
- [ ] 左侧栏（含 system / 电源详情）
- [ ] Lock / HotCorner / 录制菜单等

---

## 刻意不做 / 已砍

| 项 | 原因 |
|---|---|
| light/dark 主题切换与状态机 | 几乎不用、切换卡、占逻辑；matugen 挂了用硬编码兜底即可 |
| Rightbar 电源页 | Tuxedo 管策略；左栏 system 可看电量 |
| Updates 后台定时轮询 | 旧实现太重；改为打开/手动刷新 |
| Rightbar gooey blur | 只留给 Island |

---

## 数据层备忘

| 能力 | 状态 |
|---|---|
| Network / Bluetooth / Volume / Battery / Media / Time / Calendar / Notification | service 已有 |
| Color | 只跟 matugen JSON；无 mode 切换 |
| Updates | `updatesctl` + `data/service/Updates`；按需拉取 |
| Battery | 有 service，但不进 Rightbar |
