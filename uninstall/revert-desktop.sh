#!/usr/bin/env bash
# Undo the desktop half of the rice: restore the most recent layout backup that
# install/40-layout.sh took, and put the stock Breeze appearance back.
#
# The login screen and boot splash are separate -- see the rollback blocks
# printed by install/50-login-screen.sh and install/60-boot-animation.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../install/lib.sh"

BK="$HOME/.nothing-rice-backups"
F=plasma-org.kde.plasma.desktop-appletsrc

say "Appearance -> Breeze"
plasma-apply-lookandfeel -a org.kde.breeze.desktop >/dev/null 2>&1 || true
plasma-apply-colorscheme BreezeDark >/dev/null 2>&1 || true
kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze-dark
for k in font menuFont toolBarFont; do
    kwriteconfig6 --file kdeglobals --group General --key "$k" "Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
done
kwriteconfig6 --file kdeglobals --group General --key fixed "Hack,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"

say "Disabling the monochrome-inactive effect"
kwriteconfig6 --file kwinrc --group Plugins --key nothing-monochrome-inactiveEnabled false
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true

LATEST=$(ls -1t "$BK"/appletsrc.* 2>/dev/null | head -1 || true)
if [ -n "$LATEST" ]; then
    say "Restoring layout from $(basename "$LATEST")"
    kquitapp6 plasmashell >/dev/null 2>&1 || true
    sleep 3
    cp "$LATEST" "$HOME/.config/$F"
    setsid kstart plasmashell >/dev/null 2>&1 &
    sleep 6
    step "restored"
else
    warn "no layout backup in $BK -- panels left as they are"
    warn "reset them by hand with: Right-click panel -> Show Panel Configuration -> Remove"
fi

cat <<'MSG'

Reverted. The custom plasmoids and the KWin effect are still on disk at
    ~/.local/share/plasma/plasmoids/com.dev08.*
    ~/.local/share/kwin/effects/nothing-monochrome-inactive
Delete those directories if you want them gone entirely.
MSG
