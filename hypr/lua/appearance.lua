hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

hl.config({
    misc = {
        disable_hyprland_logo = true,
        initial_workspace_tracking = 0,
    },

    general = {
        gaps_in = 6,
        gaps_out = 12,
        border_size = 3,
        col = {
            active_border = { colors = { "rgba(ffb7c5ee)", "rgba(87cefaee)", "rgba(ffffffee)" }, angle = 45 },
            inactive_border = "rgba(87cefa55)",
        },
        layout = "dwindle",
    },

    scrolling = {
        direction = "right",
        column_width = 0.8,
        follow_focus = true,
        follow_min_visible = 0.4,
        fullscreen_on_one_column = true,
    },

    decoration = {
        rounding = 12,
        active_opacity = 0.9,
        inactive_opacity = 0.8,
        shadow = {
            enabled = true,
            range = 15,
            render_power = 3,
            color = "rgba(b19cd933)",
        },
        blur = {
            enabled = true,
            size = 8,
            passes = 2,
            new_optimizations = true,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("fastIn", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "fastIn", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "fastIn", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "fastIn" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "fastIn", style = "slidefade" })
