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
| 用户 | QQ 头像 + hostname + 问候 + 平台标签 + uptime/电量 | 与时钟并排；标签是一行小字不是药丸；电量无电池则隐；重启钮在卡右上角 |
| 时钟 | HH:mm + 日期星期 | 不显示秒（秒针 = 每秒一次重排） |
| 天气 | 图标 + 温度 + 现象 + 体感/湿度/紫外线 | 通宽横条；**不显示地名**（放不下且天气页有全的）；点击进 Weather |
| 待办 | 未完成全部，只读可滚 | 不截断、不交互 |
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
- Hub：`MediaPage` — 左封面 232 见方 + 操控；右歌词通高，cava 通宽一条压在歌词底下；
  播放器选择器在整页右上角（低频操作不占正文位）
- 进度条：波形由 cava 驱动——整体均值 → 振幅/频率/副波混乱度，低频 5 根 → 播放头那一鼓；
  相位用 `FrameAnimation` 按帧积分（速度要跟能量变，改正在跑的 `NumberAnimation`
  的 duration 会让波形当帧裂一道口）
- 歌词：折行按焦点字号（26px）排死，焦点只动 scale/颜色/透明度，不改 `pixelSize`
- **不做**：圆形 cava 环、FastBlur 底、L1 展开卡
- L1：`LyricsContent` — 播放中自动抢占；悬停 → 时钟；跑马灯 + 6 柱频谱

---

## 其它页策略

| 页 | 策略 |
|---|---|
| Media | **已做**（瘦身 Hub） |
| Wallpaper | **已做**（卷轴一屏 5 张 + 两侧渐隐位；焦点卡压邻居；本页自管顺序；模式/上下张/信息；不开 gui） |
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
5. **Wallpaper** — 已做
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
