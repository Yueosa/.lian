# qsl

> qsl 根 = `~/.config/quickshell`。本文档内路径均相对此根。

## 计划：工具页 + 提醒 + 笔记（M0–M4）

> **状态：M0–M4 全部落地并验收（2026-09-11）**。定位与规矩见
> `plan-notes.md` →「工具页 + 提醒 + 笔记」。遗留：提醒音频（后议）、
> 锁屏是否显示提醒（未定）、Ctrl+W 删笔记（无撤销风险，暂不做）。

命名约定：**闹钟 → 提醒**，**便笺 → 笔记**。全文照此。

依赖链：M0 搭容器 → M1/M2 填卡片 → M3 笔记 → M4 接线导出。

---

### M0. time 页重构

**目标**：把 C 面板（左栏）的 time 页扩成「工具页」，页首加芯片条，仿 keys 页的 header 模式。

**现状**：`ui/leftbar/Leftbar.qml` 里 `order: ["time", "sys", "keys", "todo"]`，time 页无 header，两个容器 `timeClockCard`（TimeClockCard）+ `timeTimerCard`（TimeTimerCard）。

**改动**：
1. time 页加 `header`（芯片条卡），芯片三个：时间 / 计算器 / 提醒。
2. 默认选中「时间」，显示现有 `TimeClockCard`。
3. 芯片切换 = 换 groupId，下面容器跟着换。**落地用容器占位协议而不是 keys 页的 replayContainer**：容器列表静态放四张卡（时间/计算器/提醒），各卡按 `toolState.groupId` 自报 `hasContent`，换卡动画（下降沿立刻收、新卡派生）由 RailContainer 自带；工具页配 `shownRiseMs: 0` 去掉 280ms 数据防抖（芯片切换是人为动作，不是数据抖动）。
4. `TimeTimerCard` 已随 M2 删除（连同 `Timers` 服务——秒表/倒计时被提醒取代）。

**参考**：`ui/leftbar/KeysTabsCard.qml`（芯片条），`Leftbar.qml` 里 `keys: { header: keysTabsCard, containers: [...] }` 的接线方式。

**芯片条**：新建 `ui/leftbar/ToolTabsCard.qml`（或复用 KeysTabsCard 抽象），共享状态放 Leftbar 里（`toolState.groupId`）。

---

### M1. 计算器

**目标**：工具页「计算器」tab，一个简单计算器卡片。

**范围**：四则运算 + 括号 + 百分比。**不做**二进制/十六进制、数学函数、积分（跳浏览器）。

**改动**：新建 `ui/leftbar/CalcCard.qml`，作为 calc tab 的容器卡。纯前端，无后端。

---

### M2. 提醒

**目标**：工具页「提醒」tab。指定时间到达时提醒。

**范围**：一次性 / 每天 / 指定日期 三档。不做每周几 / 工作日。

**机制**（已定案并落地）：
1. 提醒信息存本地 JSON（`~/.local/share/qsl/reminder.json`，Todo 口径 Process 写盘）。
2. qs 启动时初始化：读 JSON，恢复未过期的提醒，起 QML Timer（1s 节流，有活动提醒才跑）。
3. 到点：服务发 `reminderFired` → Island 收进**常驻提醒队列**——一级岛新形态（440×72，`Size.island.reminderW/H`），优先级 **Hub > 提醒 > 手动歌词 > 通知 toast > 自动歌词 > 时钟**；Hub 开着时排队，关 Hub 后才占岛。**必须手动点掉**（不是 5s toast、不是 notify-send），FIFO 一次一条 + 「还有 N 条」角标；这条通路不经过 Notification，**天然 DnD 豁免**（用户自己约的时间不该被免打扰压掉）。音频后议。
4. 不常驻额外进程，不要求跨 qs 重启存活——qs 没跑就没提醒，符合预期。

**改动**：新建 `data/service/Reminder.qml`（服务单例，仿 Timers.qml）+ `ui/leftbar/ReminderCard.qml`（UI）。

