pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The internal panel's backlight, as the bar wants it: one level, and
// the glyph that goes with it.
//
// Named for the hardware rather than for the reading, so the bar widget
// can be called Brightness without shadowing this -- the same reason
// Power is not called Battery.
Singleton {
    id: root

    // brightnessctl's own name for the device: amdgpu_bl1 and the like.
    // Empty until it has answered, and forever on anything with no
    // backlight at all.
    property string device: ""

    // Raw steps, on whatever scale the panel counts in -- 65535 here,
    // 255 elsewhere, 100 on some laptops. Nothing outside this file
    // works in these units; everything else reads `brightness`.
    property int steps: 0
    property int maxSteps: 0

    readonly property bool available: device !== "" && maxSteps > 0

    // 0..1, as everything else in the shell expects a level.
    readonly property real brightness: maxSteps > 0 ? steps / maxSteps : 0

    // Never all the way off. A black panel is indistinguishable from a
    // sleeping one, and the way back up is a key you can no longer see.
    readonly property real minimum: 0.01

    // Three steps: the glyph is a sun that grows, so a finer ramp would
    // only be telling the number twice.
    readonly property string icon: {
        if (brightness < 0.34)
            return "brightness_low";
        if (brightness < 0.67)
            return "brightness_medium";
        return "brightness_high";
    }

    function setBrightness(value: real): void {
        if (!available)
            return;

        const target = Math.round(Math.max(minimum, Math.min(1, value)) * maxSteps);
        if (target === steps)
            return;

        // Moved here first and written after, so a slider under the
        // pointer answers now rather than a round trip later. The write
        // comes back through the watch below and agrees with it.
        steps = target;

        // Raw steps rather than a percentage: on a 65535-step panel a
        // whole percent is a visible jump, and a drag made of those
        // reads as a staircase.
        Quickshell.execDetached(["brightnessctl", "-d", device, "-q", "s", String(target)]);
    }

    function changeBrightness(delta: real): void {
        setBrightness(brightness + delta);
    }

    // One call, for the device's name and the top of its scale. Both
    // hold for as long as the panel is attached, so nothing asks again
    // -- the level itself comes from the kernel's own file instead.
    Process {
        running: true

        // The default device is the first of the backlight class, which
        // is the panel. The machine's leds -- keyboard backlight, caps
        // lock -- are a different class and stay out of this.
        command: ["brightnessctl", "-m"]

        stdout: StdioCollector {
            onStreamFinished: {
                // device,class,current,percent,max
                const fields = text.trim().split("\n")[0].split(",");

                // A machine with no backlight says nothing at all here,
                // which leaves `available` false and the widget undrawn.
                if (fields.length < 5)
                    return;

                root.maxSteps = parseInt(fields[4]);
                root.steps = parseInt(fields[2]);

                // Last, so the watch below opens a file whose scale is
                // already known.
                root.device = fields[0];
            }
        }
    }

    // The kernel's own copy of the level, watched rather than polled.
    // Anything else that moves the backlight -- a compositor binding, a
    // brightness key, another shell -- writes through this file, and the
    // bar follows it within the frame.
    FileView {
        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        watchChanges: true

        onFileChanged: reload()

        onLoaded: {
            const value = parseInt(text());
            if (!isNaN(value))
                root.steps = value;
        }
    }
}
