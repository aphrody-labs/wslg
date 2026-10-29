-- BunOS: Hyprland nested in WSLg's Weston (aquamarine wayland backend).
-- Written for the Hyprland 0.57 Lua config API (example/hyprland.lua of v0.57.0).
-- Needs a compositor offering xdg_wm_base v6, wl_compositor v6, zwp_linux_dmabuf_v1 v4 and a
-- DRM render node; the stock WSLg Weston 9.0.0 offers none of that (docs/BUNOS-PATCHES.md).
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})

hl.env("XCURSOR_SIZE", "16")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
