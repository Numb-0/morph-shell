pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services.session
import qs.services.system

// What the OSD is showing, and when. One for the session, so every
// screen's OSD tells the same thing at the same moment.
//
// Two kinds of reading go through it. Levels -- "volume" and
// "brightness" -- show as a slider. Toggles -- "mic", "caps", "awake",
// "layout" and "profile" -- show as a glyph and a word, with `active` saying
// which way the toggle went.
Singleton {
    id: root

    property string kind: ""
    property bool shown: false

    // For the toggles: whether the thing was just turned on. Mic counts
    // as on when muted, caps when locked: on is whatever the glyph
    // stands out for. Layout and profile have no off, and stay on.
    property bool active: false

    // The keyboard layout's name, as Hyprland spells it.
    property string layout: ""

    property bool capsLock: false

    // Every reading, even one of the same kind as the last, so the OSD
    // can answer each key press rather than only the first.
    signal poked(string kind)

    function show(kind: string, active: bool): void {
        if (!settled)
            return;

        root.kind = kind;
        root.active = active;
        shown = true;
        hideTimer.restart();
        poked(kind);
    }

    // Everything reads something on its way up -- the sink at zero then
    // its level, the backlight once brightnessctl answers, a layout per
    // keyboard -- and none of that is anyone changing anything.
    property bool settled: false

    Timer {
        running: true
        interval: 1500
        onTriggered: root.settled = true
    }

    // A device switched over jumps its level the same way: held off for
    // a moment after.
    property bool sinkSettled: true
    property bool sourceSettled: true

    Timer {
        id: sinkTimer

        interval: 500
        onTriggered: root.sinkSettled = true
    }

    Timer {
        id: sourceTimer

        interval: 500
        onTriggered: root.sourceSettled = true
    }

    Timer {
        id: hideTimer

        interval: Appearance.osd.timeout
        onTriggered: root.shown = false
    }

    Connections {
        target: Audio

        function onVolumeChanged(): void {
            if (root.sinkSettled && Audio.available)
                root.show("volume", false);
        }

        function onMutedChanged(): void {
            if (root.sinkSettled && Audio.available)
                root.show("volume", false);
        }

        function onSinkChanged(): void {
            root.sinkSettled = false;
            sinkTimer.restart();
        }

        function onMicMutedChanged(): void {
            if (root.sourceSettled && Audio.micAvailable)
                root.show("mic", Audio.micMuted);
        }

        function onSourceChanged(): void {
            root.sourceSettled = false;
            sourceTimer.restart();
        }
    }

    Connections {
        target: Backlight

        // Not the idle dim and its undoing: that is the session going
        // quiet, not anyone turning the brightness.
        function onBrightnessChanged(): void {
            if (Backlight.available && !Idle.adjusting)
                root.show("brightness", false);
        }
    }

    Connections {
        target: Idle

        function onAwakeChanged(): void {
            root.show("awake", Idle.awake);
        }
    }

    Connections {
        target: Profiles

        function onProfileChanged(): void {
            if (Profiles.available)
                root.show("profile", true);
        }
    }

    // Hyprland names the layout in the event itself, after the keyboard's
    // name and a comma -- the layout's own name can have commas in it, so
    // only the first is split on. Every keyboard reports its own switch,
    // and a keyboard plugged in reports its layout, so only a layout that
    // differs from the last one counts.
    Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            if (event.name !== "activelayout")
                return;

            const data = event.data ?? "";
            const name = data.slice(data.indexOf(",") + 1);
            if (name === "" || name === root.layout)
                return;

            const first = root.layout === "";
            root.layout = name;
            if (!first)
                root.show("layout", true);
        }
    }

    // Caps Lock has no event anywhere a shell can hear it, but the
    // keyboards' own LEDs follow it, and their files are cheap to read.
    // Watching them does nothing -- sysfs never says a value changed -- so
    // they are read a few times a second instead.
    property var capsLeds: []

    Process {
        running: true

        command: ["sh", "-c", "for led in /sys/class/leds/*::capslock; do [ -e \"$led/brightness\" ] && echo \"$led/brightness\"; done"]

        stdout: StdioCollector {
            onStreamFinished: root.capsLeds = text.split("\n").filter(line => line !== "")
        }
    }

    Variants {
        id: leds

        model: root.capsLeds

        FileView {
            required property string modelData

            path: modelData
            blockLoading: true
        }
    }

    Timer {
        running: root.capsLeds.length > 0
        repeat: true
        interval: 150

        onTriggered: {
            let locked = false;
            for (const led of leds.instances) {
                led.reload();
                locked = locked || parseInt(led.text()) > 0;
            }

            if (locked === root.capsLock)
                return;

            root.capsLock = locked;
            root.show("caps", locked);
        }
    }

    //   qs -p ~/morph-shell ipc call osd hide
    IpcHandler {
        target: "osd"

        function hide(): void {
            hideTimer.stop();
            root.shown = false;
        }
    }
}
