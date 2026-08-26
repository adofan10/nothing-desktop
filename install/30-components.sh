#!/usr/bin/env bash
# Step 3 -- the parts this repo actually owns, plus the appearance settings
# that a Global Theme alone does not set.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOCAL="$HOME/.local/share"
PLASMOIDS="$LOCAL/plasma/plasmoids"

say "Custom plasmoids"
mkdir -p "$PLASMOIDS"
for p in com.dev08.nothingdynamicisland com.dev08.nothingquote com.dev08.nothingappdrawer com.dev08.nothingglyph; do
    rm -rf "${PLASMOIDS:?}/$p"
    cp -r "$REPO/plasmoids/$p" "$PLASMOIDS/"
    step "$p"
done
chmod +x "$PLASMOIDS/com.dev08.nothingdynamicisland/contents/scripts/"*.sh 2>/dev/null || true

# The quote widget renders in the same serif faces as the rest of the grid.
# Those faces are bundled inside jaxparrow07's date widget; this repo does not
# redistribute them, so they are copied across after step 2 installed it.
say "Fonts for the quote widget"
SRC_FONTS="$PLASMOIDS/com.jaxparrow07.nothingkdewidgets.date/contents/fonts"
if [ -d "$SRC_FONTS" ]; then
    mkdir -p "$PLASMOIDS/com.dev08.nothingquote/contents/fonts"
    cp "$SRC_FONTS"/serif.otf "$SRC_FONTS"/serif-light.otf "$SRC_FONTS"/ndot.ttf \
       "$PLASMOIDS/com.dev08.nothingquote/contents/fonts/" 2>/dev/null || true
    step "copied $(ls "$PLASMOIDS/com.dev08.nothingquote/contents/fonts" | wc -l) faces"
else
    warn "date widget not found -- the quote widget will fall back to a system serif"
fi

say "KWin effect -- monochrome inactive windows"
mkdir -p "$LOCAL/kwin/effects"
rm -rf "$LOCAL/kwin/effects/nothing-monochrome-inactive"
cp -r "$REPO/kwin/effects/nothing-monochrome-inactive" "$LOCAL/kwin/effects/"
kwriteconfig6 --file kwinrc --group Plugins --key nothing-monochrome-inactiveEnabled true
kwriteconfig6 --file kwinrc --group Effect-nothing-monochrome-inactive --key Saturation 0
kwriteconfig6 --file kwinrc --group Effect-nothing-monochrome-inactive --key Duration 250
# Inactive windows drain to grey instead of going see-through, so turn the
# stock translucency off or the two effects fight.
kwriteconfig6 --file kwinrc --group Plugins --key translucencyEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true
kwriteconfig6 --file kwinrc --group Plugins --key contrastEnabled true
step "installed and enabled"

say "KWin script -- window cycle for the touchpad gestures"
mkdir -p "$LOCAL/kwin/scripts"
rm -rf "$LOCAL/kwin/scripts/nothing-window-cycle"
cp -r "$REPO/kwin/scripts/nothing-window-cycle" "$LOCAL/kwin/scripts/"
kwriteconfig6 --file kwinrc --group Plugins --key nothing-window-cycleEnabled true
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
step "registers NothingMinimiseFocusNext / NothingRestoreLast"

say "Three-finger touchpad gestures"
# KWin can bind touchpad swipes only from C++ -- registerTouchpadSwipeShortcut()
# is absent from the JS API that scripts get, and nothing on KWin's D-Bus exposes
# it either. So a small watcher reads libinput and invokes the two shortcuts
# above. It needs no privilege beyond membership of the `input` group.
install -m 755 "$REPO/services/nothing-gestures" "$HOME/.local/bin/nothing-gestures"
install -m 644 "$REPO/services/nothing-gestures.service" "$HOME/.config/systemd/user/"
[ -f "$HOME/.config/nothing-gestures.conf" ] || \
    install -m 644 "$REPO/services/nothing-gestures.conf" "$HOME/.config/nothing-gestures.conf"
systemctl --user daemon-reload >/dev/null 2>&1 || true
if ! id -nG | tr ' ' '\n' | grep -qx input; then
    warn "you are not in the 'input' group, so the gestures cannot read the touchpad"
    warn "  sudo gpasswd -a $USER input   # then log out and back in"
    warn "  note: this lets any process you run read every input device, keyboard included"
elif systemctl --user enable --now nothing-gestures.service >/dev/null 2>&1; then
    step "3 fingers down = minimise + focus next, up = restore"
else
    warn "could not enable nothing-gestures.service"
fi

