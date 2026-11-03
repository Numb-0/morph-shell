pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// niri's state, kept from its event stream. One connection to
// $NIRI_SOCKET asks for the stream and niri answers with the whole
// state up front -- workspaces, windows, keyboard layouts -- then with
// every change to it, so nothing here is ever polled.
//
// Workspaces belong to an output here, numbered from 1 on each by
// `idx`, with an empty one always kept at the end. Their `id` is
// niri's own and unique across outputs; windows point at it.
//
// Actions go through `niri msg`, one process each: the event stream's
// socket answers nothing else once it is streaming.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
    readonly property bool available: socketPath !== ""

    property var workspaces: []
    property var windows: []

    property var layouts: []
    property int layoutIndex: -1
    readonly property string layout: layouts[layoutIndex] ?? ""

    property bool overviewOpen: false

    // The output the focused workspace is on.
    readonly property string focusedOutput: workspaces.find(ws => ws.is_focused)?.output ?? ""

    function workspacesOn(output: string): var {
        return workspaces.filter(ws => ws.output === output);
    }

    function action(...args): void {
        Quickshell.execDetached(["niri", "msg", "action", ...args]);
    }

    // Opens the workspace at `idx` on the given output, the empty one at
    // the end for any past it. focus-workspace counts on the focused
    // output, so focus moves there first, in the same shell so the two
    // land in order.
    function focusWorkspace(output: string, idx: int): void {
        Quickshell.execDetached(["sh", "-c", 'niri msg action focus-monitor "$1" && niri msg action focus-workspace "$2"', "morph-shell-niri", output, String(idx)]);
    }

    function handle(event: var): void {
        if ("WorkspacesChanged" in event) {
            workspaces = event.WorkspacesChanged.workspaces;
        } else if ("WorkspaceActivated" in event) {
            const {
                id,
                focused
            } = event.WorkspaceActivated;
            const output = workspaces.find(ws => ws.id === id)?.output;
            workspaces = workspaces.map(ws => Object.assign({}, ws, {
                    is_active: ws.output === output ? ws.id === id : ws.is_active,
                    is_focused: focused ? ws.id === id : ws.is_focused
                }));
        } else if ("WorkspaceUrgencyChanged" in event) {
            const {
                id,
                urgent
            } = event.WorkspaceUrgencyChanged;
            workspaces = workspaces.map(ws => ws.id === id ? Object.assign({}, ws, {
                    is_urgent: urgent
                }) : ws);
        } else if ("WindowsChanged" in event) {
            windows = event.WindowsChanged.windows;
        } else if ("WindowOpenedOrChanged" in event) {
            const win = event.WindowOpenedOrChanged.window;
            const rest = windows.filter(w => w.id !== win.id).map(w => win.is_focused && w.is_focused ? Object.assign({}, w, {
                    is_focused: false
                }) : w);
            windows = [...rest, win];
        } else if ("WindowClosed" in event) {
            const id = event.WindowClosed.id;
            windows = windows.filter(w => w.id !== id);
        } else if ("WindowFocusChanged" in event) {
            const id = event.WindowFocusChanged.id;
            windows = windows.map(w => w.is_focused !== (w.id === id) ? Object.assign({}, w, {
                    is_focused: w.id === id
                }) : w);
        } else if ("WindowUrgencyChanged" in event) {
            const {
                id,
                urgent
            } = event.WindowUrgencyChanged;
            windows = windows.map(w => w.id === id ? Object.assign({}, w, {
                    is_urgent: urgent
                }) : w);
        } else if ("KeyboardLayoutsChanged" in event) {
            const kl = event.KeyboardLayoutsChanged.keyboard_layouts;
            layouts = kl.names;
            layoutIndex = kl.current_idx;
        } else if ("KeyboardLayoutSwitched" in event) {
            layoutIndex = event.KeyboardLayoutSwitched.idx;
        } else if ("OverviewOpenedOrClosed" in event) {
            overviewOpen = event.OverviewOpenedOrClosed.is_open;
        }
    }

    Socket {
        id: stream

        path: root.socketPath
        connected: root.available

        onConnectedChanged: {
            if (connected) {
                write('"EventStream"\n');
                flush();
            } else if (root.available) {
                reconnect.restart();
            }
        }

        onError: reconnect.restart()

        // The first line answers the request itself; every one after is
        // an event.
        parser: SplitParser {
            onRead: line => {
                let event;
                try {
                    event = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (!("Ok" in event) && !("Err" in event))
                    root.handle(event);
            }
        }
    }

    // niri restarting, or the shell starting before it: try again.
    Timer {
        id: reconnect

        interval: 1000
        onTriggered: {
            stream.connected = false;
            stream.connected = true;
        }
    }
}
