pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Hyprland's state and actions, through Quickshell's own integration
// and hyprctl. What the rest of the shell asks of Hyprland comes from
// here, as niri's comes from Niri -- bar the focus grabs, which are
// windows of their own and stay with the panels they guard.
//
// Workspaces are global: any of them can be shown on any monitor, and
// their ids are what the bar numbers them by. Special workspaces have
// negative ids and live outside the row.
//
// The monitors come from hyprctl rather than from Quickshell's
// HyprlandMonitor, whose activeWorkspace and lastIpcObject never fill
// in on some Hyprland versions. They are read once at the start, and
// again, with the toplevels' IPC objects, after every burst of events
// while something that lays windows out is watching -- the overview,
// the region picker -- so it sees where windows are now, and nothing is
// spawned on every event while nothing is.
Singleton {
    id: root

    readonly property bool available: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

    // hyprctl's monitors, as it gives them.
    property var monitors: []

    // The keyboard layout's name, as Hyprland spells it.
    property string layout: ""

    readonly property string focusedMonitor: available ? (Hyprland.focusedMonitor?.name ?? "") : ""

    // The windows, as Hyprland's toplevels: each carries its IPC object,
    // for where it sits, and its Wayland handle, for a live preview.
    readonly property var toplevels: available ? Hyprland.toplevels.values : []

    // Window count by workspace id, the named ones only.
    readonly property var workspaceWindows: {
        const out = {};
        if (!available)
            return out;
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0)
                out[ws.id] = ws.toplevels.values.length;
        return out;
    }

    readonly property var urgentWorkspaces: {
        const out = {};
        if (!available)
            return out;
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0 && ws.urgent)
                out[ws.id] = true;
        return out;
    }

    function monitorNamed(name: string): var {
        return monitors.find(m => m.name === name) ?? null;
    }

    // A monitor's logical bounds, or null for one not known: hyprctl
    // gives the position in logical pixels already, but the size in real
    // ones and before rotation.
    function monitorBounds(id: int): var {
        const m = monitors.find(m => m.id === id);
        if (!m)
            return null;
        const turned = m.transform % 2 === 1;
        const w = (turned ? m.height : m.width) / m.scale;
        const h = (turned ? m.width : m.height) / m.scale;
        return Qt.rect(m.x, m.y, w, h);
    }

    // The workspace the given monitor shows, from the integration first,
    // which follows a switch the moment it happens, and from hyprctl
    // where that has not filled in. Undefined while neither knows.
    function activeWorkspaceOn(output: string): var {
        if (!available)
            return undefined;
        return Hyprland.monitors.values.find(m => m.name === output)?.activeWorkspace?.id ?? monitorNamed(output)?.activeWorkspace?.id;
    }

    // The same from hyprctl first, for what lays windows out by it and
    // has to agree with their IPC objects; with `special`, the special
    // workspace instead while it is open over the rest.
    function shownWorkspaceOn(output: string, special: bool): var {
        if (!available)
            return undefined;
        const mon = monitorNamed(output);
        if (special && mon?.specialWorkspace?.name)
            return mon.specialWorkspace.id;
        return mon?.activeWorkspace?.id ?? Hyprland.monitors.values.find(m => m.name === output)?.activeWorkspace?.id;
    }

    function dispatch(expr: string): void {
        Hyprland.dispatch(expr);
    }

    // Opens a workspace on the given monitor. Hyprland puts a new one on
    // the focused monitor, so focus moves there first; one that already
    // lives on another monitor is still followed there, as the keybinds
    // do. One expression, since that is all a dispatch takes.
    function focusWorkspace(output: string, id: int): void {
        dispatch(`(function() hl.dispatch(hl.dsp.focus({ monitor = "${output}" })) return hl.dsp.focus({ workspace = "${id}" }) end)()`);
    }

    function focusWindow(address: string): void {
        dispatch(`hl.dsp.focus({ window = "address:${address}" })`);
    }

    function moveWindow(address: string, workspace: int): void {
        dispatch(`hl.dsp.window.move({ workspace = "${workspace}", follow = false, window = "address:${address}" })`);
    }

    function setScreens(on: bool): void {
        dispatch(`hl.dsp.dpms({ action = "${on ? "on" : "off"}" })`);
    }

    readonly property var logoutCommand: ["hyprctl", "dispatch", "exit"]

    // Asks for the toplevels and the monitors again, now rather than
    // after the next event.
    function refresh(): void {
        if (!available)
            return;
        Hyprland.refreshToplevels();
        monitorsQuery.running = true;
    }

    // How many are watching. Each watch() wants an unwatch() when done;
    // the first one in refreshes straight away.
    property int watchers: 0

    function watch(): void {
        watchers++;
        if (watchers === 1)
            refresh();
    }

    function unwatch(): void {
        watchers = Math.max(0, watchers - 1);
        if (watchers === 0)
            debounce.stop();
    }

    // Asks where the pointer is; the answer comes as cursorRead, in
    // global logical pixels. Asked again while the last is still out,
    // the one answer does for both.
    signal cursorRead(real x, real y)

    function queryCursor(): void {
        if (available)
            cursorQuery.running = true;
    }

    Component.onCompleted: refresh()

    Connections {
        target: root.available ? Hyprland : null

        function onRawEvent(event: HyprlandEvent): void {
            // The layout is named in the event itself, after the
            // keyboard's name and a comma -- the layout's own name can
            // have commas in it, so only the first is split on. Every
            // keyboard reports its own switch, and a keyboard plugged in
            // reports its layout again.
            if (event.name === "activelayout") {
                const data = event.data ?? "";
                const name = data.slice(data.indexOf(",") + 1);
                if (name !== "")
                    root.layout = name;
                return;
            }

            // Events come in bursts; one refresh after the last does for
            // the lot, and only while watched. Focus moving between
            // windows changes nothing read here.
            if (root.watchers > 0 && !event.name.startsWith("activewindow"))
                debounce.restart();
        }
    }

    Timer {
        id: debounce

        interval: 40
        onTriggered: root.refresh()
    }

    Process {
        id: monitorsQuery

        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: cursorQuery

        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const pos = JSON.parse(text);
                    root.cursorRead(pos.x, pos.y);
                } catch (e) {}
            }
        }
    }
}
