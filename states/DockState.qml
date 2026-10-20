pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the dock remembers about itself between sessions. For now only
// whether it is pinned: held up at the bottom of the screen, with room
// kept for it, rather than hiding until the pointer reaches the edge.
Singleton {
    id: root

    readonly property bool pinned: state.pinned

    function togglePinned(): void {
        state.pinned = !state.pinned;
    }

    FileView {
        path: Quickshell.statePath("dock.json")

        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: state

            property bool pinned: false
        }
    }

    //   qs -p ~/morph-shell ipc call dock togglePinned
    IpcHandler {
        target: "dock"

        function togglePinned(): void {
            root.togglePinned();
        }
    }
}
