pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services.launcher

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
    //   qs -p ~/morph-shell ipc call dock pin firefox 0
    //   qs -p ~/morph-shell ipc call dock unpin firefox
    IpcHandler {
        target: "dock"

        function togglePinned(): void {
            root.togglePinned();
        }

        // Puts an app in the dock, or moves it, to a place among the
        // pins shown; past the last one, or -1, is the end.
        function pin(id: string, index: int): void {
            Apps.pin(Apps.byId(id), index);
        }

        function unpin(id: string): void {
            Apps.unpin(Apps.byId(id));
        }
    }
}
