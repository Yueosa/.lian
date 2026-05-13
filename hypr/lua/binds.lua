local mainMod = "SUPER"
local terminal = "kitty"
local fileManager = "thunar"
local browser = "google-chrome-stable"
local scriptDir = "/home/Sakurine/.local/bin"
local sysmenu = scriptDir .. "/wlogout/wlogout"
local workspaceTool = scriptDir .. "/qshell/workspaces"

local function sh(command)
    return hl.dsp.exec_cmd(command)
end

local function bind(keys, dispatcher, opts)
    hl.bind(keys, dispatcher, opts)
end

bind(mainMod .. " + S", function()
    local currentLayout = hl.get_config("general.layout")
    local nextLayout = currentLayout == "dwindle" and "scrolling" or "dwindle"

    hl.config({
        general = {
            layout = nextLayout,
        },
    })

    if nextLayout == "scrolling" then
        hl.exec_cmd("notify-send '<>  切换到 scrolling 布局'")
    else
        hl.exec_cmd("notify-send '[-]  切换到 dwindle 布局'")
    end
end)

bind(mainMod .. " + Q", hl.dsp.window.close())
bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
bind(mainMod .. " + M", sh("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))

bind(mainMod .. " + T", sh(terminal))
bind(mainMod .. " + E", sh(fileManager))
bind(mainMod .. " + A", sh("qs ipc call launcher toggle"))
bind("ALT + TAB", sh("qs ipc call island hub"))
bind("SUPER + TAB", sh("qs ipc call island switcher"))
bind(mainMod .. " + SPACE", sh(sysmenu))
bind(mainMod .. " + Z", sh("qs ipc call clipboard toggle"))
bind(mainMod .. " + X", sh("qs ipc call emoji toggle"))
bind(mainMod .. " + C", sh("qs ipc call sidebar toggle"))
bind(mainMod .. " + V", sh("qs ipc call rightbar toggle"))
bind(mainMod .. " + N", sh("qs ipc call notif toggle"))
bind(mainMod .. " + G", sh("qs ipc call overlay next"))
bind(mainMod .. " + B", sh(browser))

bind("CTRL + ALT + A", sh("qs ipc call island captureshot region"))
bind("CTRL + ALT + Q", sh("qs ipc call island captureshot full"))
bind("CTRL + ALT + R", sh("qs ipc call island capturerecordtoggle video full"))
bind("CTRL + ALT + S", sh("qs ipc call island capturestatekey"))
bind("CTRL + ALT + SHIFT + S", sh("qs ipc call island captureforcestop"))

bind("CTRL + ALT + D", sh("qs ipc call island mediatoggle"))
bind("CTRL + ALT + left", sh("qs ipc call island mediaprevious"))
bind("CTRL + ALT + right", sh("qs ipc call island medianext"))

bind("ALT + N", sh("lianwall next"))
bind("ALT + S", sh("lianwall switch"))

bind(mainMod .. " + SHIFT + left", sh(workspaceTool .. " down"))
bind(mainMod .. " + SHIFT + right", sh(workspaceTool .. " up"))
bind(mainMod .. " + SHIFT + down", sh(workspaceTool .. " empty"))

for i = 1, 10 do
    local key = i % 10
    bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

bind(mainMod .. " + ALT + left", hl.dsp.window.move({ direction = "left" }))
bind(mainMod .. " + ALT + right", hl.dsp.window.move({ direction = "right" }))
bind(mainMod .. " + ALT + up", hl.dsp.window.move({ direction = "up" }))
bind(mainMod .. " + ALT + down", hl.dsp.window.move({ direction = "down" }))

bind(mainMod .. " + mouse_up", hl.dsp.layout("move +col"))
bind(mainMod .. " + mouse_down", hl.dsp.layout("move -col"))

bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
