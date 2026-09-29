pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the bar remembers about itself between sessions. For now only
// whether it is pinned: held open at the top of the screen, with room
// kept for it, rather than hiding until the pointer reaches the edge.
Singleton {
    id: root

    readonly property bool pinned: state.pinned

    function togglePinned(): void {
        state.pinned = !state.pinned;
    }

    // Asks the bar on the focused screen to open or close one of its
    // panels. Each screen's bar keeps its own open panel, so this only
    // passes the request on; the bars decide which of them answers.
    signal panelToggled(string panel)

    FileView {
        path: Quickshell.statePath("bar.json")

        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: state

            property bool pinned: false
        }
    }

    //   qs -p ~/morph-shell ipc call bar togglePinned
    //   qs -p ~/morph-shell ipc call bar toggle session
    IpcHandler {
        target: "bar"

        function togglePinned(): void {
            root.togglePinned();
        }

        function toggle(panel: string): void {
            root.panelToggled(panel);
        }
    }
}
