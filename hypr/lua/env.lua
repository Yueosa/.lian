-- General Wayland, Qt and cursor environment.

hl.env("XDG_SESSION_TYPE", "wayland")

hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.env("XCURSOR_THEME", "BreezeX-RosePineDawn-Linux")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "BreezeX-RosePineDawn-Linux")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
