pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Hyprland's workspaces, once for the session. They are global -- any of
// them can be shown on any monitor -- so which exist, how many windows
// each holds and which want attention is the same answer for every bar,
// and every bar reads it from here. What differs by screen is only which
// workspace that screen shows, which each widget reads off its own
// monitor.
Singleton {
    id: root

    // Window count by workspace id, for the named ones only: special
    // workspaces have negative ids and live outside the row.
    readonly property var windows: {
        const out = {};
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0)
                out[ws.id] = ws.toplevels.values.length;
        return out;
    }

    readonly property var urgent: {
        const out = {};
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0 && ws.urgent)
                out[ws.id] = true;
        return out;
    }

    // Workspaces holding windows, in order.
    readonly property var occupied: {
        const out = [];
        for (const id in windows)
            if (windows[id] > 0)
                out.push(+id);
        return out.sort((a, b) => a - b);
    }

    function windowsOn(id: int): int {
        return windows[id] ?? 0;
    }

    // Opens a workspace on the given monitor. Hyprland puts a new
    // workspace on the focused monitor, so focus moves there first; one
    // that already lives on another monitor is still followed there, as
    // the keybinds do. One expression, since that is all a dispatch takes.
    function goTo(monitor: HyprlandMonitor, id: int): void {
        if (!monitor)
            return;
        Hyprland.dispatch(`(function() hl.dispatch(hl.dsp.focus({ monitor = "${monitor.name}" })) return hl.dsp.focus({ workspace = "${id}" }) end)()`);
    }

    // Steps through the workspaces in use from the one the given monitor
    // shows, wrapping at the ends -- rather than from the focused
    // monitor's, which is what a relative dispatch would do.
    function step(monitor: HyprlandMonitor, delta: int): void {
        const from = monitor?.activeWorkspace?.id ?? 1;
        const used = occupied.includes(from) ? occupied : [...occupied, from].sort((a, b) => a - b);
        const at = used.indexOf(from);
        goTo(monitor, used[(at + delta + used.length) % used.length]);
    }
}
