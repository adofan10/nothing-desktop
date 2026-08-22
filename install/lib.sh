#!/usr/bin/env bash
# Shared helpers. Sourced by every numbered step; not meant to be run directly.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO

# store.kde.org / pling content ids used by this rice
OCS_API="https://api.kde-look.org/ocs/v1/content/data"

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
step() { printf '    %s\n' "$*"; }
warn() { printf '    \033[33m!! %s\033[0m\n' "$*"; }
die()  { printf '\n\033[31mFAILED: %s\033[0m\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# Resolve a pling/store.kde.org content id to its first download, print the path.
# The store rotates its mirror hostnames, so the link is always resolved fresh
# from the OCS API rather than hardcoded.
ocs_download() {
    local id="$1" dest="$2" xml link name
    xml=$(curl -fsSL --retry 3 --retry-delay 2 "$OCS_API/$id") \
        || { warn "could not reach the KDE store for id $id"; return 1; }
    link=$(grep -o '<downloadlink1>[^<]*</downloadlink1>' <<<"$xml" | head -1 | sed 's/<[^>]*>//g; s/&amp;/\&/g')
    name=$(grep -o '<downloadname1>[^<]*</downloadname1>' <<<"$xml" | head -1 | sed 's/<[^>]*>//g')
    [ -n "$link" ] && [ -n "$name" ] || { warn "no download listed for id $id"; return 1; }
    curl -fsSL --retry 3 -o "$dest/$name" "$link" || { warn "download failed for id $id"; return 1; }
    printf '%s\n' "$dest/$name"
}

# Extract an archive into a directory, creating it first.
extract_to() {
    local archive="$1" target="$2"
    mkdir -p "$target"
    case "$archive" in
        *.tar.gz|*.tgz) tar xzf "$archive" -C "$target" ;;
        *.tar.xz)       tar xJf "$archive" -C "$target" ;;
        *.tar.bz2)      tar xjf "$archive" -C "$target" ;;
        *.zip)          unzip -qo "$archive" -d "$target" ;;
        *) die "don't know how to extract $archive" ;;
    esac
}

# Plasma 6 renamed every one of these. Fail early and clearly rather than
# half-applying the rice on a Plasma 5 box.
require_plasma6() {
    for c in kwriteconfig6 kreadconfig6 kpackagetool6 qdbus6 plasmashell; do
        have "$c" || die "$c not found -- this rice targets Plasma 6 (Kubuntu 24.04+)."
    done
}
