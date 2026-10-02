import QtQuick

// A password dot on its way out. The field takes the real dot away at
// once, so the row can close up, and leaves one of these where it stood
// to play the exit and then remove itself.
Rectangle {
    id: root

    enum Mode {
        // One character backspaced: it sinks and shrinks away.
        Erase,
        // The whole line cleared: the dots lift off one after another
        // from the right, as if wiped.
        Clear,
        // A wrong password: they drop out of the field and tumble apart.
        Fall
    }

    property int mode: Ghost.Erase
    property int size: 10

    // Place in the line, which staggers the cascade and seeds where each
    // falling dot drifts.
    property int order: 0

    property real startScale: 1

    // 0 to 1 over the exit; everything below is drawn from it.
    property real t: 0

    readonly property real seed: Math.sin(order * 12.9898 + 4.1414) * 43758.5453 % 1

    width: size
    height: size
    radius: size / 2

    transform: Translate {
        x: root.mode === Ghost.Fall ? root.seed * 16 * root.t : 0
        y: {
            switch (root.mode) {
            case Ghost.Fall:
                return (34 + Math.abs(root.seed) * 14) * root.t * root.t - 10 * Math.sin(root.t * Math.PI) * (1 - root.t);
            case Ghost.Clear:
                return -14 * root.t;
            default:
                return 6 * root.t;
            }
        }
    }

    scale: startScale * (root.mode === Ghost.Fall ? 1 - 0.5 * t : 1 - t)
    opacity: root.mode === Ghost.Fall ? 1 - Math.max(0, t - 0.25) / 0.6 : 1 - t * t

    SequentialAnimation {
        running: true

        PauseAnimation {
            duration: root.mode === Ghost.Clear ? root.order * 22 : root.mode === Ghost.Fall ? Math.abs(root.seed) * 90 : 0
        }
        NumberAnimation {
            target: root
            property: "t"
            from: 0
            to: 1
            duration: root.mode === Ghost.Fall ? 650 : root.mode === Ghost.Clear ? 280 : 220
            easing.type: root.mode === Ghost.Fall ? Easing.Linear : Easing.OutCubic
        }
        ScriptAction {
            script: root.destroy()
        }
    }
}
