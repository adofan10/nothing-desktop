// Nothing window cycle -- two actions, exposed as global shortcuts:
//
//   NothingMinimiseFocusNext   put the active window away, focus what is under it
//   NothingRestoreLast         bring back the last window put away, and focus it
//
// KWin has no way to bind a touchpad swipe from a script: EffectsHandler has
// registerTouchpadSwipeShortcut() in C++, but the JS API only exposes
// registerShortcut / registerScreenEdge / registerTouchScreenEdge. So the
// gestures live in ~/.local/bin/nothing-gestures, which reads libinput and
// invokes these two by name over kglobalaccel's D-Bus interface.
//
// They register with NO default key, deliberately: anything in the Meta+Shift
// range risks colliding with a stock KWin binding. Assign keys in
// System Settings -> Shortcuts -> KWin if you want them on the keyboard too.

// On-screen feedback. The window itself already animates -- KWin's `squash`
// effect is loaded and plays on minimise and restore alike, and the rice's own
// monochrome-inactive effect fades the newly focused window from grey back to
// colour -- but a swipe deserves to say what it did, especially when the window
// that goes away was covering the one that arrives.
//
// This lives in the KWin script rather than in the gesture daemon so it fires on
// every path into these actions: the touchpad, a key binding, or a D-Bus call.
// callDBus is one of the few host functions KWin exposes to scripts.
//
// Set to false for silent gestures; the window animation stays either way.
var SHOW_OSD = true;

function osd(icon, label, w) {
    if (!SHOW_OSD) return;
    var name = "";
    if (w) name = w.caption || w.resourceClass || "";
    if (name.length > 42) name = name.substring(0, 41) + "\u2026";
    callDBus("org.kde.plasmashell", "/org/kde/osdService", "org.kde.osdService",
             "showText", icon, name ? label + "  \u00b7  " + name : label);
}

// Windows this script minimised, most recent last. Restoring walks it backwards,
// so up/down are exact inverses for as long as you keep swiping.
var putAway = [];
var PUT_AWAY_MAX = 32;

function alive(w) {
    // A window closed since we stored it leaves a stale wrapper behind; reading
    // a property off it gives undefined rather than throwing.
    return !!w && w.deleted !== true && w.normalWindow !== undefined;
}

// Is this something the user thinks of as "a window on this screen right now"?
function isCandidate(w) {
    if (!alive(w)) return false;
    if (!w.normalWindow) return false;
    if (w.skipTaskbar || w.skipSwitcher) return false;
    if (!w.onAllDesktops && w.desktops && w.desktops.length > 0
        && w.desktops.indexOf(workspace.currentDesktop) === -1) return false;
    if (w.activities && w.activities.length > 0
        && w.activities.indexOf(workspace.currentActivity) === -1) return false;
    return true;
}

// stackingOrder runs bottom to top, so walk it backwards to get "the next window
// down" in the order the user actually sees them.
function topmostVisible(exclude) {
    var s = workspace.stackingOrder;
    for (var i = s.length - 1; i >= 0; --i) {
        var w = s[i];
        if (w === exclude || w.minimized || !isCandidate(w)) continue;
        return w;
    }
    return null;
}

function topmostMinimised() {
    var s = workspace.stackingOrder;
    for (var i = s.length - 1; i >= 0; --i) {
        var w = s[i];
        if (isCandidate(w) && w.minimized) return w;
    }
    return null;
}

function minimiseFocusNext() {
    var w = workspace.activeWindow;
    if (!isCandidate(w) || !w.minimizable) {
        // Nothing useful focused -- the desktop itself, say. Take the top window
        // instead, so the gesture still does the obvious thing.
        w = topmostVisible(null);
        if (!w || !w.minimizable) return;
    }
    // Resolve the successor BEFORE minimising: KWin refocuses on its own the
    // moment the active window goes away, and then "next" is already wrong.
    var next = topmostVisible(w);

    w.minimized = true;
    putAway.push(w);
    if (putAway.length > PUT_AWAY_MAX) putAway.shift();

    if (next) workspace.activeWindow = next;

    // the arrow points the way the fingers went
    osd("go-down", "MINIMISED", w);
}

function restoreLast() {
    // Our own stack first, skipping anything that has closed or been restored
    // by hand in the meantime.
    while (putAway.length > 0) {
        var w = putAway.pop();
        if (alive(w) && w.minimized && isCandidate(w)) {
            w.minimized = false;
            workspace.activeWindow = w;
            osd("go-up", "RESTORED", w);
            return;
        }
    }
    // Stack empty -- fall back to whatever is minimised and highest, so the
    // gesture is still useful after a fresh login.
    var m = topmostMinimised();
    if (m) {
        m.minimized = false;
        workspace.activeWindow = m;
        osd("go-up", "RESTORED", m);
    }
    // Nothing to restore stays silent on purpose: an over-swipe should not put a
    // notice on screen every time it finds an empty stack.
}

// Keep the stack honest when a window is restored or closed outside this script.
workspace.windowRemoved.connect(function (w) {
    var i = putAway.indexOf(w);
    if (i !== -1) putAway.splice(i, 1);
});

registerShortcut("NothingMinimiseFocusNext",
                 "Nothing: Minimise window and focus the next", "",
                 minimiseFocusNext);
registerShortcut("NothingRestoreLast",
                 "Nothing: Restore last minimised window", "",
                 restoreLast);
