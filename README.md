<div align="center">

# N O T H I N G

**A Nothing OS desktop for KDE Plasma 6 — dot matrix, greyscale, one red interrupt.**

Built and daily-driven on Kubuntu · Plasma 6.6 · Wayland

<img src="docs/images/desktop.png" width="100%" alt="The full Nothing desktop: floating dynamic island, widget grid, dot-matrix clock, floating dock">

</div>

---

Most "Nothing" ports stop at a dark colour scheme. This one goes end to end — the
boot splash, the login screen, the login *fonts*, the panels, the widget grid and
the window compositing all follow the same rules, so there is no moment during
startup where the illusion breaks.

Everything here is scripted and reversible. `./install.sh` on a fresh Kubuntu box
gets you the screenshot above.

<table>
<tr>
<td width="50%" valign="top">

### The dynamic island
<img src="docs/images/island.png" width="100%">

A floating top panel that is only as wide as its contents. The left cluster is a
**virtual desktop pager** — current desktop is a pill, the others are dots. Then
brightness, clock, volume, battery. Click it and it expands into a full control
surface: media with a waveform, network and bluetooth pills, a volume slider,
CPU/RAM bars, caffeine, DND, and a stopwatch.

</td>
<td width="50%" valign="top">

### The widget grid
<img src="docs/images/widgets.png" width="72%">

Date, battery, weather, quote of the day, and now-playing — laid out on a strict
208 px grid. The big dot-matrix clock sits to the right of it as the one focal
element of the surface.

</td>
</tr>
<tr>
<td colspan="2">

### Quote of the day
<img src="docs/images/quote.png" width="52%">

</td>
</tr>
</table>

---

## What you get

| Layer | What it is | Where it comes from |
|---|---|---|
| Boot + shutdown splash | 60-frame dot-matrix ripple, seamless loop at 30 Hz | **this repo** |
| Login screen | SDDM theme, dot-matrix clock, bare username/password | **this repo** |
| Dynamic island | Original plasmoid — pager, stats, media, controls | **this repo** |
| Quote of the day | Original plasmoid — 65 quotes, one a day | **this repo** |
| Inactive windows | KWin effect: unfocused windows drain to greyscale | **this repo** |
| Terminal | Konsole `Nothing` profile + colour scheme | **this repo** |
| Panels | Floating island + dock, black pills via Panel Colorizer | scripted here |
| Global theme, icons, cursor, wallpapers | Nothing 1.8, YAMIS, WhiteSur | fetched from store.kde.org |
| Desktop widgets | Nothing KDE Widgets | fetched from GitHub |
| Fonts | NType 82, Ndot 55, Nothing Font (5×7) | bundled with the widget pack |

This repo deliberately **does not redistribute** Nothing's fonts, the KDE-store
themes or the wallpapers. `install/20-upstream.sh` fetches them from their
authors so the licences stay with them.

---

## Quick start

Kubuntu 24.04+ (or Ubuntu with the `kubuntu-desktop` task), Plasma **6**, Wayland or X11.

```bash
git clone https://github.com/buddi0812/nothing-kde-rice
cd nothing-kde-rice
./install.sh
```

That runs the four user-level steps. Then the two that need root:

```bash
sudo ./install/50-login-screen.sh     # SDDM
sudo ./install/60-boot-animation.sh   # Plymouth
```

Log out and back in. Reboot to see the boot splash.

> **Heads up:** step 4 removes every existing panel — that is the point, it rebuilds
> them. Your old layout is copied to `~/.nothing-rice-backups/` first, and
> `uninstall/revert-desktop.sh` puts it back.

### Running steps individually

Every step is idempotent and standalone:

```bash
./install.sh 40          # just rebuild the panels and widget grid
./install.sh all         # everything including the sudo steps
```

| Step | Does | Root? |
|---|---|---|
| `10-packages` | apt packages | sudo for apt |
| `20-upstream` | widgets, fonts, store themes, wallpapers | no |
| `30-components` | plasmoids, KWin effect, Konsole, fonts, wallpaper | no |
| `40-layout` | panels + desktop widget grid | no |
| `50-login-screen` | SDDM theme + system-wide fonts | **yes** |
| `60-boot-animation` | Plymouth theme + initramfs | **yes** |

---

## Things worth knowing before you start

**The weather widget defaults to Villupuram.** That is the widget author's own
default, not a bug. Right-click → Configure.

