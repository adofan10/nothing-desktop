#!/usr/bin/env bash
# Step 4 -- rebuild the panels and the desktop widget grid from scratch.
#
# DESTRUCTIVE: this removes every existing panel. That is deliberate -- it is
# also the recovery script for when a Global Theme with "use desktop layout"
# ticked wipes the layout.
#
# Optional environment overrides:
#   TZONE=Europe/Berlin  DOCK_LAUNCHERS="applications:firefox.desktop,..."
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TZONE="${TZONE:-$(timedatectl show -p Timezone --value 2>/dev/null || echo UTC)}"
DOCK_LAUNCHERS="${DOCK_LAUNCHERS:-applications:org.kde.dolphin.desktop,applications:firefox_firefox.desktop,applications:org.kde.konsole.desktop,applications:spotify_spotify.desktop}"
F=plasma-org.kde.plasma.desktop-appletsrc

say "Backing up the current layout"
BK="$HOME/.nothing-rice-backups"; mkdir -p "$BK"
cp "$HOME/.config/$F" "$BK/appletsrc.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
step "$BK"

say "Rebuilding panels and widgets (timezone: $TZONE)"
IDS=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
var N = "com.jaxparrow07.nothingkdewidgets.";
var out = [];
panels().forEach(function (p) { p.remove(); });

// --- top: the dynamic island, floating, sized to its contents ---
var isl = new Panel;
isl.location = "top"; isl.alignment = "center"; isl.lengthMode = "fit";
isl.height = 48; isl.floating = true; isl.hiding = "none";
isl.addWidget("com.dev08.nothingdynamicisland");
var ic = isl.addWidget("luisbocanegra.panel.colorizer");
ic.currentConfigGroup = ["General"];
ic.writeConfig("hideWidget", true);
ic.writeConfig("animatePropertyChanges", true);
ic.writeConfig("animationDuration", 300);
out.push("ISLAND_PANEL=" + isl.id);
out.push("ISLAND_COLORIZER=" + ic.id);

// --- bottom: the dock ---
var dock = new Panel;
dock.location = "bottom"; dock.alignment = "center"; dock.lengthMode = "fit";
dock.height = 56; dock.floating = true; dock.hiding = "windowscover";
// order matters -- addWidget order is the dock order.
// start button, then the app icons, then (invisible) colorizer, then overview.
dock.addWidget("com.dev08.nothingappdrawer");
var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", "'"$DOCK_LAUNCHERS"'");
tasks.writeConfig("indicateAudioStreams", false);
tasks.writeConfig("maxStripes", 1);
tasks.writeConfig("showToolTips", false);
tasks.reloadConfig();
var dc = dock.addWidget("luisbocanegra.panel.colorizer");
dc.currentConfigGroup = ["General"];
dc.writeConfig("hideWidget", true);
dc.writeConfig("animatePropertyChanges", true);
dc.writeConfig("animationDuration", 300);
try { dock.addWidget("com.himdek.kde.plasma.overview"); } catch (e) {}
out.push("DOCK_PANEL=" + dock.id);
out.push("DOCK_COLORIZER=" + dc.id);

// --- desktop widget grid ---
var d = null;
desktops().forEach(function (x) { if (x.screen === 0) d = x; });
function add(type, group, cfg) {
    var a = d.addWidget(type);
    a.currentConfigGroup = [group];
    for (var k in cfg) a.writeConfig(k, cfg[k]);
    a.reloadConfig();
    return a.id;
}
out.push("DESKTOP="  + d.id);
out.push("W_DATE="   + add(N + "date",              "General",    { themeMode: 0 }));
out.push("W_BATT="   + add(N + "battery",           "General",    { themeMode: 0 }));
out.push("W_WEA1="   + add(N + "weather",           "General",    { themeMode: 0, widgetVariant: 0 }));
out.push("W_GLYPH="  + add("com.dev08.nothingglyph", "General",   {}));
out.push("W_QUOTE="  + add("com.dev08.nothingquote","General",    { themeMode: 0 }));
out.push("W_MEDIA="  + add(N + "media",             "General",    { themeMode: 0 }));
out.push("W_BIG="    + add(N + "digitalclocklarge", "Appearance", { fontStyle: 1, showDate: true, use24HourFormat: true, useDarkerFont: true, themeMode: 1 }));
print(out.join("\n"));
' 2>/dev/null | grep -v QThreadStorage)

echo "$IDS" | sed 's/^/    /'
eval "$(echo "$IDS" | grep -E '^[A-Z_0-9]+=[0-9]+$')"
[ -n "${DESKTOP:-}" ] || die "layout script returned no desktop containment"

say "Stopping plasmashell to write config it would otherwise overwrite"
kquitapp6 plasmashell >/dev/null 2>&1 || true
sleep 3

say "Panel geometry, backgrounds, widget placement"
# The scripting API's `hiding` does not always survive; pin the view settings.
for pair in "$ISLAND_PANEL:48" "$DOCK_PANEL:56"; do
    pid="${pair%%:*}"; th="${pair##*:}"
    kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $pid" --key floating 1
    kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $pid" --key panelLengthMode 1
    kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $pid" --key panelVisibility 2
    kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $pid" --group Defaults --key thickness "$th"
done

# Native Plasma has no "transparent panel" option -- Panel Colorizer draws the
# black pill on both panels. Its whole state is one JSON blob per instance.
kwriteconfig6 --file $F --group Containments --group "$ISLAND_PANEL" --group Applets --group "$ISLAND_COLORIZER" \
  --group Configuration --group General --key globalSettings "$(cat "$REPO/panel-colorizer/pc-island-transparent.json")"
kwriteconfig6 --file $F --group Containments --group "$DOCK_PANEL" --group Applets --group "$DOCK_COLORIZER" \
  --group Configuration --group General --key globalSettings "$(cat "$REPO/panel-colorizer/pc-dock.json")"

# Folder View snaps to a 208 px grid, so these are grid slots, not free pixels.
# NOTE: these keys live directly under [Containments][N], NOT under [General].
GEO="Applet-$W_DATE:64,80,208,208,0;Applet-$W_BATT:272,80,208,208,0;Applet-$W_WEA1:64,288,208,208,0;Applet-$W_GLYPH:272,288,208,208,0;Applet-$W_QUOTE:64,496,416,208,0;Applet-$W_MEDIA:64,704,416,208,0;Applet-$W_BIG:592,80,624,208,0;"
kwriteconfig6 --file $F --group Containments --group "$DESKTOP" --key "ItemGeometries-1786x1116" "$GEO"
kwriteconfig6 --file $F --group Containments --group "$DESKTOP" --key "ItemGeometriesHorizontal" "$GEO"

say "Restarting plasmashell"
setsid kstart plasmashell >/dev/null 2>&1 &
sleep 8

cat <<MSG

Layout rebuilt:
  island   panel $ISLAND_PANEL  (top, always visible)
  dock     panel $DOCK_PANEL  (bottom, hides under windows)
  desktop  containment $DESKTOP with 7 widgets

Two things the scripts cannot set for you:
  * Weather location defaults to Villupuram (the widget's own default).
    Right-click the weather widget -> Configure to change it.
  * Dolphin's Information panel is a binary window-state blob: press F11 in
    Dolphin once and it sticks.
MSG
