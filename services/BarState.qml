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

    FileView {
        path: Quickshell.statePath("bar.json")

        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: state

            property bool pinned: false
        }
    }

    //   qs -p ~/morph-shell ipc call bar togglePinned
    IpcHandler {
        target: "bar"

        function togglePinned(): void {
            root.togglePinned();
        }
    }
}
