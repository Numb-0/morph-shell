pragma Singleton

import QtQuick
import Quickshell
import qs.services.compositor

// The workspaces, once for the session, as numbered slots on a screen:
// how many windows each holds, which want attention, which one the
// screen shows, and opening one.
//
// On Hyprland they are global -- any of them can be shown on any
// monitor -- so the slots are the workspace ids and every screen gets
// the same answer, bar which one it shows. On niri each output has its
// own, and the slots are their places in its column, from 1.
Singleton {
    id: root

    // Window count by slot on the given screen.
    function windowsOn(output: string): var {
        if (!Compositor.isNiri)
            return Hypr.workspaceWindows;
        const counts = {};
        for (const w of Niri.windows)
            counts[w.workspace_id] = (counts[w.workspace_id] ?? 0) + 1;
        const out = {};
        for (const ws of Niri.workspacesOn(output))
            out[ws.idx] = counts[ws.id] ?? 0;
        return out;
    }

    function urgentOn(output: string): var {
        if (!Compositor.isNiri)
            return Hypr.urgentWorkspaces;
        const out = {};
        for (const ws of Niri.workspacesOn(output))
            if (ws.is_urgent || Niri.windows.some(w => w.workspace_id === ws.id && w.is_urgent))
                out[ws.idx] = true;
        return out;
    }

    // Slots holding windows, in order.
    function occupiedOn(output: string): var {
        const windows = windowsOn(output);
        const out = [];
        for (const id in windows)
            if (windows[id] > 0)
                out.push(+id);
        return out.sort((a, b) => a - b);
    }

    // The slot the given screen shows.
    function activeOn(output: string): int {
        if (Compositor.isNiri)
            return Niri.workspacesOn(output).find(ws => ws.is_active)?.idx ?? 1;
        if (Compositor.isHyprland)
            return Hypr.activeWorkspaceOn(output) ?? 1;
        return 1;
    }

    // Opens a slot on the given screen.
    function goTo(output: string, id: int): void {
        if (output === "")
            return;
        if (Compositor.isNiri)
            Niri.focusWorkspace(output, id);
        else if (Compositor.isHyprland)
            Hypr.focusWorkspace(output, id);
    }

    // Steps through the slots in use from the one the given screen
    // shows, wrapping at the ends -- rather than from the focused
    // screen's, which is what a relative dispatch would do.
    function step(output: string, delta: int): void {
        const from = activeOn(output);
        const occupied = occupiedOn(output);
        const used = occupied.includes(from) ? occupied : [...occupied, from].sort((a, b) => a - b);
        const at = used.indexOf(from);
        goTo(output, used[(at + delta + used.length) % used.length]);
    }
}
