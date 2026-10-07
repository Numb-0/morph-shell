pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// Every workspace at once, as a grid over each screen with the windows
// drawn live inside them. A click on a workspace goes there, a click on a
// window focuses it, a middle click closes it, and dragging one into
// another workspace moves it there. The keyboard walks the grid too.
Scope {
    id: root

    // Loaded, and drawn. Closing fades the grid out before unloading it,
    // so the two part for the length of the fade.
    property bool active: false
    property bool shown: false

    // The screen the keyboard goes to, chosen once on opening, as the
    // pickers do.
    property string keyScreen: ""

    function open(): void {
        if (shown)
            return;
        unload.stop();
        keyScreen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        Hyprland.refreshToplevels();
        active = true;
        shown = true;
    }

    // What to do once closed, such as switching workspace. It waits for
    // the keyboard to be let go: Hyprland hands it back to the window
    // that had it and follows that window to its workspace, so a switch
    // made while the overview holds the keyboard is undone as it closes.
    property var after: null

    function close(after: var): void {
        if (!shown)
            return;
        root.after = after ?? null;
        shown = false;
        handoff.restart();
        unload.restart();
    }

    function toggle(): void {
        if (shown)
            close(null);
        else
            open();
    }

    Timer {
        id: handoff

        interval: 50
        onTriggered: {
            const action = root.after;
            root.after = null;
            action?.();
        }
    }

    Timer {
        id: unload

        interval: Appearance.anim.durations.defaultEffects
        onTriggered: root.active = false
    }

    // From the launcher's commands.
    Connections {
        target: Commands

        function onOverviewRequested(): void {
            root.open();
        }
    }

    //   morph-shell ipc call overview toggle
    IpcHandler {
        target: "overview"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close(null);
        }
    }

    LazyLoader {
        active: root.active

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                color: "transparent"

                // Over everything, the bar included, and reserving nothing.
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "morph-shell-overview"
                WlrLayershell.keyboardFocus: root.shown && modelData.name === root.keyScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                OverviewGrid {
                    screen: win.modelData
                    shown: root.shown

                    onDismissed: after => root.close(after)
                }
            }
        }
    }
}