**M2 完成后**：删 `TimeTimerCard.qml` 及其在 `Leftbar.qml` 里的 `timeTimerCard` 装配（原来计时/秒表被提醒取代）。

---

### M3. 笔记

**目标**：常驻左 rail 内侧的笔记面板，多篇 + 增删，纯文本。

**范围**：多篇、新增、删除、tab 切换、常驻显示、Super+J 抢占/归还焦点、Esc 退出打字态、hover 聚焦、高度有上限 + 滚动。**不做**图片、lightbox、混排。

**已定的形态决策**：
- 宽度同 C 面板（`Size.panel.cWidth`）。
- 高度有上限，超了滚动（不是无限长）。
- 常驻语义（用户修订）：**默认收起**（启动不展开），Super+J 才唤出；**Super+J = 唤出 + 切换焦点（打字 ↔ 静息），Esc = 关闭页面**（退出打字 + 收起回 rail），点框外同 Esc。C/Z 开窗临时让位。
- 焦点：hover 聚焦（`forceActiveFocus`，同现有 `focusTick` 思路）。
- 面板内快捷键（仅打字态生效，方案 2026-09-11 定）：`Tab`/`Shift+Tab` 标题↔正文；`Ctrl+Tab`/`Ctrl+Shift+Tab` 下/上一篇；`Ctrl+N` 新建（焦点落正文）。`Ctrl+W` 删当前**未实现**——无撤销、误触丢数据。
- 涟漪：**只在焦点态（打字/抢占）放**——进入 claim(edge "left", anchor=卡片中线) 自带进波 + 周期波，退出 release 自带临别波；静息零涟漪成本（水波约 8% CPU，常驻放波会让渲染循环常年不睡，与「空闲真的静止」硬规矩冲突）。`RailRipple.originFor` 为此补了竖边 anchor 支持。

**架构硬约束**：笔记**必须并进框窗**（FrameWindow），不能独立 surface。理由见 `ui/frame/RailRipple.qml` 顶部注释——涟漪要画在 rail 所在的那棵场景图里，跨窗画不了一个像素。所以笔记和 rail 必须同一 surface。

**改动**：
1. 新建 `data/service/Note.qml`（笔记列表 + 内容持久化，本地 JSON；**500ms 无输入防抖自动保存** + 切笔记/退打字 flush）。
2. 新建 `ui/note/`（面板壳 + 编辑卡），在 `ui/frame/FramePanels.qml` 里装配（声明在 Leftbar 之前 = C 开窗盖在笔记上）。
3. 让位：**只读 `Panels.activeIn("left")`**——C/Z 开着就滑回 rail（复用 RailContainer 的 present），不 claim 组（claim 的语义是「被挤掉就关窗」，对常驻面板是错的，且常驻 claim 会把键盘栈永远顶住）。
4. 涟漪：打字态 claim(edge "left", anchor=卡片中线) 占波源槽位，退出 release。
5. 空态不可达（用户定）：服务加载时一篇不剩就立一篇空白，删光立刻补一篇；焦点默认落**正文**（标题是元信息）；标题行有背景，观感同正文输入区。

**注意**：笔记常驻 = 它不像其他面板 `open` 才显示，`wantsOverlay`/`wantsKeyboard` 的语义要和「常驻 + 仅打字态抢键盘」对齐，不能照抄 Leftbar 的 `open` 绑定。

---

### M4. 导出 IPC + 快捷键

**目标**：把笔记接入外部调用。

**改动**：
1. 导出笔记的 qs IPC：在 `ui/frame/FramePanels.qml` 的 IpcHandler 区加 `note` target（toggle / focus / 增删等），对应 Super+J 的抢占/归还焦点语义。
2. 更新 `asset/hotkeys.json`：加 Super+J 条目。**遵守该文件 `_note` 的排版约束**（desc ≤10 汉字、键名统一箭头、同义键合并等）。
3. 更新 Hyprland 快捷键：`~/.lian/hypr/lua/binds.lua` 加 `Super+J`，绑定到笔记 IPC。
