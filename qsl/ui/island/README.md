# Dynamic Island（qsl）

> 状态机 + 耳朵 morph 壳先立住，页面按 Overview → Media → Wallpaper → Weather → Switcher 逐页搬。
> 生产：默认 `qs`（`~/.config/quickshell` → qsl）；IPC target `island`。

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
- 无 `DropShadow`（岛体不加阴影）

### 三级岛（Hub）

快捷键（hypr 已绑）：

| 键 | IPC | 行为 |
|---|---|---|
| Alt+Tab | `island hub` | toggle Hub；默认 Overview，或恢复上次 Media/Wallpaper/Weather |
| Super+Tab | `island switcher` | toggle Switcher（已开则关） |

五页：`overview` / `media` / `wallpaper` / `weather` / `switcher`  
Hub 内 Tab / Shift+Tab 循环；Esc 关 Hub。

**Loader 按页**：仅当前 Tab `active`，关 Hub 卸掉内容（旧 qs 五页常驻是内存债）。

---

## Overview（信息架构）

瘦身「身份 + 时间感」，参考 Dank bento 节奏，不抄滑条 / 迷你媒体 / 控制中心。

| 块 | 内容 | 备注 |
|---|---|---|
| 用户 | QQ 头像 + hostname + Arch/uptime | 加大头像与字号 |
| 时钟 | 问候 + HH:mm（两行） | 日期交给右栏日历 |
| 天气 | 图标 + 温度 + 短文案 | `Weather` peek；点击进 Weather |
| 主视觉 | 大日历三缓冲翻页 | prev/curr/next 预加载再滚 |

**状态：已实现**（`OverviewPage` + `OverviewCalendar`）

---

## Weather

- 后端：`weatherd` → `~/.cache/qsl/forecast.json`
- 定位：点地名搜索（geocode）/ `reset_location` 回 IP
- 页：`WeatherPage`（对齐旧 Island 四区；天空穹精简今日轨迹）
- Overview：图标 + 温度轻量预览

---

## Media（瘦身）

- IPC：`mediatoggle` / `prev` / `next` → `Media.active`（已通）
- 服务：`Media`（选播放器 + isMusicPlayer）、`Cava`（cava-relay + refCount）、`Lyrics`（lyrics-fetch）
- Hub：`MediaPage` — 封面 / 进度 / 传输 / 切播放器 / 12 柱小频谱 / 歌词列表
- **不做**：圆形 cava 环、FastBlur 底、L1 展开卡
- L1：`LyricsContent` — 播放中自动抢占；悬停 → 时钟；跑马灯 + 6 柱频谱

---

## 其它页策略

| 页 | 策略 |
|---|---|
| Media | **已做**（瘦身 Hub） |
| Wallpaper | 照搬 + 轻优化；`lianwall` 封装 |
| Weather | **已做**（weatherd） |
| Switcher | **已做**（视口静帧 / 焦点 live；ListView 定位；Island 延迟 dispatch 跳转） |

---

## 状态机（真源）

`data/state/Island.qml` 单例，避免多屏各挂一套 IPC 导致 Super/Alt+Tab 水土不服。

```
showHub ─────────────────────────────────→ Hub（三级）
showLyrics / autoLyrics（且未悬停还原）──→ 歌词条
notifToast 活跃 ─────────────────────────→ 通知条
否则 ────────────────────────────────────→ 时钟（一级默认）
```

## 关岛（务必可用）

Hub 开着时是 `Exclusive` 键盘焦点，Hypr 收不到 Alt+Tab。必须靠岛内退出：

- **Esc**（窗口级 FocusScope，主屏抢键）
- **点岛外空白**
- 应急：`qs ipc call island close`

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

1. **壳**：耳朵 + morph + Hub 壳 + IPC — 已做
2. **Overview** — 已做
3. **Weather** — 已做
4. **Media** — 已做（瘦身 Hub + L1 歌词条）
5. Wallpaper
6. Switcher — 已做
7. 通知条接入一级优先级 — 已做

---

## IPC（开发）

```bash
qs ipc call island hub
qs ipc call island media
qs ipc call island switcher
qs ipc call island wallpaper
qs ipc call island mediatoggle
qs ipc call island mediaprevious
qs ipc call island medianext
```
