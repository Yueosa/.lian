-- 快捷键配置
--     这个文件专注于配置 hyprland 级别的快捷键
--     与 qsl/asset/hotkeys.json 保持同步（速查页）


-- 主修饰键
--     此按键应该仅用于 hyprland 的快捷键分发
--     qs, kitty 等任何窗口管理器以下级别不应该关联到它
local mainMod = "SUPER"


-- ============================================================
-- 命令封装
-- ============================================================

-- 执行任意 shell 命令（通过 hyprland dispatch，延迟到按键时执行）
local function sh(command)
    return hl.dsp.exec_cmd(command)
end

-- 调用 qsl IPC 接口（qs ipc call；默认配置已指 ~/.lian/qsl）
local function qs(mod, action)
    return hl.dsp.exec_cmd("qs ipc call " .. mod .. " " .. action)
end


-- ============================================================
-- 默认应用 / 脚本路径
-- ============================================================

local terminal = "kitty"
local fileManager = "thunar"
local browser = "google-chrome-stable"

local scriptDir = "/home/Sakurine/.local/bin"
local sysmenu = scriptDir .. "/wlogout/wlogout"
local workspaceTool = scriptDir .. "/qshell/workspaces"


-- ============================================================
-- 布局管理
-- ============================================================

hl.bind(mainMod .. " + S", function()
    local currentLayout = hl.get_config("general.layout")
    local nextLayout = currentLayout == "dwindle" and "scrolling" or "dwindle"
    hl.config({ general = { layout = nextLayout } })
    if nextLayout == "scrolling" then
        hl.exec_cmd("notify-send '<>  切换到 scrolling 布局'")
    else
        hl.exec_cmd("notify-send '[-]  切换到 dwindle 布局'")
    end
end)


-- ============================================================
-- 窗口管理
-- ============================================================

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + M", sh("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))


-- ============================================================
-- 电源管理
-- ============================================================

hl.bind(mainMod .. " + SPACE", sh(sysmenu))
hl.bind(mainMod .. " + L", qs("lock", "lock"))  -- 锁屏（qsl SessionLock）


-- ============================================================
-- 应用启动
-- ============================================================

hl.bind(mainMod .. " + T", sh(terminal))
hl.bind(mainMod .. " + E", sh(fileManager))
hl.bind(mainMod .. " + B", sh(browser))


-- ============================================================
-- 快捷面板
-- ============================================================

hl.bind(mainMod .. " + A", qs("free-window-app", "toggle"))
hl.bind(mainMod .. " + Z", qs("free-window-clipboard", "toggle"))
hl.bind(mainMod .. " + X", qs("websearch", "toggle"))  -- Web 搜索


-- ============================================================
-- 侧栏与通知 / 灵动岛
-- ============================================================

hl.bind("ALT + TAB", qs("island", "hub"))
hl.bind(mainMod .. " + TAB", qs("island", "switcher"))
hl.bind(mainMod .. " + C", qs("sidebar", "toggle"))
hl.bind(mainMod .. " + V", qs("rightbar", "toggle"))
hl.bind(mainMod .. " + N", qs("notif", "toggle"))
hl.bind(mainMod .. " + G", qs("island", "togglelayer"))  -- 一级岛置顶开关（全屏游戏时看歌词/通知）


-- ============================================================
-- 屏幕截图
-- ============================================================

local captureSh = "$HOME/.lian/qsl/scripts/capture.sh"

hl.bind("CTRL + ALT + A", sh("bash " .. captureSh .. " shot region"))
hl.bind("CTRL + ALT + Q", sh("bash " .. captureSh .. " shot full"))


-- ============================================================
-- 媒体控制
-- ============================================================

hl.bind("CTRL + ALT + D", qs("island", "mediatoggle"))
hl.bind("CTRL + ALT + left", qs("island", "mediaprevious"))
hl.bind("CTRL + ALT + right", qs("island", "medianext"))


-- ============================================================
-- 壁纸控制
-- ============================================================

hl.bind("CTRL + ALT + N", sh("lianwall next"))
hl.bind("CTRL + ALT + P", sh("lianwall prev"))
hl.bind("CTRL + ALT + S", sh("lianwall switch"))


-- ============================================================
-- 工作区跳转
-- ============================================================

hl.bind(mainMod .. " + SHIFT + left", sh(workspaceTool .. " down"))
hl.bind(mainMod .. " + SHIFT + right", sh(workspaceTool .. " up"))
hl.bind(mainMod .. " + SHIFT + down", sh(workspaceTool .. " empty"))
hl.bind(mainMod .. " + SHIFT + up", sh(workspaceTool .. " empty-max"))

-- Super+数字 → 聚焦工作区；Super+Shift+数字 → 窗口移入
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end


-- ============================================================
-- 焦点与移动
-- ============================================================

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + ALT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + ALT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.move({ direction = "down" }))


-- ============================================================
-- 鼠标操作
-- ============================================================

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- ============================================================
-- Submap：键盘调整窗口大小
-- ============================================================

local _resizeOriginalBorder

local function enterResize()
    _resizeOriginalBorder = hl.get_config("general.col.active_border")
    hl.config({ general = { col = { active_border = "rgb(ff6633)" } } })
    hl.exec_cmd("notify-send '↔ 窗口调整模式' '← → ↑ ↓ 调整大小 / Esc 退出'")
    hl.dispatch(hl.dsp.submap("resize"))
end

local function exitResize()
    if _resizeOriginalBorder then
        hl.config({ general = { col = { active_border = _resizeOriginalBorder } } })
    end
    hl.exec_cmd("notify-send -t 1000 '  窗口调整完成'")
    hl.dispatch(hl.dsp.submap(""))
end

hl.bind(mainMod .. " + R", enterResize)

hl.define_submap("resize", function()
    hl.bind("left",  hl.dsp.window.resize({ x = -5, y = 0, relative = true }), { repeating = true })
    hl.bind("right", hl.dsp.window.resize({ x = 5, y = 0, relative = true }),  { repeating = true })
    hl.bind("up",    hl.dsp.window.resize({ x = 0, y = -5, relative = true }), { repeating = true })
    hl.bind("down",  hl.dsp.window.resize({ x = 0, y = 5, relative = true }),  { repeating = true })
    hl.bind("SHIFT + left",  hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
    hl.bind("SHIFT + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }),  { repeating = true })
    hl.bind("SHIFT + up",    hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
    hl.bind("SHIFT + down",  hl.dsp.window.resize({ x = 0, y = 40, relative = true }),  { repeating = true })
    hl.bind("Escape", exitResize)
    hl.bind("Return", exitResize)
    hl.bind(mainMod .. " + R", exitResize)
end)
