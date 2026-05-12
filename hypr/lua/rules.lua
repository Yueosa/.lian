local function appWindowRule(name, class, opts)
    opts = opts or {}
    opts.name = name
    opts.match = opts.match or { class = class }
    hl.window_rule(opts)
end

appWindowRule("rofi-floating", "^(Rofi)$", {
    float = true,
    center = true,
})

appWindowRule("nmrs-floating", "^(org.nmrs.ui)$", {
    float = true,
    size = "400 600",
    center = true,
})

appWindowRule("pavucontrol-floating", "^(org.pulseaudio.pavucontrol)$", {
    float = true,
    size = "600 740",
    center = true,
})

appWindowRule("blueman-floating", "^(blueman-manager)$", {
    float = true,
    size = "560 800",
    center = true,
})

appWindowRule("tuxedo-control-center-floating", "^(tuxedo-control-center)$", {
    float = true,
    size = "1250 800",
    center = true,
})

appWindowRule("lianwall-gui-floating", "^(lianwall-gui)$", {
    float = true,
    size = "720 900",
    center = true,
})

appWindowRule("qq-tile", "^(QQ)$", {
    tile = true,
    match = { class = "^(QQ)$", title = "^(QQ)$" },
})

appWindowRule("mihomo-party-workspace", "^(mihomo-party)$", {
    workspace = "10 silent",
})

appWindowRule("kitty-opaque", "^(kitty)$", {
    opacity = "1.0 override",
})

hl.window_rule({
    name = "fcitx5-input-opaque",
    match = { initial_title = "^(Fcitx5 Input Window)$" },
    opacity = "1.0 override",
})

hl.layer_rule({
    name = "wlogout-blur",
    match = { namespace = "wlogout" },
    blur = true,
    ignore_alpha = 0,
})
