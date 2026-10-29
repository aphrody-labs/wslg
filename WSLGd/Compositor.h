// BunOS patch: compositor selection for WSLGd. Header-only and free of WSLG/winpr
// dependencies so it can be unit-tested on any Linux host (see tests/compositor_test.cpp).
#pragma once
#include <cctype>
#include <string>
#include <vector>

namespace wslgd
{
    // WSL2_COMPOSITOR (settable in .wslgconfig [system-distro-env]).
    //   weston            Weston RDP backend + rdprail-shell (upstream behaviour, default).
    //   hyprland-nested   Weston as before, plus Hyprland as a Wayland client of it
    //                     (aquamarine wayland backend); Hyprland listens on wayland-1.
    //   hyprland-headless Weston as before for the Windows side, plus Hyprland on its
    //                     headless backend. No RDP bridge exists: see docs/BUNOS-PATCHES.md.
    enum class CompositorMode
    {
        Weston,
        HyprlandNested,
        HyprlandHeadless,
        Invalid,
    };

    inline CompositorMode ParseCompositorMode(const char* value)
    {
        if (value == nullptr || *value == '\0') {
            return CompositorMode::Weston;
        }

        std::string v(value);
        for (auto& c : v) {
            c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
        }

        if (v == "weston") {
            return CompositorMode::Weston;
        }
        if (v == "hyprland-nested") {
            return CompositorMode::HyprlandNested;
        }
        if (v == "hyprland-headless") {
            return CompositorMode::HyprlandHeadless;
        }
        return CompositorMode::Invalid;
    }

    inline const char* CompositorModeName(CompositorMode mode)
    {
        switch (mode) {
        case CompositorMode::Weston: return "weston";
        case CompositorMode::HyprlandNested: return "hyprland-nested";
        case CompositorMode::HyprlandHeadless: return "hyprland-headless";
        default: return "invalid";
        }
    }

    inline bool IsHyprland(CompositorMode mode)
    {
        return mode == CompositorMode::HyprlandNested || mode == CompositorMode::HyprlandHeadless;
    }

    // argv of the Hyprland launch. dbus-run-session gives Hyprland a session bus.
    inline std::vector<std::string> HyprlandCommand(const std::string& configPath)
    {
        return {"/usr/bin/dbus-run-session", "--", "/usr/bin/Hyprland", "--config", configPath};
    }

    // Config file for the mode, relative to the system distro /etc/wslg.
    inline std::string HyprlandConfigPath(CompositorMode mode)
    {
        return mode == CompositorMode::HyprlandHeadless ? "/etc/wslg/hyprland-headless.lua"
                                                        : "/etc/wslg/hyprland-nested.lua";
    }

    // Extra environment (NAME=value) for the Hyprland process, on top of WSLGd's own.
    //  nested:   host compositor is Weston's wayland-0 (aquamarine wayland backend).
    //  headless: WAYLAND_DISPLAY must be empty so aquamarine does not pick its wayland
    //            fallback backend; an empty entry is skipped by ProcessMonitor, so the
    //            variable is explicitly set to the empty string by the caller via unsetenv.
    inline std::vector<std::string> HyprlandEnv(CompositorMode mode, const std::string& hostWaylandDisplay)
    {
        std::vector<std::string> env{"XDG_CURRENT_DESKTOP=Hyprland", "XDG_SESSION_TYPE=wayland"};
        if (mode == CompositorMode::HyprlandNested) {
            env.push_back("WAYLAND_DISPLAY=" + hostWaylandDisplay);
        }
        return env;
    }
}
