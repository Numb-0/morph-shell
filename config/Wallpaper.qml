pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The image the background shows, from a file beside the colours and
// swapped the same way. With no file, or no image in it, the background
// is plain surface.
Singleton {
    id: root

    readonly property string path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/morph-shell/wallpaper.json`
    property string image: ""

    function reload(): void {
        file.reload();
    }

    // Either { "image": path }, or chromix's own { "source": { "image" } }
    // for a theme it made from a wallpaper.
    FileView {
        id: file

        path: root.path

        watchChanges: true
        onFileChanged: reload()

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.image = parsed.image ?? parsed.source?.image ?? "";
            } catch (e) {
                // Mid-write: keep the image already up.
            }
        }

        printErrors: false
        onLoadFailed: root.image = ""
    }
}
