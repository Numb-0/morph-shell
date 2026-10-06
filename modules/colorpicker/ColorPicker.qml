pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// A colour picker in place of hyprpicker. Every screen freezes, a lens
// follows the pointer, and a click copies the colour under it as hex
// and says so in a notification.
Scope {
    id: root

    property bool active: false

    // The screen the keyboard goes to, chosen once on opening, as the
    // screenshot picker does, so Escape stays in one place.
    property string keyScreen: ""

    // How long the notification pops up for, in milliseconds.
    readonly property int notifyTimeout: 4000

    function open(): void {
        if (active)
            return;
        keyScreen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        active = true;
    }

    function close(): void {
        active = false;
    }

    function take(c: color): void {
        const hex = c.toString().toUpperCase();
        const rgb = `rgb(${Math.round(c.r * 255)}, ${Math.round(c.g * 255)}, ${Math.round(c.b * 255)})`;
        // A grey has no hue, and Qt says -1 for it.
        const hsl = `hsl(${Math.round(Math.max(0, c.hslHue) * 360)}, ${Math.round(c.hslSaturation * 100)}%, ${Math.round(c.hslLightness * 100)}%)`;
        Quickshell.execDetached(["wl-copy", hex]);
        // The hint has the notification show the colour itself, as a
        // swatch beside the text.
        Quickshell.execDetached(["notify-send", "-a", "Color picker", "-t", String(notifyTimeout), "-h", `string:x-morph-color:${hex}`, `${hex} copied`, `${rgb}\n${hsl}`]);
        close();
    }

    // From the launcher's commands.
    Connections {
        target: Commands

        function onColorPickerRequested(): void {
            root.open();
        }
    }

    //   morph-shell ipc call colorpicker pick
    IpcHandler {
        target: "colorpicker"

        function pick(): void {
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
                WlrLayershell.namespace: "morph-shell-colorpicker"
                WlrLayershell.keyboardFocus: modelData.name === root.keyScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Overlay {
                    screen: win.modelData

                    onPicked: c => root.take(c)
                    onCancelled: root.close()
                }
            }
        }
    }
}
