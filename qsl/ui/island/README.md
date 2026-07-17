# Dynamic Island（qsl）

> 状态机 + 耳朵 morph 壳先立住，页面按 Overview → Media → Wallpaper → Weather → Switcher 逐页搬。
> 开发：`qs -p ~/.lian/qsl`；IPC 与生产同名 `island`。

---

## 目标形态

### 一级岛（常驻顶栏中）

展示优先级（高 → 低）：

**通知条 > 歌词 > 时间**

- 歌词态时：**鼠标悬停优先显示时间**（`lyricsHoverRestore`）
- **不设左键 / 右键**：一级不再展开二级媒体卡
- **砍掉**：旧 L2 轻量播放器、音量 OSD 抢占一级

视觉灵魂（非 gooey blur）：

- 顶栏贴边 **左右耳朵**（Canvas 四分之一圆凹角）
- 实色底（`Color.background`）+ 尺寸 / 圆角 morph
- `DropShadow`（`cached: false`，避免形变阴影泄漏）

### 三级岛（Hub）

快捷键（hypr 已绑）：

| 键 | IPC | 行为 |
|---|---|---|
| Alt+Tab | `island hub` | toggle Hub；默认 Overview，或恢复上次 Media/Wallpaper/Weather |
| Super+Tab | `island switcher` | 强制打开 Switcher（不 toggle 关） |

五页：`overview` / `media` / `wallpaper` / `weather` / `switcher`  
Hub 内 Tab / Shift+Tab 循环；Esc 关 Hub。

**Loader 按页**：仅当前 Tab `active`，关 Hub 卸掉内容（旧 qs 五页常驻是内存债）。

---

## Overview（信息架构）

瘦身「身份 + 时间感」，参考 Dank bento 节奏，不抄滑条 / 迷你媒体 / 控制中心。

| 块 | 内容 | 备注 |
|---|---|---|
| 用户 | QQ 头像 + hostname | 头像：`https://q1.qlogo.cn/g?b=qq&nk=1303028790&s=640`（可配置） |
| 标识 | Arch logo | 资源放 `asset/` |
| 时长 | uptime | 低频刷新 |
| 主视觉 | 大日历 | 复用 `Calendar` service |
| 摘要 | 系统摘要若干行 | 与 hostname/uptime 同级补白；**字段名单后定**（可来自 Sysmon / fastfetch 缓存） |

明确不做：WiFi/BT 开关、电源策略、麦克风滑条、控制中心、三模式、事件偏好页。

---

## 其它页策略

| 页 | 策略 |
|---|---|
| Media | 逻辑照搬；媒体 IPC（toggle/prev/next）走统一 `Media` 服务 |
| Wallpaper | 照搬 + 轻优化；`lianwall` 封装 |
| Weather | 照搬 |
| Switcher | 照搬 + 修滚动/焦点；控制 Screencopy live 范围 |

---

## 状态机（真源）

`data/state/Island.qml` 单例，避免多屏各挂一套 IPC 导致 Super/Alt+Tab 水土不服。

```
showHub ─────────────────────────────────→ Hub（三级）
showLyrics / autoLyrics（且未悬停还原）──→ 歌词条
notifToast 活跃 ─────────────────────────→ 通知条
否则 ────────────────────────────────────→ 时钟（一级默认）
```

Hub 打开时压制一级展示内容（岛体放大到 Hub 尺寸）。

---

## 风格

- Island / Hub：**实色表面**（对齐旧 qs），弱边框或不描边
- 与 Left/Right/Notif 的白透明暂不强制统一；岛稳定后再考虑收口
- 尺寸令牌：`Size.island.*`

---

## 性能预算

- 无 gooey GaussianBlur（耳朵 + 阴影足够）
- Hub 单 Loader；关岛 `active=false`
- Switcher 默认不全窗 live screencopy
- 头像 Image：`asynchronous` + 固定源，避免反复解码
- 系统摘要：开 Overview 时刷新 / 低频，勿常驻 Process

---

## 落地顺序

1. **壳**（本阶段）：耳朵 + morph + 一级时钟占位 + Hub 壳 + IPC
2. Overview 瘦身页
3. Media（+ 媒体 IPC）
4. Wallpaper / Weather
5. Switcher 修 bug
6. 通知条 / 歌词条接入一级优先级

---

## IPC（开发）

```bash
qs -p ~/.lian/qsl ipc call island hub
qs -p ~/.lian/qsl ipc call island switcher
qs -p ~/.lian/qsl ipc call island wallpaper
qs -p ~/.lian/qsl ipc call island mediatoggle
qs -p ~/.lian/qsl ipc call island mediaprevious
qs -p ~/.lian/qsl ipc call island medianext
```
