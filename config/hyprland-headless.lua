-- BunOS: Hyprland on aquamarine's headless backend. It needs a DRM render node for the GBM
-- allocator; no RDP bridge exists yet, so the output is only reachable through screencopy
-- (grim/wayvnc) from inside the system distro.
hl.on("hyprland.start", function ()
    hl.exec_cmd("hyprctl output create headless")
end)

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
