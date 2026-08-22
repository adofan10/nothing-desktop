#!/usr/bin/env bash
# Step 1 -- distro packages. Needs sudo for apt only.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_plasma6

say "Installing distro packages"

PKGS=(
    curl unzip git                # fetching upstream assets
    papirus-icon-theme            # YAMIS inherits it; without it missing icons
                                  # fall back to colourful breeze-dark
    fonts-noto-color-emoji
    plymouth plymouth-themes      # boot animation
    python3-pil python3-numpy     # only to regenerate Plymouth frames
    imagemagick                   # wallpaper padding helper
)

sudo apt-get update
sudo apt-get install -y "${PKGS[@]}"

say "Optional: window decoration"
cat <<'MSG'
    The titlebars in the screenshots are Klassy (kdecoration3), built from
    source -- it is not in the Ubuntu archive:

        https://github.com/paulmcauley/klassy

    Klassy is OPTIONAL. Skip it and KWin falls back to Breeze, which still
    looks fine with this rice; the aurorae "Nothing" decoration installed in
    step 2 is the other option (it is kdecoration2, so Plasma 6.6+ ignores it
    unless you force it).
MSG

say "Packages done"