**The window decoration is optional.** The titlebars in the screenshots are
[Klassy](https://github.com/paulmcauley/klassy), which is not in the Ubuntu
archive and has to be built. Skip it and KWin falls back to Breeze, which still
looks fine here.

**Do not re-apply the Nothing Global Theme with "use desktop layout" ticked.**
It wipes the panels *and* the desktop widgets. If it happens, `./install.sh 40`
rebuilds everything.

**The desktop containment must be Folder View** for the widget grid to snap to
208 px cells. That is the Kubuntu default. Switching it to Desktop gives you
free pixel placement but loses desktop icons.

---

## What's in here

```
├── install.sh                  orchestrator
├── install/
│   ├── lib.sh                  shared helpers, KDE-store OCS downloader
│   ├── 10-packages.sh          apt
│   ├── 20-upstream.sh          widgets, fonts, store themes, wallpapers
│   ├── 30-components.sh        plasmoids, KWin effect, Konsole, appearance
│   ├── 40-layout.sh            panels + desktop widget grid
│   ├── 50-login-screen.sh      SDDM            (sudo)
│   └── 60-boot-animation.sh    Plymouth        (sudo)
├── plasmoids/
│   ├── com.dev08.nothingdynamicisland/
│   └── com.dev08.nothingquote/
├── kwin/effects/nothing-monochrome-inactive/
├── sddm/Nothing/
├── plymouth/nothing/           60 frames + make-frames.py
├── konsole/                    Nothing profile + colour scheme
├── panel-colorizer/            the two panel-background presets
├── uninstall/revert-desktop.sh
└── docs/
    ├── ENGINEERING-LOG.md      how each piece was built, and what broke
    └── TROUBLESHOOTING.md      every failure mode hit so far, with fixes
```

---

## The custom pieces

### Dynamic island — `com.dev08.nothingdynamicisland`

The reference desktop's island is unreleased, so this is an original
implementation. It avoids the fragile QML sensor APIs entirely: one
`stats.sh` subprocess emits `cpu/mem/temp/vol/mute/bright/net/ntype/bt` as
`\x1f`-separated pairs every 2 s, and the QML just parses that.

The compact pill's left cluster is a real virtual-desktop pager. The expanded
panel drives volume through `wpctl`, caffeine through PowerDevil's
`beginSuppressingSleep`, and DND through `NotificationManager.Settings`.

### Quote of the day — `com.dev08.nothingquote`

65 short quotes, one per day, picked by *local* day number — `Date.UTC(y,m,d)/86400000`
rather than `Date.now()/86400000`, which would roll over at UTC midnight instead
of yours. Click it to step through the set; midnight returns it to the day's own quote.

It keeps the stadium shape of the clock pill it replaces, which costs horizontal
room: text is inset by `min(h*0.36, w*0.2)` per side, leaving ~261 logical px, so
quotes are capped near 95 characters and `Text.Fit` shrinks the rest.

### Monochrome inactive windows — KWin effect

Unfocused windows drain to greyscale instead of going translucent, so they stay
readable over the light wallpaper while still reading as "not here".

The interesting part is what it must *not* do. A held `set()` animation takes a
visibility reference that **outranks the hide minimising relies on** — animate a
minimised window and it never leaves the screen, it just sits there in grey. The
effect therefore treats any window that should not be on screen as never-a-candidate,
and cancels its animation rather than skipping past it. There is also no
handler-level `windowMinimized` signal on this API, so every window is watched
individually via `minimizedChanged`.

### Plymouth theme

The upstream frames were a one-shot ping — ~17 frames of motion, 15 frozen, then a
hard cut back to frame 0. `make-frames.py` recovers the underlying lattice from
those frames by least-squares fit (hex, 5 rings, 91 dots, pitch 22.24 px, residual
0.012 px/dot) and re-renders it at display size as a continuous radial wave, so
frame 59 flows into frame 0 with no seam. Each ring's radius is a pure cosine of
time, which makes the loop exact by construction.

---

## Design rules

Taken from Nothing's published design system, and worth keeping if you modify anything:

- **Greyscale is the hierarchy** — 100 / 90 / 60 / 40. Red `#d71921` is an
  *interrupt only*: battery ≤15 % off-AC, temp ≥80 °C, recording, DND on.
- **Motion is percussive** — short `OutCubic`, staged reveals. No spring, no
  bounce (explicitly an anti-pattern in their system), no gradients, no shadows.
- **One focal element per surface.** Type carries the hierarchy.

---

## Credits

This is a reconstruction, not original design work. The look comes from
Nothing OS; the desktop concept comes from **u/penedeperro**'s
*[KDE] Nothing Laptop (1)* on r/unixporn.

| | |
|---|---|
| Global theme, Plasma style, decoration, colours, wallpapers | [jomada](https://store.kde.org/u/jomada) |
| Nothing KDE Widgets + the Nothing fonts | [jaxparrow07](https://github.com/jaxparrow07/nothing-kde-widgets) |
| YAMIS icon theme | [dirn](https://store.kde.org/p/2303161) |
| Panel Colorizer | [luisbocanegra](https://store.kde.org/p/2130967) |
| Overview widget | [HimDek](https://github.com/HimDek) |
| Plymouth dot lattice (original frames) | [adi1090x](https://github.com/adi1090x/plymouth-themes) |
| SDDM theme base | David Edmundson / KDE, LGPL |
| Klassy decoration | [paulmcauley](https://github.com/paulmcauley/klassy) |

## Licence

GPL-3.0 — see [LICENSE](LICENSE). Third-party components keep their own licences;
none of them are redistributed here.
