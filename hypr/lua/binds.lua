-- 快捷键配置
--     这个文件专注于配置 hyprland 级别的快捷键


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

-- 调用 quickshell IPC 接口（qs ipc call）
local function qs(mod, action)
    return hl.dsp.exec_cmd("qs ipc call " .. mod .. " " .. action)
end


-- ============================================================
-- 默认应用 / 脚本路径
-- ============================================================

-- 终端模拟器
local terminal = "kitty"
-- 文件管理器
local fileManager = "thunar"
-- 浏览器
local browser = "google-chrome-stable"

-- 用户脚本根目录（XDG ~/.local/bin）
local scriptDir = "/home/Sakurine/.local/bin"
-- 电源菜单（wlogout）
local sysmenu = scriptDir .. "/wlogout/wlogout"
-- 工作区切换工具（qs workspace）
local workspaceTool = scriptDir .. "/qshell/workspaces"


-- ============================================================
-- 布局管理
-- ============================================================

-- 切换布局：dwindle ↔ scrolling（带通知提示）
hl.bind(mainMod .. " + S", function()
    -- 1. 读取当前布局
    local currentLayout = hl.get_config("general.layout")
    -- 2. 计算相反布局
    local nextLayout = currentLayout == "dwindle" and "scrolling" or "dwindle"
    -- 3. 写入新布局
    hl.config({ general = { layout = nextLayout } })
    -- 4. 发送通知
    if nextLayout == "scrolling" then
        hl.exec_cmd("notify-send '<>  切换到 scrolling 布局'")
    else
        hl.exec_cmd("notify-send '[-]  切换到 dwindle 布局'")
    end
end)


-- ============================================================
-- 窗口 / 电源管理
-- ============================================================

-- 关闭当前窗口
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- 切换浮动 / 嵌入模式
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
-- 退出 Hyprland（优先 hyprshutdown，fallback 到 hyprctl）
hl.bind(mainMod .. " + M", sh("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))
-- 电源菜单（wlogout）
hl.bind(mainMod .. " + SPACE", sh(sysmenu))


-- ============================================================
-- 应用启动
-- ============================================================

-- 终端
hl.bind(mainMod .. " + T", sh(terminal))
-- 文件管理器
hl.bind(mainMod .. " + E", sh(fileManager))
-- 浏览器
hl.bind(mainMod .. " + B", sh(browser))


-- ============================================================
-- 启动菜单
-- ============================================================

-- 应用启动器
hl.bind(mainMod .. " + A", qs("launcher", "toggle"))
-- 剪贴板面板
hl.bind(mainMod .. " + Z", qs("clipboard", "toggle"))
-- Emoji 面板
hl.bind(mainMod .. " + X", qs("emoji", "toggle"))


-- ============================================================
-- Quickshell 显示控制
-- ============================================================

-- 切换覆盖层显示模式
hl.bind(mainMod .. " + G", qs("overlay", "next"))


-- ============================================================
-- 灵动岛
-- ============================================================

-- Hub 主视图
hl.bind("ALT + TAB", qs("island", "hub"))
-- Switcher 窗口切换
hl.bind(mainMod .. " + TAB", qs("island", "switcher"))
-- 左侧边栏（系统视图 + 天气）
hl.bind(mainMod .. " + C", qs("sidebar", "toggle"))
-- 右侧边栏（QuickSettings）
hl.bind(mainMod .. " + V", qs("rightbar", "toggle"))
-- 通知中心
hl.bind(mainMod .. " + N", qs("notif", "toggle"))


-- ============================================================
-- 截图 / 录制
-- ============================================================

-- 区域截图
hl.bind("CTRL + ALT + A", qs("island", "captureshot region"))
-- 全屏截图
hl.bind("CTRL + ALT + Q", qs("island", "captureshot full"))
-- 全屏录制 开始/停止
hl.bind("CTRL + ALT + R", qs("island", "capturerecordtoggle video full"))
-- 录制状态键（空闲→菜单 / 录制中→暂停 / 暂停→恢复）
hl.bind("CTRL + ALT + S", qs("island", "capturestatekey"))
-- 强制停止录制并保存
hl.bind("CTRL + ALT + SHIFT + S", qs("island", "captureforcestop"))


-- ============================================================
-- 媒体控制
-- ============================================================

-- 播放 / 暂停
hl.bind("CTRL + ALT + D", qs("island", "mediatoggle"))
-- 上一首
hl.bind("CTRL + ALT + left", qs("island", "mediaprevious"))
-- 下一首
hl.bind("CTRL + ALT + right", qs("island", "medianext"))


-- ============================================================
-- 壁纸控制
-- ============================================================

-- 下一张壁纸
hl.bind("ALT + N", sh("lianwall next"))
-- 切换壁纸模式（image / video）
hl.bind("ALT + S", sh("lianwall switch"))


-- ============================================================
-- 工作区管理
-- ============================================================

-- 上一个非空工作区
hl.bind(mainMod .. " + SHIFT + left", sh(workspaceTool .. " down"))
-- 下一个非空工作区
hl.bind(mainMod .. " + SHIFT + right", sh(workspaceTool .. " up"))
-- 下一个空工作区
hl.bind(mainMod .. " + SHIFT + down", sh(workspaceTool .. " empty"))

-- Super+数字键 → 跳到工作区 N（Super+0 = 工作区 10）
-- Super+Shift+数字键 → 移动窗口到工作区 N
--     利用取余算法批量生成 20 条绑定：
--     1~9 → key = 数字本身，10 → key = 0（因为键盘没有 10 键）
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end


-- ============================================================
-- 焦点 / 窗口移动
-- ============================================================

-- 焦点切换（Super+方向键）
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- 窗口移动（Super+Alt+方向键）
hl.bind(mainMod .. " + ALT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + ALT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.move({ direction = "down" }))


-- ============================================================
-- 鼠标操作
--     mouse:272 = X 左键
--     mouse:273 = X 右键
-- ============================================================

-- Super+左键拖拽窗口
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
-- Super+右键调整窗口大小
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- ============================================================
-- Submap：键盘调整窗口大小
--     进入 resize 模式后：边框变亮橙色，通知提示
--     退出后恢复原边框色
--     Esc / Enter / Super+R 退出
-- ============================================================

-- 保存进入 resize 前的活动边框色，退出时恢复
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
    hl.bind("left",  hl.dsp.window.resize({ x = -20, y = 0, relative = true }))
    hl.bind("right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }))
    hl.bind("up",    hl.dsp.window.resize({ x = 0, y = -20, relative = true }))
    hl.bind("down",  hl.dsp.window.resize({ x = 0, y = 20, relative = true }))
    hl.bind("Escape", exitResize)
    hl.bind("Return", exitResize)
    hl.bind(mainMod .. " + R", exitResize)
end)
