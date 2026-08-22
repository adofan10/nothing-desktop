#!/usr/bin/env bash
# Step 6 -- Plymouth boot + shutdown animation. MUST be run with sudo.
#     sudo ./install/60-boot-animation.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "$(id -u)" -eq 0 ] || die "run this one with sudo"
SRC="$REPO/plymouth/nothing"
THEME=/usr/share/plymouth/themes/nothing

say "Installing the theme"
rm -rf "$THEME"
install -d -m 755 "$THEME"
install -m 644 "$SRC"/dot-*.png "$THEME/"
install -m 644 "$SRC"/nothing.script "$SRC"/nothing.plymouth "$SRC"/nothing.grub "$THEME/"
[ -f "$SRC/LICENSE" ] && install -m 644 "$SRC/LICENSE" "$THEME/"
step "$(ls "$THEME"/dot-*.png | wc -l) frames (expect 60)"

say "Registering as the default theme"
update-alternatives --install \
  /usr/share/plymouth/themes/default.plymouth default.plymouth \
  "$THEME/nothing.plymouth" 200 \
  --slave /usr/share/plymouth/themes/default.grub default.plymouth.grub "$THEME/nothing.grub"
update-alternatives --set default.plymouth "$THEME/nothing.plymouth"
step "default.plymouth -> $(readlink -f /usr/share/plymouth/themes/default.plymouth)"

# plymouthd.conf OUTRANKS update-alternatives wherever the named theme exists.
# Leave it pointing elsewhere and boot may still show this theme (because the
# named one is absent from the initramfs and plymouth falls through), while
# SHUTDOWN -- which runs from the real root, where it does exist -- shows the
# other one. Name it explicitly so both ends match.
say "Pinning the theme in plymouthd.conf"
CONF=/etc/plymouth/plymouthd.conf
install -d /etc/plymouth
if [ -f "$CONF" ] && grep -q '^Theme=' "$CONF"; then
    sed -i 's/^Theme=.*/Theme=nothing/' "$CONF"
else
    grep -q '^\[Daemon\]' "$CONF" 2>/dev/null || echo '[Daemon]' >> "$CONF"
    echo 'Theme=nothing' >> "$CONF"
fi
step "$(grep '^Theme=' "$CONF")"

say "Rebuilding the initramfs"
update-initramfs -u

say "Verification"
INIT=/boot/initrd.img-$(uname -r)
printf '    %-22s %s\n' "frames installed"  "$(ls "$THEME"/dot-*.png 2>/dev/null | wc -l)  (expect 60)"
printf '    %-22s %s\n' "frames in initramfs" "$(lsinitramfs "$INIT" 2>/dev/null | grep -c 'themes/nothing/dot-' || echo 0)  (expect 60)"
printf '    %-22s %s\n' "script in initramfs" "$(lsinitramfs "$INIT" 2>/dev/null | grep -c 'themes/nothing/nothing.script' || echo 0)  (expect 1)"
printf '    %-22s %s\n' "configured theme"   "$(grep '^Theme=' "$CONF")"

# A stale recordfail flag makes the next boot sit at the GRUB menu forever.
# update-grub races grub2-common.service and can leave it set, so always check.
say "GRUB recordfail (must be clear before you reboot)"
if grub-editenv /boot/grub/grubenv list 2>/dev/null | grep -q recordfail; then
    warn "recordfail was set -- clearing it"
    grub-editenv /boot/grub/grubenv unset recordfail
    systemctl reset-failed grub2-common.service 2>/dev/null || true
    step "cleared"
else
    step "clean"
fi

cat <<MSG

Done -- reboot to see it.

Rollback:
    sudo update-alternatives --set default.plymouth \\
        /usr/share/plymouth/themes/kubuntu-logo/kubuntu-logo.plymouth
    sudo sed -i 's/^Theme=.*/Theme=kubuntu-logo/' /etc/plymouth/plymouthd.conf
    sudo update-initramfs -u

To re-render the frames at a different size, edit and run:
    python3 $SRC/make-frames.py
MSG
