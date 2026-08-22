/*
 * Nothing rice -- monochrome inactive windows.
 *
 * Replaces the translucency effect's inactive-window fade: unfocused windows
 * drain to greyscale instead of going see-through, so they stay readable over
 * the wallpaper while still reading as "not here".
 *
 * Config lives in kwinrc under [Effect-nothing-monochrome-inactive]:
 *   Saturation   0-100, saturation kept on inactive windows (0 = pure grey)
 *   Duration     ms of the colour fade
 *   AffectDocks  also desaturate panels/docks
 *   AffectFullScreen  also desaturate inactive full-screen windows
 */
"use strict";

const cfg = {
    saturation: 0.0,
    duration: 250,
    affectDocks: false,
    affectFullScreen: false,
};

function loadConfig() {
    const sat = effect.readConfig("Saturation", 0) / 100;
    cfg.saturation = Math.max(0, Math.min(1, sat));
    cfg.duration = animationTime(effect.readConfig("Duration", 250));
    cfg.affectDocks = effect.readConfig("AffectDocks", false);
    cfg.affectFullScreen = effect.readConfig("AffectFullScreen", false);
}

// Only real windows. OSDs, menus, notifications and the desktop are never
// "inactive" in a way the user cares about, and greying them just looks broken.
function isCandidate(window) {
    if (!window || window.deleted) {
        return false;
    }
    // A held set() animation keeps KWin painting the window, which outranks the
    // hide that minimising and desktop switches rely on. Animate one of those
    // and it never leaves the screen -- it just sits there in grey. So a window
    // that is not meant to be on screen is never a candidate.
    if (window.minimized || window.onCurrentDesktop === false) {
        return false;
    }
    if (window.dock) {
        return cfg.affectDocks;
    }
    if (window.fullScreen && !cfg.affectFullScreen) {
        return false;
    }
    return window.normalWindow || window.dialog || window.utility || window.toolbar;
}

// A modal dialog and the window it belongs to are one unit -- greying the parent
// while its own dialog has focus looks like a bug.
function sharesFocusWith(window, active) {
    if (!active) {
        return false;
    }
    for (let side = 0; side < 2; ++side) {
        let node = side === 0 ? active : window;
        const target = side === 0 ? window : active;
        for (let hops = 0; node && hops < 8; ++hops) {
            if (node === target) {
                return true;
            }
            node = node.transientFor;
        }
    }
    return false;
}

function applySaturation(window, target) {
    if (window.nothingMonoAnimation !== undefined) {
        if (retarget(window.nothingMonoAnimation, target, cfg.duration)) {
            return;
        }
        // The animation was dropped underneath us (window re-mapped); start over.
        window.nothingMonoAnimation = undefined;
    }
    if (target === 1.0) {
        return;  // full colour is the default state; nothing to hold.
    }
    window.nothingMonoAnimation = set({
        window: window,
        duration: cfg.duration,
        curve: QEasingCurve.InOutQuad,
        type: Effect.Saturation,
        from: 1.0,
        to: target,
    });
}

function forget(window) {
    if (window && window.nothingMonoAnimation !== undefined) {
        cancel(window.nothingMonoAnimation);
        window.nothingMonoAnimation = undefined;
    }
}

function refresh() {
    const active = effects.activeWindow;
    const stack = effects.stackingOrder;
    for (let i = 0; i < stack.length; ++i) {
        const window = stack[i];
        if (!isCandidate(window)) {
            // Let go of anything we are still holding, or the window stays
            // pinned to the screen in grey. See isCandidate().
            forget(window);
            continue;
        }
        applySaturation(window, sharesFocusWith(window, active) ? 1.0 : cfg.saturation);
    }
}

// There is no handler-level minimise signal on this API, so every window has to
// be watched on its own -- otherwise nothing tells us to release a window that
// just got minimised or sent to another desktop.
function watch(window) {
    if (!window || window.nothingMonoWatched) {
        return;
    }
    window.nothingMonoWatched = true;
    if (window.minimizedChanged !== undefined) {
        window.minimizedChanged.connect(refresh);
    }
    if (window.desktopsChanged !== undefined) {
        window.desktopsChanged.connect(refresh);
    }
}

function added(window) {
    watch(window);
    refresh();
}

function reconfigure() {
    const stack = effects.stackingOrder;
    for (let i = 0; i < stack.length; ++i) {
        forget(stack[i]);
    }
    loadConfig();
    refresh();
}

effect.configChanged.connect(reconfigure);
effects.windowAdded.connect(added);
effects.windowActivated.connect(refresh);
effects.windowClosed.connect(forget);

loadConfig();
const initial = effects.stackingOrder;
for (let i = 0; i < initial.length; ++i) {
    watch(initial[i]);
}
refresh();
