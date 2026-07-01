# Hyprland Lua API 参考（v0.55.4）

> 本文档记录 Hyprland 暴露给 Lua 配置的完整 API 树。
> 每个节点对应 `oneapi/` 或 `dsp/` 下的详细研究文档。
> 子命名空间（window/workspace/group/cursor）各自为目录，每个方法一个 .md 文件。

---

## 外部资源

| 资源 | 地址 |
|---|---|
| 官网 | https://hyprland.org |
| GitHub | https://github.com/hyprwm/Hyprland |
| 官方 Wiki | https://wiki.hyprland.org |
| DeepWiki 源码分析 | https://deepwiki.com/hyprwm/Hyprland |
| 本文档基于的版本 | v0.55.4（2026-06-25 升级） |

### Wiki 关键页面

| 页面 | 地址 |
|---|---|
| Lua API 总览 | https://wiki.hyprland.org/Configuring/Lua-API/ |
| 按键绑定 (Binds) | https://wiki.hyprland.org/Configuring/Basics/Binds/ |
| Dispatchers | https://wiki.hyprland.org/Configuring/Basics/Dispatchers/ |
| 配置变量 (Variables) | https://wiki.hyprland.org/Configuring/Basics/Variables/ |
| 窗口规则 (Window Rules) | https://wiki.hyprland.org/Configuring/Window-Rules/ |
| 更新日志 (Changelog) | https://wiki.hyprland.org/Getting-Started/Changelog/ |
| 迁移指南 | https://wiki.hyprland.org/Getting-Started/Migration/ |

---

## 全局对象：`hl`

```
hl
├── .bind()           — 绑定按键/鼠标事件        → oneapi/bind.md
├── .unbind()         — 解除绑定                   → oneapi/unbind.md
├── .exec_cmd()       — 立即执行 shell 命令        → oneapi/exec_cmd.md
├── .dispatch()       — 立即执行 dispatcher 动作   → oneapi/dispatch.md
├── .config()         — 读写配置变量               → oneapi/config.md
├── .get_config()     — 读取单个配置值             → oneapi/get_config.md
├── .reload()         — 重载配置                   → oneapi/reload.md
├── .on()             — 事件监听                   → oneapi/on.md
├── .timer()          — 定时器                     → oneapi/timer.md
├── .get_windows()    — 获取所有窗口对象           → oneapi/get_windows.md
├── .get_workspaces() — 获取所有工作区对象         → oneapi/get_workspaces.md
├── .get_monitors()   — 获取所有显示器对象         → oneapi/get_monitors.md
├── .define_submap()  — 定义按键子映射             → oneapi/define_submap.md
├── .notice()         — 发送通知                   → oneapi/notice.md
│
├── .dsp              — dispatcher 集合（返回动作票，不立刻执行）
│   ├── .exec_cmd()          → dsp/exec.md
│   ├── .exec_raw()          → dsp/exec.md
│   ├── .focus()             → dsp/focus.md
│   ├── .exit()              → dsp/exit.md
│   ├── .submap()            → dsp/submap.md
│   ├── .pass()              → dsp/pass.md
│   ├── .send_shortcut()     → dsp/send_shortcut.md
│   ├── .send_key_state()    → dsp/send_shortcut.md
│   ├── .layout()            → dsp/layout.md
│   ├── .dpms()              → dsp/dpms.md
│   ├── .event()             → dsp/event.md
│   ├── .global()            → dsp/global.md
│   ├── .force_idle()        → dsp/force_idle.md
│   ├── .no_op()             → dsp/no_op.md
│   ├── .window              → dsp/window/index.md
│   ├── .workspace           → dsp/workspace/index.md
│   ├── .group               → dsp/group/index.md
│   └── .cursor              → dsp/cursor/index.md
│
└── .monitor           — 显示器输出配置             → oneapi/monitor.md
```

---

## 对象类型

| 类型 | 属性 | 详细文档 |
|---|---|---|
| HL.Window | `.address`, `.title`, `.class`, `.workspace`, `.monitor`, `.floating`, `.pid` | docs/oneapi/get_windows.md |
| HL.Workspace | `.id`, `.name`, `.monitor`, `.windows`, `.is_special` | docs/oneapi/get_workspaces.md |
| HL.Monitor | `.id`, `.name`, `.width`, `.height`, `.refresh_rate`, `.active_workspace` | docs/oneapi/get_monitors.md |

---

## 常用模式

```lua
-- 封装简化（建议在 binds.lua 中使用）
local function sh(cmd)    return hl.dsp.exec_cmd(cmd) end
local function bind(k, d)  return hl.bind(k, d) end
local function qs(mod, act) return sh("qs ipc call " .. mod .. " " .. act) end
```

---

## 文档约定

- 每个 `docs/oneapi/*.md` 研究一个 `hl.*` 一级方法
- 每个 `docs/dsp/*.md` 研究一个 `hl.dsp.*` 命名空间及其子方法
- 每篇文档应包含：方法签名、参数说明、返回值、使用示例、与相关方法的对比
