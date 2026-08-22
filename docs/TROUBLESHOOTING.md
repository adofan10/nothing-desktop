# Troubleshooting

Every failure mode actually hit while building this, and what fixed it. Most of
these fail *silently*, which is why they are worth writing down.

---

## Login screen

### The login screen is the stock Breeze one, not Nothing

SDDM does not report theme errors to your face. A single unknown QML property
anywhere in the theme makes it discard the whole thing and quietly load the
embedded fallback greeter. Check:

```bash
journalctl -b -u sddm | grep -i "Fallback to embedded theme"
```

Any hit means the theme was rejected. Validate the installed copy — not your
working copy — before rebooting:

```bash
for f in /usr/share/sddm/themes/Nothing/*.qml; do /usr/lib/qt6/bin/qmllint "$f"; done
```

`install/50-login-screen.sh` runs this automatically and refuses to activate a
theme that fails.

### The login screen renders in the wrong font

SDDM runs as the unprivileged `sddm` user and **cannot read anyone's `$HOME`**.
Fonts in `~/.local/share/fonts` are invisible to it. They must be in
`/usr/local/share/fonts`. Verify as the sddm user itself:

```bash
sudo -u sddm fc-match "NType 82 Mono"
```

If that returns DejaVu or similar, the fonts are not installed system-wide.

### Locked out by a broken theme

Ctrl+Alt+F3 for a TTY, then:

```bash
sudo sed -i 's/^Current=Nothing/Current=breeze/' /etc/sddm.conf.d/kde_settings.conf
sudo systemctl restart sddm
```

---

## Boot splash

### Boot shows the right animation but shutdown shows a different one

`/etc/plymouth/plymouthd.conf`'s `Theme=` **outranks `update-alternatives`
wherever the named theme actually exists.**

The initramfs hook copies `plymouthd.conf` into the initramfs but only copies the
theme directory named by `update-alternatives`. So if `plymouthd.conf` names some
other theme, that theme is *absent* inside the initramfs, plymouth falls through
to `default.plymouth`, and boot shows the right thing purely by accident. At
shutdown plymouthd runs from the real root where the named theme *does* exist —
so shutdown shows the other one.

Fix: name the theme explicitly in both places. `install/60-boot-animation.sh` does.

### The machine hangs at the GRUB menu after a reboot

`update-grub` races `grub2-common.service` and can leave `recordfail=1` in the
GRUB environment. The next boot then waits at the menu forever. Always check
before rebooting:

```bash
grub-editenv /boot/grub/grubenv list | grep recordfail && \
  sudo grub-editenv /boot/grub/grubenv unset recordfail
```

### The animation stutters

Two independent causes: frames rescaled at runtime instead of rendered at display
size, and a frame-advance divisor that dropped frames. `plymouth.script` supports
`Plymouth.SetRefreshRate(30)` — use it, and render the frames at final size with
`make-frames.py` rather than letting plymouth scale them.

---

## Desktop and panels

### A Global Theme wiped my panels and widgets

Applying a Global Theme with **"Use desktop layout from theme"** ticked replaces
the panels *and* every desktop widget. There is no undo in the UI.

```bash
./install.sh 40
```

rebuilds the whole layout. This is the main reason step 4 exists as a standalone
script.

### Desktop widgets won't move, or snap to odd positions

The Folder View containment snaps to a **208 px grid** — widget sizes are
cell-quantised, not free pixels. For pixel-free placement you would have to
switch the containment from `org.kde.plasma.folder` to `org.kde.plasma.desktop`,
which loses desktop icons.

### Widget positions written to the config do nothing

`ItemGeometries-<WxH>` and `ItemGeometriesHorizontal` live **directly under
`[Containments][N]`**, not under `[Containments][N][General]`. Writing them under
`[General]` silently does nothing.

Also: plasmashell rewrites this file from memory. Stop it before editing:

```bash
systemctl --user stop plasma-plasmashell.service
# edit ~/.config/plasma-org.kde.plasma.desktop-appletsrc
systemctl --user start plasma-plasmashell.service
```

### I want to swap one widget but keep its exact position

Change only the `plugin=` line in `[Containments][N][Applets][<id>]` and delete
that applet's stale `[Configuration]` groups, with plasmashell stopped. Positions
are keyed by applet **id**, so the slot survives untouched.

Do *not* use the scripting API's `addWidget()` for this — it allocates a new id
and drops the widget at a default position.

### The panels have no black background

That is Panel Colorizer not loading. Native Plasma has no transparent-panel
option, so the black pill on both panels is drawn by that widget. Its entire
state is one `globalSettings` JSON blob per instance — see `panel-colorizer/`.

---

## Windows and compositing

### Minimising a window leaves it on screen in greyscale

This was a real bug in an early version of the KWin effect here, and the failure
mode generalises to any KWin scripted effect.

A `set()` animation is held until explicitly cancelled, and holding one takes a
visibility reference on the window that **outranks the hide that minimising and
desktop switching rely on**. The window plays its minimise animation, then
reappears in place showing the animated attribute — here, drained to grey.

Fixes, all three needed:

1. Treat `window.minimized` and `window.onCurrentDesktop === false` as
   never-a-candidate.
2. `cancel()` the animation on non-candidates in the refresh loop rather than
   `continue`-ing past them.
3. Watch each window's `minimizedChanged` — there is **no** handler-level
   `windowMinimized` signal on this API (verified on KWin 6.6).

Do not gate on `EffectWindow.visible`: a held animation can force it true, so the
guard would never fire.

Reload an effect without logging out:

```bash
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect nothing-monochrome-inactive
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect   nothing-monochrome-inactive
journalctl --user -b | grep kwin_scripting     # print() output and JS errors land here
```

---

## Applications

### Konsole opens unthemed

Konsole applies the default profile at launch only; existing windows keep theirs.
Set it explicitly and open a new window:

```bash
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile "Nothing.profile"
```

### Snap app icons stay colourful in the dock

Snap launchers hardcode an absolute PNG path
(`/snap/firefox/current/default256.png`), which bypasses the icon theme entirely.
A local override in `~/.local/share/applications/` with a plain `Icon=firefox`
lets the theme's monochrome version win. `install/30-components.sh` writes these.

### Dolphin's Information panel keeps coming back

It is stored in a binary window-state blob, so it is not scriptable. Press **F11**
in Dolphin once and it sticks.

---

## Updates

**A widget-pack update overwrites local patches.** If you patch anything under
`~/.local/share/plasma/plasmoids/com.jaxparrow07.*`, keep a copy — upgrading
replaces the whole package directory.