say "Konsole theme"
mkdir -p "$LOCAL/konsole"
cp "$REPO/konsole/Nothing.colorscheme" "$REPO/konsole/Nothing.profile" "$LOCAL/konsole/"
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile "Nothing.profile"
# Konsole only picks up a profile named here at launch; existing windows keep theirs.
kwriteconfig6 --file konsolerc --group KonsoleWindow --key RememberProfile false 2>/dev/null || true
step "Nothing.profile set as default"

say "Widget reload on network-up"
# Several widgets fetch exactly once from Component.onCompleted -- the weather
# widget geocodes once and never retries -- and at login plasmashell is up
# seconds before Wi-Fi associates, so they sit empty until something restarts the
# shell. Plasma has no per-applet reload in its scripting API and no D-Bus call
# for one, so this watches NetworkManager over D-Bus and restarts
# plasma-plasmashell.service on a genuine offline->online edge. Debounced and
# rate-limited; see services/nothing-net-reload for the knobs.
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
install -m 755 "$REPO/services/nothing-net-reload" "$HOME/.local/bin/nothing-net-reload"
install -m 644 "$REPO/services/nothing-net-reload.service" "$HOME/.config/systemd/user/"
# never clobber settings someone has already tuned
[ -f "$HOME/.config/nothing-net-reload.conf" ] || \
    install -m 644 "$REPO/services/nothing-net-reload.conf" "$HOME/.config/nothing-net-reload.conf"
systemctl --user daemon-reload >/dev/null 2>&1 || true
if systemctl --user enable --now nothing-net-reload.service >/dev/null 2>&1; then
    step "watcher enabled"
else
    warn "could not enable nothing-net-reload.service -- widgets will not self-refresh"
fi

say "Appearance"
plasma-apply-lookandfeel -a Nothing >/dev/null 2>&1 || warn "global theme not applied"
plasma-apply-colorscheme Nothing    >/dev/null 2>&1 || true
plasma-apply-cursortheme WhiteSur-cursors >/dev/null 2>&1 || true
CHANGEICONS=$(ls /usr/lib/*/libexec/plasma-changeicons 2>/dev/null | head -1)
[ -n "$CHANGEICONS" ] && "$CHANGEICONS" YAMIS >/dev/null 2>&1 || true
kwriteconfig6 --file plasmarc  --group Theme   --key name Nothing
kwriteconfig6 --file kdeglobals --group Icons  --key Theme YAMIS

# A Global Theme does not carry fonts, so they have to be written explicitly.
NT="NType 82,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
for k in font menuFont toolBarFont; do
    kwriteconfig6 --file kdeglobals --group General --key "$k" "$NT"
done
kwriteconfig6 --file kdeglobals --group General --key smallestReadableFont "NType 82,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kdeglobals --group General --key fixed "NType 82 Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file kdeglobals --group WM      --key activeFont "$NT"
step "fonts, icons, colours, cursor"

say "Wallpaper"
WALL="$LOCAL/wallpapers/Nothing2"
if [ -d "$WALL" ]; then
    SRC=$(find "$WALL" -path '*/contents/images/*' -type f | sort | tail -1)
    OUT="$SRC"
    # Nothing2 ships at 2337x1080. On a taller screen Plasma crops it, which eats
    # the composition -- so pad it out to the panel size with its own field grey
    # (#b8b8b8) instead of letting it crop.
    if have magick || have convert; then
        IM=$(have magick && echo magick || echo convert)
        RES=$(kscreen-doctor -o 2>/dev/null | grep -oP '\d{3,5}x\d{3,5}' | head -1 || true)
        if [ -n "$RES" ]; then
            OUT="$(dirname "$SRC")/${RES}.png"
            "$IM" "$SRC" -background '#b8b8b8' -gravity center -extent "$RES" "$OUT" 2>/dev/null \
                && step "padded to $RES" || OUT="$SRC"
        fi
    fi
    plasma-apply-wallpaperimage "$OUT" >/dev/null 2>&1 || warn "could not set wallpaper"
    step "$(basename "$OUT")"
else
    warn "Nothing2 wallpaper missing -- step 2 may have failed"
fi

say "Monochrome dock icons for snap apps"
# Snap launchers hardcode an absolute PNG path, which bypasses the icon theme
# entirely. A local override makes YAMIS's monochrome versions win.
mkdir -p "$LOCAL/applications"
for app in firefox_firefox:firefox spotify_spotify:spotify; do
    f="${app%%:*}"; icon="${app##*:}"
    sys=$(ls /var/lib/snapd/desktop/applications/"$f".desktop 2>/dev/null | head -1)
    if [ -n "$sys" ]; then
        sed "s/^Icon=.*/Icon=$icon/" "$sys" > "$LOCAL/applications/$f.desktop"
        step "$f.desktop -> Icon=$icon"
    fi
done
update-desktop-database "$LOCAL/applications" 2>/dev/null || true

qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
say "Components done"
