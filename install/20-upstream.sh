#!/usr/bin/env bash
# Step 2 -- everything this repo deliberately does NOT vendor: the KDE-store
# themes, the widget pack, and Nothing's fonts. All fetched from their authors.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
LOCAL="$HOME/.local/share"

say "Nothing KDE Widgets + fonts (jaxparrow07)"
# The widget pack is the only source of Nothing's fonts and of the shared
# NothingColors palette. The quote widget in this repo needs its serif faces.
if [ -d "$TMP/nkw" ]; then :; else
    git clone --depth 1 https://github.com/jaxparrow07/nothing-kde-widgets "$TMP/nkw" \
        || die "could not clone the widget pack"
fi
found=0
for p in "$TMP"/nkw/*/metadata.json "$TMP"/nkw/*/*/metadata.json; do
    [ -f "$p" ] || continue
    d=$(dirname "$p")
    kpackagetool6 --type Plasma/Applet --install "$d" >/dev/null 2>&1 \
        || kpackagetool6 --type Plasma/Applet --upgrade "$d" >/dev/null 2>&1 || true
    found=$((found+1))
done
step "installed/upgraded $found widget packages"
[ "$found" -gt 0 ] || warn "no widgets installed -- check the repo layout upstream"

step "fonts -> ~/.local/share/fonts/nothing/"
mkdir -p "$LOCAL/fonts/nothing"
find "$TMP/nkw" -type f \( -iname '*.otf' -o -iname '*.ttf' \) -exec cp -n {} "$LOCAL/fonts/nothing/" \;
fc-cache -f >/dev/null
step "$(ls "$LOCAL/fonts/nothing" | wc -l) font files"

say "KDE store themes"
# id : kind : where it goes
install_ocs() {
    local id="$1" kind="$2" label="$3" f
    f=$(ocs_download "$id" "$TMP") || { warn "skipped $label (id $id)"; return 0; }
    case "$kind" in
        lookandfeel) kpackagetool6 --type Plasma/LookAndFeel --install "$f" >/dev/null 2>&1 \
                     || kpackagetool6 --type Plasma/LookAndFeel --upgrade "$f" >/dev/null 2>&1 || true ;;
        plasmatheme) kpackagetool6 --type Plasma/Theme --install "$f" >/dev/null 2>&1 \
                     || kpackagetool6 --type Plasma/Theme --upgrade "$f" >/dev/null 2>&1 || true ;;
        applet)      kpackagetool6 --type Plasma/Applet --install "$f" >/dev/null 2>&1 \
                     || kpackagetool6 --type Plasma/Applet --upgrade "$f" >/dev/null 2>&1 || true ;;
        aurorae)     extract_to "$f" "$LOCAL/aurorae/themes" ;;
        colors)      extract_to "$f" "$TMP/colors"
                     mkdir -p "$LOCAL/color-schemes"
                     find "$TMP/colors" -name '*.colors' -exec cp {} "$LOCAL/color-schemes/" \; ;;
        icons)       extract_to "$f" "$LOCAL/icons" ;;
        cursors)     extract_to "$f" "$HOME/.icons" ;;
        wallpaper)   extract_to "$f" "$LOCAL/wallpapers" ;;
    esac
    step "$label"
}

install_ocs 2116667 lookandfeel "Global theme  -- Nothing (jomada)"
install_ocs 2116665 plasmatheme "Plasma style  -- Nothing"
install_ocs 2116663 aurorae     "Decoration    -- Nothing (aurorae)"
install_ocs 2116662 colors      "Colour scheme -- Nothing"
install_ocs 2303161 icons       "Icons         -- YAMIS (dirn)"
install_ocs 1411743 cursors     "Cursor        -- WhiteSur"
install_ocs 2116657 wallpaper   "Wallpaper     -- Nothing1"
install_ocs 2116658 wallpaper   "Wallpaper     -- Nothing2 (the grey one used here)"
install_ocs 2116659 wallpaper   "Wallpaper     -- Nothing3"
install_ocs 2130967 applet      "Panel Colorizer (luisbocanegra)"

say "Overview widget (himdek)"
if git clone --depth 1 https://github.com/HimDek/Plasma-Overview-Widget "$TMP/ov" >/dev/null 2>&1; then
    d=$(find "$TMP/ov" -name metadata.json -printf '%h\n' | head -1)
    [ -n "$d" ] && { kpackagetool6 --type Plasma/Applet --install "$d" >/dev/null 2>&1 \
                  || kpackagetool6 --type Plasma/Applet --upgrade "$d" >/dev/null 2>&1 || true; }
    step "installed"
else
    warn "skipped -- the dock will lose its overview button; edit install/40-layout.sh to drop it"
fi

say "Upstream assets done"
