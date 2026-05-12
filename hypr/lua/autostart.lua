local screenshotDir = "$HOME/Pictures/Screenshots"

local importEnv = "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP HYPRLAND_INSTANCE_SIGNATURE DISPLAY GTK_IM_MODULE QT_IM_MODULE XMODIFIERS"

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd " .. importEnv)
    hl.exec_cmd("systemctl --user import-environment " .. importEnv)
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- Quickshell starts first so tray clients can attach to its StatusNotifierWatcher.
    hl.exec_cmd("qs")
    hl.exec_cmd("hyprctl setcursor BreezeX-RosePineDawn-Linux 24")
    hl.exec_cmd("mkdir -p " .. screenshotDir)

    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd("kanshi")
    hl.exec_cmd("mihomo-party")
    hl.exec_cmd("/home/Sakurine/.local/bin/lianclaw")
end)

hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop hyprland-session.target")
end)
