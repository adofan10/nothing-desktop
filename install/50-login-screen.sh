#!/usr/bin/env bash
# Step 5 -- the SDDM login screen. MUST be run with sudo.
#     sudo ./install/50-login-screen.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "$(id -u)" -eq 0 ] || die "run this one with sudo"
USERHOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
THEMES=/usr/share/sddm/themes
DEST="$THEMES/Nothing"

say "Fonts, system-wide"
# SDDM runs as the unprivileged 'sddm' user and cannot read anyone's $HOME.
# A theme that references NType 82 from ~/.local renders in a fallback face.
if [ -d "$USERHOME/.local/share/fonts/nothing" ]; then
    install -d /usr/local/share/fonts/nothing
    cp "$USERHOME"/.local/share/fonts/nothing/*.otf \
       "$USERHOME"/.local/share/fonts/nothing/*.ttf /usr/local/share/fonts/nothing/ 2>/dev/null || true
    chmod 644 /usr/local/share/fonts/nothing/*
    fc-cache -f >/dev/null
    step "$(ls /usr/local/share/fonts/nothing | wc -l) faces in /usr/local/share/fonts/nothing"
else
    warn "no Nothing fonts found -- run step 2 first"
fi

say "Installing the theme"
[ -d "$DEST" ] && cp -a "$DEST" "$DEST.bak.$(date +%Y%m%d-%H%M%S)"
rm -rf "$DEST"
cp -r "$REPO/sddm/Nothing" "$DEST"

# The repo does not vendor a 4 MB wallpaper; take the one already installed.
WALL=$(find "$USERHOME/.local/share/wallpapers/Nothing2" -path '*/contents/images/*' -type f 2>/dev/null | sort | tail -1)
if [ -n "$WALL" ]; then
    cp "$WALL" "$DEST/background.png"
    step "background from $(basename "$WALL")"
else
    warn "Nothing2 wallpaper not found -- falling back to a flat colour"
    sed -i 's/^type=.*/type=color/' "$DEST/theme.conf"
fi

# SDDM wants an avatar directory to exist even when the theme shows no avatars.
install -d "$DEST/faces"
chown -R root:root "$DEST"
chmod -R a+rX "$DEST"

say "Validating the QML before it can lock you out"
# An unknown property anywhere in the theme makes SDDM silently swap in the
# stock greeter -- the theme just "doesn't apply" with no visible error.
QMLLINT=$(ls /usr/lib/qt6/bin/qmllint 2>/dev/null || command -v qmllint 2>/dev/null || true)
if [ -n "$QMLLINT" ]; then
    bad=0
    for f in "$DEST"/*.qml; do
        if "$QMLLINT" "$f" 2>&1 | grep -q '^Error'; then
            warn "QML error in $(basename "$f")"; bad=1
        fi
    done
    [ "$bad" -eq 0 ] && step "no QML errors" || die "fix the theme before activating it"
else
    warn "qmllint not available -- skipping validation"
fi

say "Checking the sddm user can resolve the fonts"
for f in "NType 82" "NType 82 Mono" "Nothing Font (5x7)"; do
    got=$(sudo -u sddm fc-match "$f" 2>/dev/null || echo FAILED)
    printf '    %-22s -> %s\n' "$f" "$got"
done

say "Activating"
CONF=/etc/sddm.conf.d/kde_settings.conf
install -d /etc/sddm.conf.d
if [ -f "$CONF" ] && grep -q '^\[Theme\]' "$CONF"; then
    grep -q '^Current=' "$CONF" && sed -i 's/^Current=.*/Current=Nothing/' "$CONF" \
                                || sed -i '/^\[Theme\]/a Current=Nothing' "$CONF"
else
    printf '[Theme]\nCurrent=Nothing\n' >> "$CONF"
fi
grep -A1 '^\[Theme\]' "$CONF" | sed 's/^/    /'

cat <<'MSG'

Done. The new login screen appears at your next reboot.
Apply it now with:  sudo systemctl restart sddm   (this ends your session)

If it ever misbehaves, switch to a TTY with Ctrl+Alt+F3 and run:
    sudo sed -i 's/^Current=Nothing/Current=breeze/' /etc/sddm.conf.d/kde_settings.conf
    sudo systemctl restart sddm

To confirm the theme really loaded (rather than silently falling back):
    journalctl -b -u sddm | grep -i "Fallback to embedded theme"
  Any hit there means SDDM rejected the theme and used the stock greeter.
MSG
