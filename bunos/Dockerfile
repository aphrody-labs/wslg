# syntax=docker/dockerfile:1.7
# BunOS source stack: newest Weston, Xwayland (xwayland-shell) and the Hyprland chain at the
# tags pinned in versions.env, on Arch Linux. Used to probe protocol coverage and to carry the
# compositor binaries that the WSLg system distro does not have. Build context: the repository root (docker build -f bunos/Dockerfile .)
ARG ARCH_IMAGE=docker.io/library/archlinux:base-devel

FROM ${ARCH_IMAGE} AS base
RUN pacman -Syu --noconfirm --needed \
      git meson ninja cmake pkgconf python python-mako curl \
      wayland wayland-protocols libxkbcommon pixman libinput libevdev mtdev \
      cairo pango libpng libjpeg-turbo libwebp freerdp libdrm mesa libglvnd \
      libxcb xcb-util-cursor libxcursor lcms2 libxml2 xorgproto libxcvt \
      wayland-utils xorg-xdpyinfo xorg-xwininfo xorg-xprop procps-ng \
 && pacman -Scc --noconfirm
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig \
    LD_LIBRARY_PATH=/usr/local/lib \
    PATH=/usr/local/bin:/usr/bin:/bin
COPY bunos/versions.env /opt/bunos/
COPY bunos/deps/ /opt/bunos/deps/
COPY bunos/patches/ /opt/bunos/patches/
WORKDIR /src

# ---------------------------------------------------------------- libwayland + wayland-protocols
FROM base AS wayland
RUN . /opt/bunos/versions.env \
 && git clone --depth 1 -b "${WAYLAND_TAG}" https://gitlab.freedesktop.org/wayland/wayland.git wayland \
 && test "$(git -C wayland rev-parse HEAD)" = "${WAYLAND_SHA}" \
 && meson setup wayland/build wayland --prefix=/usr/local --libdir=lib --buildtype=release \
      -Ddocumentation=false -Dtests=false -Ddtd_validation=false \
 && ninja -C wayland/build install \
 && git clone --depth 1 -b "${WAYLAND_PROTOCOLS_TAG}" https://gitlab.freedesktop.org/wayland/wayland-protocols.git wlp \
 && test "$(git -C wlp rev-parse HEAD)" = "${WAYLAND_PROTOCOLS_SHA}" \
 && meson setup wlp/build wlp --prefix=/usr/local --libdir=lib -Dtests=false \
 && ninja -C wlp/build install && ldconfig

# ---------------------------------------------------------------- Xwayland (xwayland-shell)
# XW_TAG/XW_SHA build args override the pins; they default to the stable line; CI also builds the 26.1 RC candidate.
FROM wayland AS xwayland
ARG XW_TAG=
ARG XW_SHA=
RUN . /opt/bunos/versions.env \
 && XWAYLAND_TAG=${XW_TAG:-$XWAYLAND_TAG} && XWAYLAND_SHA=${XW_SHA:-$XWAYLAND_SHA} \
 && pacman -S --noconfirm --needed --asdeps $(bash /opt/bunos/deps/list.sh xorg-xwayland) \
 && git clone --depth 1 -b "${XWAYLAND_TAG}" https://gitlab.freedesktop.org/xorg/xserver.git xserver \
 && test "$(git -C xserver rev-parse HEAD)" = "${XWAYLAND_SHA}" \
 && opts="" \
 && for o in xvfb=false xdmcp=false secure-rpc=false xwayland_ei=false docs=false devel-docs=false docs-pdf=false; do \
      grep -q "option('${o%%=*}'" xserver/meson_options.txt && opts="$opts -D$o"; done \
 && echo "xserver meson options: $opts" \
 && meson setup xserver/build xserver --prefix=/usr/local --libdir=lib --buildtype=release $opts \
 && ninja -C xserver/build install

