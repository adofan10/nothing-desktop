# Engineering log

How each piece of this rice was built, in the order it happened, including the
parts that were wrong the first time. This is the working record, not a guide --
for installation read the [README](../README.md); for failure modes read
[TROUBLESHOOTING.md](TROUBLESHOOTING.md).

Paths are written relative to `~`. Phase numbering is historical.

---

Source: r/unixporn "[KDE] Nothing Laptop (1)" by u/penedeperro (Nobara + Plasma 6).

## Installed
| Piece | Name | Origin |
|---|---|---|
| Global theme | Nothing 1.8 | store.kde.org/p/2116667 (jomada) |
| Plasma style | Nothing 1.5 | store.kde.org/p/2116665 |
| Window decoration | Nothing 1.2 (Aurorae) | store.kde.org/p/2116663 |
| Color scheme | Nothing (#1b1b1d bg, #eb3131 accent) | store.kde.org/p/2116662 |
| Icons | YAMIS 1.5.3 | store.kde.org/p/2303161 (dirn) |
| Cursor | WhiteSur-cursors | store.kde.org/p/1411743 |
| Wallpapers | Nothing1 / Nothing2 / Nothing3 | store.kde.org/p/2116657-9 |
| Widgets (8) | Nothing KDE Widgets 1.2 | github.com/jaxparrow07/nothing-kde-widgets |
| Fonts | NType 82 (UI), NType 82 Mono, Ndot55Caps, Nothing Font (5x7) | bundled with the widget repo |

Fonts live in ~/.local/share/fonts/nothing/

## NOT reproducible
OP's Plasma style and the "dynamic island" plasmoid are custom and unreleased.
As of the thread he says "really really soon" for both — recheck store.kde.org for user `penedeperro`.

## Scripts
- ./revert.sh  — restore the pre-Nothing (Utterly-Nord) desktop from latest.tar.gz
- ./reapply.sh — re-apply the Nothing look

## Optional
- `sudo apt install papirus-icon-theme` — YAMIS inherits Papirus-Dark; without it,
  icons YAMIS lacks fall through to breeze-dark (colourful) instead of staying mono.
- `plasma-apply-lookandfeel -a Nothing --resetLayout` — adopt jomada's panel layout.
  DESTRUCTIVE: replaces your current panel and all its widgets. Run revert.sh to undo.

---

## Phase 2 — full reference match (2026-08-22, later)

### Wallpaper
Nothing2 is the light/grey one from the reference. Extended from 2337x1080 to
3840x2400 by padding with its own field colour (184,184,184) so it doesn't crop:
`~/.local/share/wallpapers/Nothing2/contents/images/3840x2400.png`

### Panels
- **Top panel removed** (user's choice) and replaced with a floating, `lengthMode=fit`,
  **autohide** panel holding only the dynamic island. Cursor to the top edge reveals it.
- **Dock** kept (overview + icontasks), floating, fit, `dodgewindows`, h=56.
- **Panel Colorizer v8** (store id 2130967) is what draws the black pill on BOTH panels
  (native Plasma has no "transparent panel" option). Its settings live in one
  `globalSettings` JSON blob per instance; generated from the shipped "Black" preset with
  bg `#0b0b0c`, alpha 1, radius 17 (island) / 28 (dock), borders + shadows off.
  Both instances have `hideWidget=true` so the colorizer icon itself is invisible.

### Dynamic island — CUSTOM BUILD
`~/.local/share/plasma/plasmoids/com.dev08.nothingdynamicisland/`
OP's island is unreleased, so this is an original implementation, not his.
- `contents/scripts/stats.sh` — one subprocess per 2s emitting cpu/mem/temp/vol/mute/
  bright/net/ntype/bt as `\x1f`-separated key=value. Avoids fragile QML sensor APIs.
- `CompactPill.qml` — LEFT CLUSTER IS THE VIRTUAL-DESKTOP PAGER (GNOME style: current
  desktop = 15px pill, others = 4px dots, clickable, 190ms OutCubic morph).
  Then brightness, clock (the one focal element), volume, battery.
- `ExpandedPanel.qml` — clock+seconds, date, network pill, bluetooth pill, volume slider
  (wpctl), MPRIS media card with waveform, stopwatch, CPU/RAM/brightness bars, caffeine
  toggle (PowerDevil beginSuppressingSleep), lock, DND (NotificationManager.Settings).

### Nothing design rules followed
Sourced from Nothing's published design system:
- greyscale IS the hierarchy (100/90/60/40); **red #d71921 is an interrupt only** —
  it appears solely for battery <=15% off-AC, temp >=80C, active recording, DND on.
- motion is percussive: short OutCubic, staged reveals, **no spring/bounce** (explicitly
  an anti-pattern in their system), no gradients, no shadows.
- one focal element per surface; type carries the hierarchy.

### Dock icons made monochrome
The snap launchers hardcode absolute PNG paths (`/snap/firefox/current/default256.png`),
which bypasses the icon theme entirely. Fixed with local overrides in
`~/.local/share/applications/{firefox_firefox,spotify_spotify}.desktop` setting
`Icon=firefox` / `Icon=spotify` so YAMIS's monochrome versions win.
Dolphin + Konsole already resolved through the theme.

### Desktop widgets
Positions live in `[Containments][200]` -> `ItemGeometries-1786x1116` and
`ItemGeometriesHorizontal`, format `Applet-<id>:x,y,w,h,0;`  (NOT under [General] —
writing there does nothing). The Folder View containment **snaps to a 208px grid**, so
sizes are cell-quantised. For pixel-free placement the containment would have to be
switched from `org.kde.plasma.folder` to `org.kde.plasma.desktop` (loses desktop icons).

### Local patch to a third-party widget
`com.jaxparrow07.nothingkdewidgets.digitalclock` hardcodes 12-hour AM/PM in
`getTimeInTimezone()`, ignoring `use24HourFormat`, for the wide-pill (world clock)
variant. Patched locally to honour it. **A widget update will overwrite this.**
Original saved as `contents/ui/main.qml.orig-backup`.

### Known gaps / your call
- Weather location is **Villupuram** — that is the widget's own default (OP's city).
  Change it in the weather widget's settings.
- Dolphin's Information panel is stored in a binary window-state blob, so it is not
  scriptable: press **F11** in Dolphin once and it sticks.
- The island's "stopwatch" tile is a stopwatch; OP's equivalent tile said "GRABACIÓN"
  and its actual function is unknown.
- Island labels are English (OP's were Spanish).

---

## Phase 3 — size, visibility, motion, terminal

### Island size
Panel height 34 -> **48**; pill height 26 -> **38**; clock 13 -> 19px, labels 10 -> 14px,
pager pill 15x4 -> 22x6. Expanded panel scaled x1.30 (384x288 -> 499x374) by a scripted
numeric pass over `font.pixelSize`, Layout/implicit sizes, radii, spacing and margins.

### Visibility
Island panel is now `hiding = "none"` (always visible). It still disappears under genuine
fullscreen windows because Plasma panels are always covered by fullscreen clients — which
is exactly the requested behaviour. As a side effect it reserves a 48px strut at the top,
so maximised windows sit below it (matching the reference screenshots).
Dock stays `dodgewindows`.

### Show/hide animation
The black pill is now drawn by **the widget itself**, not Panel Colorizer, so its geometry
is animatable. The island panel's Colorizer instance is set to
`panel.normal.backgroundColor.alpha = 0` **and** `nativePanel.background.enabled = false`
-- that second key is the one that actually hides Plasma's own panel background; alpha
alone just exposes it.

Reveal is a ParallelAnimation: the capsule widens from 0.22 -> 1.0 over 380ms OutCubic
while the contents stagger in 90ms later, and the pager dots tick in 55ms apart.
`onVisibleChanged` resets `grow`/`reveal` so it replays on every reappearance.

**Limitation:** the panel *slide* itself is Plasma's own shell animation and cannot be
replaced from a widget. Colorizer's `animatePropertyChanges=true` / `animationDuration=300`
is enabled on both panels for its own transitions. The dock is stock icontasks, so its
show/hide is whatever the shell does.

### Terminal — Konsole
- `~/.local/share/konsole/Nothing.colorscheme` — bg #0b0b0c, fg #f2f2f2, greyscale ANSI
  ramp, **red #d71921 as the only saturated colour**; green/amber/blue/magenta/cyan are
  deliberately muted (Nothing's system permits status colours for encoding data, but
  nothing else).
- `~/.local/share/konsole/Nothing.profile` — **NType 82 Mono 11pt** (verified true
  monospace, fontconfig spacing=100 — it is Nothing's own mono face), 16px margin,
  block cursor in Nothing red, scrollbar hidden, no blinking cursor.
- `konsolerc` — Nothing.profile is default, menubar off, tab bar always hidden.

Existing Konsole windows keep their old profile; **new windows** get Nothing. To convert a
running window: Settings > Switch Profile > Nothing.

---

## Phase 4 — global-theme reset, and two island fixes

### !! DO NOT RE-APPLY THE "Nothing" GLOBAL THEME !!
Applying it from System Settings runs the theme's own
`contents/layouts/org.kde.plasma.desktop-layout.js`, which **wipes every panel and every
desktop widget** and replaces them with jomada's stock layout. It also resets icons to
breeze-dark. It does NOT touch the installed plasmoids, themes, fonts or wallpapers —
only the arrangement.

The whole look was already applied component-by-component back in phase 1, so the global
theme entry adds nothing and only destroys the layout. Leave it alone.

**If it happens again — one command:**

    ~/nothing-rice-backup/rebuild-layout.sh

It restores icons + fonts + wallpaper, removes whatever panels exist, recreates the island
panel and the dock (with their Panel Colorizer instances and saved presets from
`assets/`), re-adds all seven desktop widgets with their configs, and re-pins the grid
geometry. Applet IDs are captured at runtime, so it works no matter what numbers Plasma
assigns.

### Island popup no longer sits in a box
`fullRepresentation` makes Plasma wrap the content in its own dialog frame, so the panel's
rounded corners were visible *inside* a square container. Replaced with a
`PlasmaCore.Dialog` (`org.kde.plasma.core/Dialog`) using
`backgroundHints: PlasmaCore.Types.NoBackground` — the rounded panel now IS the popup.
`CompactPill` registers itself as `island.anchorItem` on completion so the dialog anchors
under the pill; clicking the pill calls `island.togglePanel(pill)`.

### Island hiding
`hiding = "none"` does **not** get covered by fullscreen windows — it just stays pinned.
Changed to **`dodgewindows`**, same as the dock: visible over the desktop, hidden as soon
as a window occupies that space. This is the behaviour that was actually wanted.

---

## Phase 5 — Nothing design-system audit

Skills installed via `npx skills`:
- `dominikmartn/nothing-design-skill@nothing-design` (504 installs) — the Nothing design
  system itself: tokens, craft rules, anti-patterns. This is the authority used below.
- `julianoczkowski/designer-skills@design-review` (4.7K installs) — general critique.

Rejected the top "ui ux design audit" hits (max 449 installs, most <150) — the find-skills
skill's own bar is 1K+ installs, and none of them were on-domain.

### Findings and fixes

| # | Rule | Was | Now |
|---|------|-----|-----|
| 1 | Exact token greys, pure neutral | `#0b0b0c` / `#1b1b1d` / `#242426` / `#87878b` — all **blue-tinted**, matched no token | `#000000` `--black`, `#111111` `--surface`, `#1a1a1a` `--surface-raised`, `#999999` `--text-secondary`, `#666666` `--text-disabled`, `#333333` `--border-visible`, `#e8e8e8` `--text-primary` |
| 2 | Max 3 font sizes per surface | **7 sizes** (9,10,12,13,17,20,35) | **3** — display 35 / body 13 / caption 10 |
| 3 | Tertiary labels = mono ALL CAPS | proportional NType 82 | **NType 82 Mono**, ALL CAPS, letter-spaced (7 labels) |
| 4 | Cards radius <= 16 | media card at 18.2 | 16. Pills/circles rewritten as `radius: height / 2` so they are true pills by construction |
| 5 | "Prefer opacity over position — elements fade, don't slide" | **5 `Translate` y-slides** + a pill width-grow | all removed; **opacity-only** reveal |
| 6 | Easing `cubic-bezier(0.25,0.1,0.25,1)` | `Easing.OutCubic` (approximation) | `Easing.Bezier` with the exact curve |
| 7 | Status colours | terminal green `#8f9e8a`, amber `#c9a227` (invented) | `--success #4A9E5C`, `--warning #D4A843`, `--interactive #5B9BF6`; terminal bg to true `#000000`, fg `#E8E8E8` |

Panel also grew 500x404 — the content genuinely totalled ~398px and was being clipped at
the bottom, which the audit surfaced.

### Deliberately NOT "fixed"
- Outer island shell keeps radius 28.6. The <=16 rule is written for *cards*; the island
  is a pill-family surface and Nothing's own island is heavily rounded.
- Desktop widgets stay dark-on-light. That is a mode mix, but it is exactly what the
  reference rice does, and the reference is the brief.
- Red is absent from the island at rest. That is correct, not a bug: "if nothing is
  urgent, no red on the screen."

Pre-audit QML copies: `~/nothing-rice-backup/assets/qml-preaudit/`

---

## Phase 6 — island invisible: root cause

**Symptom:** the island pill did not render at all. The panel reserved its 48px strut, but
the pill was absent. No QML errors anywhere; `plasmawindowed` loaded the package cleanly.

**Diagnosis:** `applet.geometry` reported **42x42** — a square the thickness of the panel,
i.e. Plasma's *placeholder icon*, not the compact representation. Hardcoding
`Layout.preferredWidth: 380` changed nothing, which proved Plasma was ignoring the compact
representation entirely rather than mis-sizing it.

**Cause:** when the frameless-popup change removed `fullRepresentation` (phase 4), it left
the applet with `preferredRepresentation: compactRepresentation` and **no full
representation at all**. Plasma treats compact/full as a pair; with only a compact one
declared it discards it and falls back to the placeholder. The regression therefore came
from the popup change, not from the design audit — the audit merely happened in between,
and the pill was never visually re-checked after phase 4 because a maximised window was
hiding the panel in every screenshot.

**Fix:** declare a 1x1 stub full representation. We never set `expanded`, so it never
opens; the custom `PlasmaCore.Dialog` still provides the real popup.

    compactRepresentation: CompactPill { island: root }
    fullRepresentation: Item { implicitWidth: 1; implicitHeight: 1 }

Applet geometry then reports 413x42 and the pill renders.

Also hardened `pillW` against NaN: `Math.max(170, (row.implicitWidth || 0) + 38)` --
`undefined + 38` is NaN, and a NaN Layout hint silently degrades to the placeholder too.

### Visibility setting changed back to "none"
`dodgewindows` hides the panel for **any** overlapping window, including merely *maximised*
ones — and since there is usually something maximised, the island was effectively never
visible. Now `hiding = "none"`: always visible, reserving a 48px strut so maximised windows
sit below it (as in the reference screenshots). Genuine fullscreen clients still cover it.
If you would rather it float *over* windows without reserving space, the alternative is
`windowsgobelow`.

---

## Phase 7 — iOS-style motion, hiding, alignment

### Hiding: back to dodgewindows
Phase 6 set `hiding = "none"` on the theory that dodgewindows was hiding the island too
eagerly. That was a **misdiagnosis** — the island was invisible because of the 42x42
placeholder bug, not the hiding mode. With the pill actually rendering, `dodgewindows`
behaves correctly: visible on the desktop, hidden when a window occupies that space,
exactly like the dock. Restored, and the rebuild script updated to match.

The "island moves slightly upward when a window opens" symptom was Plasma's *floating*
panel de-floating (snapping flush to the edge) under `none`. Under `dodgewindows` it hides
instead, which is what was wanted.

### iOS-style entrance on the island
`CompactPill` now animates on every reappearance:
- `opacity: pill.reveal`  and  `scale: 0.94 + 0.06 * pill.reveal`
- 300ms on iOS's "smooth" deceleration curve `cubic-bezier(0.32, 0.72, 0, 1)`

No overshoot, so it reads like the iOS volume HUD while still honouring Nothing's
explicit "no spring/bounce easing" rule. Note this does reintroduce a small *transform*
animation, which Nothing's "prefer opacity over position" guidance discourages — a
deliberate, user-requested trade-off, kept subtle (6%) for that reason.

**Limitation:** only the *entrance* is ours. The panel slide itself, and the exit, are
Plasma's shell animation (`PanelView`) and cannot be overridden from a widget.
The dock is a stock `icontasks` applet, so its show/hide is entirely Plasma's — there is
no hook to animate another applet's content.

### Widget alignment
Plasma had re-snapped widgets badly after the rebuild: 302 sat at `x=0`, 303 at `y=0`
(wrong row entirely), 306 off the 208 grid, and the two wide widgets ended at 416 while
the row above ended at 480. Re-pinned to a clean grid — every left-column widget now spans
`x=64` to `right=480`, rows on the 208 pitch, big clock at `688,80` aligned with row 1.

### Also
- Restored `com.himdek.kde.plasma.overview` to the dock; the phase-4 rebuild script had
  dropped it. Script updated so it is not lost again.
- Fixed a QML deprecation in `CompactPill`: a bare `text` inside `onTextChanged` picks up
  the injected signal parameter; qualified it as `clock.text`.

### skills.sh registry
`npx skills find` returned empty for every query at this point, including a control search
for "react" that had worked earlier in the session — a transient backend issue, not a bad
query. The already-installed `nothing-design` skill supplied the motion tokens.

---

## Phase 8 — Konsole opened unthemed

**Symptom:** launching Konsole normally gave the old translucent Nord look, even though
`DefaultProfile=Nothing.profile` was set and a `konsole --profile Nothing` test looked right.

**Diagnosis:**
- `konsole --separate` (its own process) -> correctly Nothing-themed.
- `konsole` (plain, no flags)            -> old Nord profile.

That difference is the whole answer. `konsolerc` had **`UseSingleInstance=true`**, so a
plain launch is served by the *already-running* Konsole process. That process started at
22:14, **before** the Nothing profile was written at 23:23, and it still held the old
default profile in memory. Every "new" window it spawned inherited Nord.

The earlier verification was misleading because it used `--profile Nothing`, which bypasses
the default-profile lookup entirely — it proved the profile was valid, not that it would
actually be used.

**Fix:** `kwriteconfig6 --file konsolerc --group KonsoleWindow --key UseSingleInstance false`

Each launch now starts its own process and re-reads the config, so the Nothing profile is
picked up regardless of what is already running. Verified with a plain flagless `konsole`.

**Note:** a terminal window that was already open keeps its old profile, and new *tabs*
opened from inside it still come from that old process. Close it once, or use
Settings > Switch Profile > Nothing, and everything after that is themed.

---

## Phase 9 — Nothing lock screen + login screen

### Lock screen — DONE and ACTIVE
In Plasma 6 the lock screen lives in the **shell package**, not the look-and-feel package
(`look-and-feel/*/contents/lockscreen/` no longer exists). So:

`~/.local/share/plasma/shells/org.kde.nothing.desktop/` — a copy of the stock shell package
with only `contents/lockscreen/` changed. Activated with:

    kwriteconfig6 --file plasmarc --group Shell --key ShellPackage org.kde.nothing.desktop

New files: `NothingClock.qml` (self-contained, no singleton import so the same file drops
into the SDDM theme), `NothingTokens.qml` (singleton, registered in the local `qmldir`).

Changes to stock files — `LockScreenUi.qml`, `MainBlock.qml`. Stock copies kept alongside
as `*.stock`. `LockScreen.qml` was deliberately **not** touched: it declares the "magical
properties" kscreenlocker looks for (`viewVisible`, `suspendToRam`…), and breaking it
breaks unlocking.

Gotchas hit:
- `WallpaperFader` dereferences `clock.shadow.opacity`, so the `DropShadow` object must
  stay — set `visible: false` rather than deleting it.
- The scrim at `z: 1` painted **over** the clock and greyed it out; content needs `z: 5`.
- A `background: Item { implicitHeight: … }` on a TextField causes a binding loop —
  TextField derives its own implicitHeight from the background.
- The lock wallpaper was a JPEG in `~/Downloads`; white digits on a white wallpaper are
  invisible. Now `Nothing1` + a flat 55% black scrim.

### Login screen — BUILT AND TESTED, needs one sudo step
Staged at `~/nothing-rice-backup/sddm-Nothing/` (a fork of the Breeze SDDM theme, which
KDE keeps structurally in sync with the lock screen — the same patches applied).

**Not installed yet.** Run:

    sudo ~/nothing-rice-backup/install-login-theme.sh

That installs the fonts system-wide, copies the theme, **verifies the `sddm` user can
resolve the fonts**, and flips `Current=Nothing`.

The font step is not optional: SDDM runs as the `sddm` user, which cannot read
`~/.local/share/fonts`. The windowed test looks correct only because it runs as your own user.
Same reason the wallpaper is bundled *inside* the theme rather than referenced from `$HOME`.

### Design applied to both
Three layers: dot-matrix clock (primary), mono ALL-CAPS date (secondary), power/battery/
keyboard labels (tertiary). No avatar — a photo or a blue Kubuntu logo fights a monochrome
system and Nothing bans multi-colour icons. Inputs are a single rule drawn from the centre,
not a box. Red appears only on failed auth.

### Recovery
`~/nothing-rice-backup/RECOVERY.md` — written *before* anything was activated, with TTY
commands for both surfaces.

### Phase 9b — post-install verification
Install verified: theme at `/usr/share/sddm/themes/Nothing` (root-owned, a+rX), fonts at
`/usr/local/share/fonts/nothing` (644, all parents traversable, 6 faces registered by
fontconfig), wallpaper bundled inside the theme, `Current=Nothing` in `kde_settings.conf`
(which sorts last in `/etc/sddm.conf.d/`, so it wins over `20-kubuntu.conf`).

GRUB checked before recommending a reboot: `grubenv` has **no `recordfail=1`** and no
systemd units failed — the boot-hang condition from the earlier session is not present.

One cosmetic defect found by testing the *installed* copy rather than the staging copy:
an earlier sed had injected `placeholderTextColor` into two `Rectangle` blocks inside the
field backgrounds, where the property does not exist. Harmless (QML ignores it, the greeter
renders correctly) but it logs an error twice. Fixed in staging; sync with:

    sudo cp ~/nothing-rice-backup/sddm-Nothing/Login.qml /usr/share/sddm/themes/Nothing/

Remaining known log line: `Main.qml:400 Unable to assign [undefined] to QUrl` — the logo
path, which is undefined because `showlogo=hidden`. Stock-theme behaviour, no visual effect.

## Phase 10 — login screen fallback + boot/shutdown animation (2026-08-23)

### Correction to Phase 9b
Phase 9b called the stray `placeholderTextColor` **"harmless (QML ignores it, the greeter
renders correctly)"**. That was wrong, and it is why the first reboot showed the *stock*
login screen. QML does **not** ignore an unknown property: assigning one to a `Rectangle`
fails the whole component, so `Login.qml` never compiles, `Main.qml:181` cannot instantiate
`Login`, and SDDM prints:

    Main.qml:181:26: Type Login unavailable
    Login.qml:98:9: Cannot assign to non-existent property "placeholderTextColor"
    Fallback to embedded theme

**`Fallback to embedded theme` is the line to grep for.** SDDM does not fail loudly — it
quietly swaps in its built-in greeter, so the theme looks "not applied" rather than broken.
The staged fix from Phase 9b was correct but was **never copied to `/usr/share`** before the
reboot, so the broken copy booted.

Lesson: always validate the **installed** copy, headless, before rebooting:

    QT_QPA_PLATFORM=offscreen sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/Nothing 2>&1 \
      | grep -iE "fallback|unavailable|non-existent"

Silence there means the theme really loads. This needs no root and no VT switch.

Also: only the two occurrences nested inside `Rectangle` blocks were invalid. Both
`PlasmaComponents3.TextField` and `PlasmaExtras.PasswordField` **do** accept
`placeholderTextColor` (Qt 6), so it was restored on the password field — verified by test,
not assumed. The `Main.qml:400 Unable to assign [undefined] to QUrl` line is gone too:
`showlogo=hidden` left `config.logo` undefined, fixed by adding `logo=default-logo.svg`
to `theme.conf` (logo stays hidden).

### Boot + shutdown animation
Theme `nothing` at `/usr/share/plymouth/themes/nothing`, frames from **hexagon_dots** by
Aditya Shakya (@adi1090x, MIT) — white dot-matrix on black, the closest match to the Ndot
language. Staged in `~/nothing-rice-backup/plymouth-nothing/`.

- **HiDPI is the real gotcha.** adi1090x frames are an 800x600 canvas holding a ~200px
  cluster. Drawn 1:1 on this 3840x2400 panel that is ~5% of screen width — a speck.
  `nothing.script` scales frames at startup (`Image.Scale`, factor `screen.w / 1400`,
  clamped 1x–4x) so the cluster lands at ~14% of width. Scale **once outside** the refresh
  callback; rescaling per frame is expensive.
- One theme covers **both** boot and shutdown — `plymouth-poweroff/reboot/halt.service` are
  `static` and reuse the default theme. There is no separate shutdown setting.
- `plymouth-set-default-theme` **does not exist** on Kubuntu. Use `update-alternatives`
  (link `/usr/share/plymouth/themes/default.plymouth`, slave `default.grub`), then
  `update-initramfs -u`. `--set` also pins it to `manual` so upgrades cannot steal it back.
- The `.grub` slave only affects the GRUB menu on the next `update-grub`, which was
  deliberately **not** run — the menu is hidden here and it risks the `recordfail` race.

Rollback: `sudo update-alternatives --set default.plymouth \
/usr/share/plymouth/themes/kubuntu-logo/kubuntu-logo.plymouth && sudo update-initramfs -u`

---

## Phase 11 — fluid boot animation, and the 80% battery cap removed

### The animation was stuttering for two independent reasons

**1. The 32 frames were never a loop.** Measured mean |delta| against the previous
frame across the hexagon_dots sequence:

| frames | mean delta | what it is |
|---|---|---|
| 0–16 | 3.2 – 8.9 | a single outward ping |
| 17–29 | 2.3 → 0.04 | dying out |
| 30, 31 | **0.00** | frozen, byte-identical |
| 31 → 0 | **8.9** | the largest jump in the whole sequence |

So it played a ~0.6 s ripple, froze for ~0.6 s, then hard-cut back to the start.
adi1090x frame sets are one-shot animations, not loops — Phase 9 treated it as one.

**2. Every frame was a 14 MB blit.** `screen.w / 1400` = 2.743 on this panel, so all
32 frames were inflated 800x600 → 2194x1645 and held decoded: **441 MB resident**, and
14.4 MB of unaccelerated memcpy per displayed frame in early KMS.

### Fix: regenerate the frames instead of rescaling them

The lattice was recovered from the original PNGs by least-squares fit — **hex, 5 rings,
91 dots (3n²+3n+1), pitch 22.24 px, centre (400, 289.5), residual 0.012 px/dot**, and the
resting radius per ring measured as `[3.58, 4.46, 4.50, 3.55, 2.03, 1.53]` source px.
`plymouth-nothing/make-frames.py` re-renders that lattice at final display scale with a
continuous radial wave: each ring's radius is a cosine of time, phase-offset by one full
wavelength across the 5 rings, so **frame 59 → frame 0 is exact by construction**.

- 60 frames, 566x646, `Plymouth.SetRefreshRate(30)` → one 2.0 s ripple.
- Verified seamless: wrap delta 0.480 sits mid-range (0.467–0.646, spread 1.38x), and no
  adjacent pair is identical. Compare the old sequence: 0.00 to 8.9.
- Rendered at 1:1 for a 3840-wide panel, so the scaling path is skipped entirely.
  **441 MB → 84 MB resident, 14.4 MB → 1.45 MB per frame.** Also sharper: the dots are
  drawn at output resolution instead of upscaled 2.7x from an 800px source.
- `make-frames.py` reproduces the staged frames byte-for-byte; re-run it to retune.

### `Plymouth.SetRefreshRate` exists — use it

Confirmed in this build (`script.so`): `SetRefreshRate(n)` stores `(int)n` and the plugin
schedules its next tick at `1.0 / n` seconds. Pinning it makes the tempo independent of
the plugin's compiled-in default, so frame count and playback speed stay coupled.

### Phase 9 was wrong about shutdown

It claimed "one theme covers both boot and shutdown — there is no separate setting."
There is: `/etc/plymouth/plymouthd.conf` had `Theme=breeze-text`, dated 2026-07-02.

- The initramfs hook (`/usr/share/initramfs-tools/hooks/plymouth`, line ~176) **copies
  that file into the initramfs**, but only copies the theme directory named by
  `update-alternatives`. So inside the initramfs `breeze-text` does not exist, plymouth
  logs "Theme breeze-text not found" and falls through to `default.plymouth` → `nothing`.
  **Boot showed the right theme purely by accident.**
- At shutdown plymouthd runs from the real root, where `breeze-text` *does* exist — so
  shutdown was showing the Breeze text splash all along, not the dot matrix.
- Fixed by setting `Theme=nothing` in `plymouthd.conf`. `update-alternatives` alone is
  not sufficient; `plymouthd.conf` outranks it wherever the named theme is present.


### Clock pill replaced with Quote of the Day

Applet **304** in containment 265 (the 416x208 stadium in the left widget grid, which
was `nothingkdewidgets.digitalclock` on `widgetVariant=1`) is now
`com.dev08.nothingquote`. The big centre clock (applet 306) is untouched.

- Package: `~/.local/share/plasma/plasmoids/com.dev08.nothingquote/`. Fonts,
  `NothingColors.qml` and `icon.png` are copies from the `nothingkdewidgets.date`
  package, so the palette tracks the rest of the grid (`background` #1a1a1a at
  `opacity: 0.95`, accent #ff4444 — measured on screen as #222222 over the
  #b8b8b8 wallpaper).
- Shape is `radius: height / 2` — a **stadium**, deliberately, so the grid row keeps the
  silhouette the clock gave it. That costs horizontal room: text is inset by
  `min(h*0.36, w*0.2)` on each side, leaving ~261 logical px. Quotes are capped at ~95
  characters for that reason; `fontSizeMode: Text.Fit` shrinks the rest. The 94-char
  worst case renders as 4 legible lines with the author line intact.
- 65 quotes in `contents/ui/quotes.js`, picked by local day number
  (`Date.UTC(y,m,d)/86400000` — dividing `Date.now()` would roll over at 05:30 IST).
  Clicking steps through the set; midnight resets to the day's own quote.

**Swapping a desktop widget in place:** stop `plasma-plasmashell.service`, change the
`plugin=` line of the applet group and delete its stale `[Configuration]` groups, then
start the service. The `ItemGeometries*` keys reference `Applet-304` by id, so position
and size survive untouched — `addWidget()` via the scripting API would not have.
Old layout: `~/nothing-rice-backup/appletsrc.pre-quote-20260823-021051`.

**Mapping screenshots to widget coordinates:** logical→physical is x2.1538 (3840/1783),
and the desktop containment starts **~63 logical px below y=0** because the dynamic
island panel offsets it. Forgetting that offset crops the wrong region.

---

# Phase 12–14 — connectivity sheets, lyrics, app drawer, gestures, and an audit

## The island grows instead of opening windows

The network and Bluetooth cards used to launch a KCM. Now they turn the pill into a
picker, and a third sheet turns the media card into a full now-playing screen.

**Wi-Fi** goes through `PlasmaNM.Handler` from `org.kde.plasma.networkmanagement` —
the same object plasma-nm's own applet uses, so saved profiles, the kded secret
agent and enterprise networks keep working:

- `addAndActivateConnection(devicePath, specificPath, password)` — inline join
- `activateConnection(connectionPath, devicePath, specificPath)` — a network that
  already has a `Uuid`

`NetworkModel`'s role names are the `ItemRole` enum minus "Role": `Name`, `Ssid`,
`Signal`, `SecurityType`, `ConnectionState`, `DevicePath`, `SpecificPath`, `Uuid`,
`Type`.

The password screen is a **second state of the sheet**, not an inline row.
`AppletProxyModel` re-sorts live on signal strength, so a row that sprouted a
password field would wander off under the cursor.

**Bluetooth** uses `org.kde.bluezqt`. `Device::pair()` is **not exposed to QML** —
only `connectToDevice()` / `disconnectFromDevice()`. Pairing therefore calls
`org.bluez.Device1.Pair` over `busctl`. Deliberately not `bluetoothctl`: that
registers a *competing* agent and steals the PIN prompt from bluedevil.

## The stutter, and why the popup window must not resize

First cut animated the popup's `implicitHeight` between sheet sizes. That
renegotiates the Wayland surface every frame and visibly stutters.

The popup window is now a fixed 500×660 and never resizes. Only the black
`Rectangle` inside it animates its height, which is pure scene-graph work. Because
`backgroundHints: NoBackground`, the leftover area is transparent — so it gets a
dismiss `MouseArea`, and the pill gets one of its own to swallow clicks.

## Lyrics

Source is [LRCLIB](https://lrclib.net) — open, no key, and it serves LRC timestamps
rather than plain text, which is what makes the lines move.

`/api/get` wants an exact album+duration match and 404s for most tracks, because
the album string MPRIS reports rarely matches to the character. A miss falls through
to `/api/search`, scoring hits by "has syncedLyrics" first, then closest running time.

**Slowed and sped-up edits** are the same words at another tempo, so the original's
stamps run early or late by exactly the length ratio. `_timeScale()` rescales when
the ratio is outside 0.97–1.03 but inside 0.6–1.7. Without it every "(SLOWED)" track
scrolls visibly out of time.

Two things that look like details and are not:

- **Emphasis is colour and `scale`, never `font.pixelSize`.** A size change moves
  `implicitHeight`, which reflows the whole ListView on every line and makes the
  scroll jump. `scale` with `transformOrigin: Item.Left` costs no layout at all.
- MPRIS reports position once a second, far too coarse to land a line on the beat.
  `main.qml` extrapolates at 10 Hz and re-anchors on every real `positionChanged`.

Scrolling is `ListView.StrictlyEnforceRange` with `preferredHighlightBegin ==
preferredHighlightEnd == height * 0.34`: the playing line is pinned a third of the
way down and the list slides under it.

The cover bleeds past the layout's content inset with `Layout.rightMargin: -16.9`
— negative layout margins do work — and a horizontal `Gradient` scrim takes it from
`#ff000000` at the left to `#00000000` at the right. Painting a scrim beats fading
the image: identical on a black pill, and no shader.

## App drawer

`X-Plasma-Provides: ["org.kde.plasma.launchermenu"]` is the whole trick for the Meta
key. `activate application launcher=Meta` was **already** in `kglobalshortcutsrc`;
it simply had no applet claiming it. No shortcut was changed.

Plasma expands the stub `fullRepresentation` on that shortcut, so `main.qml`
intercepts `onExpandedChanged`, sets `expanded = false`, and opens its own window.

That window is **`Kicker.DashboardWindow`** — the primitive KDE's own Application
Dashboard uses. Full screen on the visualParent's screen,
`KWindowEffects::enableBlurBehind`, and a `keyEventProxy` so every keystroke lands
in the search field. Far more reliable than making a `PlasmaCore.Dialog` go
fullscreen on Wayland.

Its `visible` must be **assigned, not bound**: DashboardWindow hides itself in C++
on focus loss, which would tear down a binding permanently.

Paging is `flow: GridView.FlowTopToBottom` with `cellWidth`/`cellHeight` dividing
the viewport exactly, so one viewport width is exactly one page and snapping is
`Math.round(contentX / width)`.

**First-open layout bug:** the compositor sizes the window a frame *after* it is
shown, so the first layout ran against a zero-width grid and the tiles came out
garbled until a model change forced a relayout — typing "fixed" it. Cured with a
zero-interval `forceLayout()` and a relayout on `onWidthChanged`.

Open and close are two flags — `drawerOpen` (intent) and `drawerMapped` (window on
screen) — so the window survives its own exit animation; `AppDrawer` calls
`finishClose()` from a `ScriptAction` at the end.

## Three-finger window gestures

**KWin cannot bind a touchpad swipe from a script.**
`EffectsHandler::registerTouchpadSwipeShortcut()` is present in `libkwin.so.6`, but
the JS API exposes only `registerShortcut`, `registerScreenEdge`,
`registerRealtimeScreenEdge` and `registerTouchScreenEdge` — for scripts *and* for
`ScriptedEffect`. Nothing gesture-related on KWin's D-Bus, and Plasma 6.6 ships no
gestures KCM (only `kcm_touchpad` and `kcm_kwintouchscreen`).

So: a KWin script registers two global shortcuts with **no default key** (anything
in the Meta+Shift range risks colliding with a stock binding), and
`nothing-gestures` reads `libinput debug-events` and invokes them via
`qdbus6 org.kde.kglobalaccel /component/kwin ...invokeShortcut <name>`.

- **Resolve the successor before minimising.** KWin refocuses on its own the moment
  the active window goes away; read `stackingOrder` after and "next" is wrong.
- **Calibrate, do not guess.** The first threshold was 40 libinput units, which
  would have ignored *every* real swipe — measured swipes accumulate 4.6–15.0.
  `nothing-gestures --calibrate` prints per-swipe totals and changes nothing.
- The axis-ratio test (vertical must beat horizontal by 1.5×) is what keeps this
  clear of KWin's own three-finger left/right desktop switching.
- `grep --line-buffered` filters the libinput stream in C before bash sees it;
  without it the loop parses every POINTER_MOTION line the touchpad emits.

**KWin scripts have `callDBus(service, path, interface, method, args...)`** — that
is how the script puts its OSD up, via
`org.kde.plasmashell /org/kde/osdService showText`. It lives in the script rather
than the daemon so it fires on every path in: touchpad, key binding, or D-Bus.

Two development gotchas that cost real time:

- **`reconfigure` does not reload a KWin script.** Use `/Scripting unloadScript
  <name>`, then `loadScript <path> <name>`, then `start` — otherwise edits appear to
  do nothing while the old copy keeps running.
- Script `print()` / `console.log` is filtered out of the journal. **`console.warn`
  shows up**, as `js:` under the kwin_wayland unit.

## Widget reload on network-up

Several widgets fetch exactly once from `Component.onCompleted` — the weather widget
geocodes once, at `main.qml:426` — and plasmashell is up seconds before Wi-Fi
associates at login, so they stay empty until something restarts the shell.

There is **no per-applet reload** in Plasma's scripting API and no D-Bus call for
one, so "reload" is `systemctl --user restart plasma-plasmashell.service`. Nothing
is lost: applet config is already on disk.

Online is read as a **number** off NetworkManager's D-Bus properties
(`Connectivity == 4`, or `State >= 70` when connectivity checking is off) — never
from `nmcli` text, which is translated.

`gdbus monitor` feeds the loop over **fd 3 via process substitution**, not a pipe:
`cmd | while` forks a second bash and strands the state variables in a subshell.
`read -t` doubles as the fallback tick; rc > 128 is the timeout, any other non-zero
is EOF and exits so systemd restarts it.

## Performance audit

Measured, not guessed. `stats.sh` was the whole story.

| what | cost |
|---|---|
| old — everything, every 2 s | 88.7 ms/call = **4.44 % of a core, always** |
| new `lite` — closed, every 3 s | 28.3 ms/call = **0.94 % of a core** |
| new `full` — only while open, 2 s | 88.7 ms/call, only when something reads it |

Per command: `nmcli` 22 ms, `wpctl` 15 ms, `bluetoothctl` 10 ms, `busctl` 6 ms. The
pill draws only volume, brightness, battery and the clock, so `lite` does `wpctl`
plus two sysfs reads. Verified by timeline sampling across an open/close cycle:
`full` while open, `lite` while closed, **never both** — a changed
`connectedSources` does disconnect the old source.

Everything else that was awake with nothing to show:

- `PlasmaNM.*` and `BluezQt.*` moved out of `main.qml` into the sheets.
  `NetworkModel` subscribes to every AP's signal-strength updates, and
  `BluezQt.Manager` starts a BlueZ client the instant it is *referenced*.
- **`ExpandedPanel` is built at applet load and never destroyed**, so its infinite
  waveform animation looped at 60 fps behind a closed popup for as long as anything
  was playing. `running:` now also requires `panelOpen`.
- MPRIS `updatePosition()` polling gated on `panelOpen`.
- Lyrics cache bounded to 24 entries, FIFO.
- The drawer drops its GridView model when unmapped, freeing app-icon pixmaps that
  were resident from login onwards.

No leak: plasmashell RSS flat at 339–340 MiB across a 60 s idle sample.

**Do not import `org.kde.plasma.private.volume` or
`org.kde.plasma.private.brightnesscontrolplugin`** to replace the polling. Doing so
kills the applet outright and Plasma logs **nothing at all** — no import error, no
QML error, the applet simply never appears. Diagnose a vanished applet by checking
whether its side effects still run (`pgrep -f scripts/stats.sh`), not by looking for
an error.

Two pre-existing CPU sinks found and left alone, both third-party: a
`font.pixelSize` **binding loop** in jaxparrow07's digitalclocklarge
(`main.qml:116`) and a recursive Layout rearrange in its weather widget.
