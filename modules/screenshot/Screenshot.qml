pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// Region screenshots, standing in for slurp in a grim pipeline. The
// shell only picks the region; grim takes the picture, straight into
// the clipboard and a file, and the notification that says so offers
// satty to mark it up.
//
// grim rather than a grab of the shell's own view of the screen: it
// encodes only the region, where a grab has to read back and encode the
// whole screen to crop it afterwards.
Scope {
    id: root

    property bool active: false

    // The picked region, as grim's -g takes it. Set while the overlay
    // has stopped drawing and is waiting to be gone from the screen.
    property string pending: ""

    // The screen the keyboard goes to, chosen once on opening rather
    // than following focus around, which would hand Escape back and
    // forth as the pointer crossed between monitors.
    property string keyScreen: ""

    // How long the notification pops up for, in milliseconds.
    readonly property int notifyTimeout: 8000

    function open(): void {
        if (active)
            return;
        pending = "";
        keyScreen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
        active = true;
    }

    function close(): void {
        shutter.stop();
        active = false;
        pending = "";
    }

    // Global logical coordinates, which is what grim -g reads.
    function capture(x: real, y: real, w: real, h: real): void {
        if (pending !== "")
            return;
        pending = `${Math.round(x)},${Math.round(y)} ${Math.round(w)}x${Math.round(h)}`;
        shutter.restart();
    }

    // Copied first so the image is on the clipboard as soon as grim is
    // done, then saved where satty used to save it, then announced.
    // notify-send waits on the notification: a click on it or its Edit
    // button prints the action's name, and satty opens on the file.
    // Timing out only drops the popup -- the notification stays in the
    // centre with its button, so editing is still there later.
    readonly property string script: `
        dir="\${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
        mkdir -p "$dir" || exit 1
        file="$dir/$(date +%Y%m%d_%H%M%S).png"

        grim -l 1 -g "$1" "$file" || exit 1
        wl-copy --type image/png < "$file"

        action=$(notify-send -a Screenshot -t ${notifyTimeout} \\
            -h "string:image-path:$file" \\
            -A default=Edit -A edit=Edit \\
            "Screenshot copied" "$(basename "$file")")

        case "$action" in
            default|edit)
                exec satty --filename "$file" --output-filename "$file" --copy-command wl-copy ;;
        esac
    `

    // A breath between the overlay going blank and grim reading the
    // screen, so the compositor has put up a frame without the dim.
    Timer {
        id: shutter

        interval: 60
        onTriggered: {
            Quickshell.execDetached(["sh", "-c", root.script, "morph-shell-screenshot", root.pending]);
            root.close();
        }
    }

    // From the launcher's commands.
    Connections {
        target: Commands

        function onScreenshotRequested(): void {
            root.open();
        }
    }

    //   morph-shell ipc call screenshot region
    IpcHandler {
        target: "screenshot"

        function region(): void {
            root.open();
        }

        function cancel(): void {
            root.close();
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

                // Over everything, the bar and notifications included,
                // and reserving nothing.
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "morph-shell-screenshot"
                WlrLayershell.keyboardFocus: modelData.name === root.keyScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Picker {
                    screen: win.modelData
                    hidden: root.pending !== ""

                    onPicked: (x, y, w, h) => root.capture(win.modelData.x + x, win.modelData.y + y, w, h)
                    onCancelled: root.close()
                }
            }
        }
    }
}