# ---------------------------------------------------------------- Weston
FROM xwayland AS weston
RUN . /opt/bunos/versions.env \
 && pacman -S --noconfirm --needed --asdeps $(bash /opt/bunos/deps/list.sh weston) \
 && git clone --depth 1 -b "${WESTON_TAG}" https://gitlab.freedesktop.org/wayland/weston.git weston \
 && test "$(git -C weston rev-parse HEAD)" = "${WESTON_SHA}" \
 && meson setup weston/build weston --prefix=/usr/local --libdir=lib --buildtype=release \
      -Dbackend-headless=true -Dbackend-rdp=true -Dbackend-drm=false -Dbackend-wayland=false \
      -Dbackend-pipewire=false -Dbackend-vnc=false -Dbackend-default=headless \
      -Drenderer-gl=true -Drenderer-vulkan=false \
      -Dxwayland=true -Dxwayland-path=/usr/local/bin/Xwayland \
      -Dshell-desktop=true -Dshell-ivi=false -Dshell-kiosk=false -Dshell-lua=false \
      -Dsystemd=false -Dcolor-management-lcms=false -Dimage-jpeg=true -Dimage-webp=false \
      -Ddeprecated-pipewire=false -Ddeprecated-remoting=false \
      -Dsimple-clients=shm,egl,damage -Dtools=info -Ddemo-clients=false \
      -Dtests=false -Ddoc=false \
 && ninja -C weston/build install

# ---------------------------------------------------------------- Hyprland chain
FROM weston AS hyprland
RUN . /opt/bunos/versions.env \
 && pacman -S --noconfirm --needed --asdeps \
      $(bash /opt/bunos/deps/list.sh hyprland hyprwire aquamarine hyprcursor hyprgraphics hyprlang hyprutils hyprwayland-scanner) \
 && clone() { git clone --depth 1 -b "$2" "https://github.com/hyprwm/$1.git" "$1" \
              && test "$(git -C "$1" rev-parse HEAD)" = "$3"; } \
 && cm() { cmake -S "$1" -B "$1/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_INSTALL_LIBDIR=lib "${@:2}" \
           && cmake --build "$1/build" -j"$(nproc)" && cmake --install "$1/build"; } \
 && clone hyprwayland-scanner "$HYPRWAYLAND_SCANNER_TAG" "$HYPRWAYLAND_SCANNER_SHA" && cm hyprwayland-scanner \
 && clone hyprland-protocols "$HYPRLAND_PROTOCOLS_TAG" "$HYPRLAND_PROTOCOLS_SHA" \
 && cm hyprland-protocols \
 && clone hyprutils "$HYPRUTILS_TAG" "$HYPRUTILS_SHA" && cm hyprutils \
 && clone hyprlang "$HYPRLANG_TAG" "$HYPRLANG_SHA" && cm hyprlang \
 && clone hyprcursor "$HYPRCURSOR_TAG" "$HYPRCURSOR_SHA" && cm hyprcursor \
 && clone hyprgraphics "$HYPRGRAPHICS_TAG" "$HYPRGRAPHICS_SHA" && cm hyprgraphics \
 && clone aquamarine "$AQUAMARINE_TAG" "$AQUAMARINE_SHA" \
 && git -C aquamarine apply /opt/bunos/patches/aquamarine-*.patch && cm aquamarine \
 && clone hyprwire "$HYPRWIRE_TAG" "$HYPRWIRE_SHA" && cm hyprwire \
 && ldconfig \
 && git clone --depth 1 --recurse-submodules --shallow-submodules -b "$HYPRLAND_TAG" https://github.com/hyprwm/Hyprland.git Hyprland \
 && test "$(git -C Hyprland rev-parse HEAD)" = "$HYPRLAND_SHA" \
 && cm Hyprland -DNO_TESTS=ON -DNO_HYPRPM=ON -DNO_UWSM=ON -DNO_SYSTEMD=ON -DBUILD_TESTING=OFF \
 && ldconfig

# ---------------------------------------------------------------- probes
FROM hyprland AS probes
RUN pacman -S --noconfirm --needed wlr-randr grim python \
 && pacman -Scc --noconfirm
COPY bunos/probes/ /opt/bunos/probes/
COPY config/hyprland-nested.lua config/hyprland-headless.lua /etc/wslg/
RUN useradd -m probe && chmod +x /opt/bunos/probes/*.sh
USER probe
ENTRYPOINT ["/opt/bunos/probes/run-probes.sh"]
