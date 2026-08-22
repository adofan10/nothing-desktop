#!/usr/bin/env bash
# Nothing OS rice for KDE Plasma 6 -- orchestrator.
#
#   ./install.sh            run the user-level steps (1-4), then print the sudo ones
#   ./install.sh all        also run steps 5 and 6 (will prompt for sudo)
#   ./install.sh 30 40      run just those steps
#
# Every step is idempotent and can be re-run on its own.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./install/lib.sh

USER_STEPS=(10-packages 20-upstream 30-components 40-layout)
ROOT_STEPS=(50-login-screen 60-boot-animation)

run() {
    local name="$1" f="./install/$1.sh"
    [ -f "$f" ] || die "no such step: $1"
    case "$name" in
        5*|6*) sudo -E bash "$f" ;;
        *)     bash "$f" ;;
    esac
}

if [ $# -gt 0 ] && [ "$1" != "all" ]; then
    for a in "$@"; do
        match=$(printf '%s\n' "${USER_STEPS[@]}" "${ROOT_STEPS[@]}" | grep "^$a" | head -1)
        [ -n "$match" ] || die "no step matching '$a'"
        run "$match"
    done
    exit 0
fi

cat <<'BANNER'

   ┌───────────────────────────────────────────────┐
   │   N O T H I N G   ·   KDE Plasma 6 rice       │
   └───────────────────────────────────────────────┘

   This replaces your panels and desktop widgets.
   Your current layout is backed up to ~/.nothing-rice-backups/

BANNER
read -rp "   Continue? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "   aborted."; exit 0; }

for s in "${USER_STEPS[@]}"; do run "$s"; done

if [ "${1:-}" = "all" ]; then
    for s in "${ROOT_STEPS[@]}"; do run "$s"; done
else
    cat <<'MSG'

===============================================================
 Desktop done. Two steps left, both need root:

     sudo ./install/50-login-screen.sh     # SDDM login screen
     sudo ./install/60-boot-animation.sh   # Plymouth boot splash

 Then log out and back in (or reboot) so the fonts and the
 window decoration are picked up everywhere.
===============================================================
MSG
fi
