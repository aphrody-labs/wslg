// Unit test for WSLGd/Compositor.h; builds with any C++17 compiler, no WSL needed.
#include "../Compositor.h"
#include <cstdio>
#include <cstdlib>

using namespace wslgd;

static int failures = 0;
#define CHECK(cond) do { if (!(cond)) { std::fprintf(stderr, "FAIL %s:%d %s\n", __FILE__, __LINE__, #cond); failures++; } } while (0)

int main()
{
    CHECK(ParseCompositorMode(nullptr) == CompositorMode::Weston);
    CHECK(ParseCompositorMode("") == CompositorMode::Weston);
    CHECK(ParseCompositorMode("weston") == CompositorMode::Weston);
    CHECK(ParseCompositorMode("WESTON") == CompositorMode::Weston);
    CHECK(ParseCompositorMode("hyprland-nested") == CompositorMode::HyprlandNested);
    CHECK(ParseCompositorMode("Hyprland-Headless") == CompositorMode::HyprlandHeadless);
    CHECK(ParseCompositorMode("hyprland") == CompositorMode::Invalid);
    CHECK(ParseCompositorMode("sway") == CompositorMode::Invalid);

    CHECK(std::string(CompositorModeName(CompositorMode::HyprlandNested)) == "hyprland-nested");
    CHECK(ParseCompositorMode(CompositorModeName(CompositorMode::HyprlandHeadless)) == CompositorMode::HyprlandHeadless);
    CHECK(IsHyprland(CompositorMode::HyprlandNested) && IsHyprland(CompositorMode::HyprlandHeadless));
    CHECK(!IsHyprland(CompositorMode::Weston) && !IsHyprland(CompositorMode::Invalid));

    CHECK(HyprlandConfigPath(CompositorMode::HyprlandNested) == "/etc/wslg/hyprland-nested.lua");
    CHECK(HyprlandConfigPath(CompositorMode::HyprlandHeadless) == "/etc/wslg/hyprland-headless.lua");

    auto cmd = HyprlandCommand("/x.conf");
    CHECK(cmd.size() == 5 && cmd[2] == "/usr/bin/Hyprland" && cmd[4] == "/x.conf");

    auto nested = HyprlandEnv(CompositorMode::HyprlandNested, "wayland-0");
    auto headless = HyprlandEnv(CompositorMode::HyprlandHeadless, "wayland-0");
    auto has = [](const std::vector<std::string>& v, const char* s) {
        for (auto& e : v) if (e == s) return true;
        return false;
    };
    CHECK(has(nested, "WAYLAND_DISPLAY=wayland-0"));
    CHECK(!has(headless, "WAYLAND_DISPLAY=wayland-0"));
    CHECK(has(headless, "XDG_CURRENT_DESKTOP=Hyprland"));

    if (failures == 0) std::puts("compositor_test: all checks passed");
    return failures ? EXIT_FAILURE : EXIT_SUCCESS;
}
