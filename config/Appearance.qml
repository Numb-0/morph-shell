pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Where the colours come from. A theme switcher swaps this file (or
    // what it links to) and the shell follows; with no file the defaults
    // below, Catppuccin Mocha, stand.
    readonly property string colorsPath: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/morph-shell/colors.json`

    // Material 3 colour roles, named as material-color-utilities names
    // them behind an m3 prefix: QML reads a property called onSurface as
    // a handler for a surface signal, so the bare names cannot be
    // declared. The fallbacks are Catppuccin Mocha.
    //
    // Each role fades to its new value rather than cutting, so a theme
    // change washes over the whole shell at once and no widget needs a
    // colour animation of its own for it.
    readonly property QtObject palette: QtObject {
        default property list<QtObject> behaviors

        // The base the panels are cut from, and the containers on it.
        // Panels sit on surfaceContainer; wells and cards inset into a
        // panel drop back to surface.
        property color m3surface: root.loaded.surface ?? "#1e1e2e"
        property color m3surfaceContainer: root.loaded.surfaceContainer ?? "#313244"

        // Content on any surface: body text, then the quieter secondary
        // text and inactive glyphs.
        property color m3onSurface: root.loaded.onSurface ?? "#cdd6f4"
        property color m3onSurfaceVariant: root.loaded.onSurfaceVariant ?? "#bac2de"

        property color m3primary: root.loaded.primary ?? "#89b4fa"
        property color m3onPrimary: root.loaded.onPrimary ?? "#1e1e2e"

        // Borders and the off state of controls: the unchecked switch,
        // an unfocused field.
        property color m3outline: root.loaded.outline ?? "#6c7086"

        // States. Warning and error carry the battery as it drains;
        // success calls out charging. Material has no success or warning
        // role, so a theme supplies them as custom colours, ideally
        // harmonised towards primary.
        property color m3error: root.loaded.error ?? "#f38ba8"
        property color m3onError: root.loaded.onError ?? "#1e1e2e"
        property color m3success: root.loaded.success ?? "#a6e3a1"
        property color m3warning: root.loaded.warning ?? "#f9e2af"

        Behavior on m3surface {
            ColorAnimation {
                duration: root.anim.durations.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.anim.slowEffects
            }
        }

        Behavior on m3surfaceContainer {
            ColorAnimation {
                duration: root.anim.durations.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.anim.slowEffects
            }
        }

        Behavior on m3onSurface {
            ColorAnimation {
                duration: root.anim.durations.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.anim.slowEffects
            }
        }

        Behavior on m3onSurfaceVariant {
            ColorAnimation {
                duration: root.anim.durations.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.anim.slowEffects
            }
        }

        Behavior on m3primary {
            ColorAnimation {
                duration: root.anim.durations.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.anim.slowEffects
            }
        }

        Behavior on m3onPrimary {
            ColorAnimation {
                duration: root.anim.durations.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.anim.slowEffects
            }
        }

        Behavior on m3outline {
            ColorAnimation {
                duration: root.anim.durations.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.anim.slowEffects
            }
        }

        Behavior on m3error {
            ColorAnimation {
                duration: root.anim.durations.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.anim.slowEffects
            }
        }

        Behavior on m3onError {
            ColorAnimation {
                duration: root.anim.durations.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.anim.slowEffects
            }
        }

        Behavior on m3success {
            ColorAnimation {
                duration: root.anim.durations.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.anim.slowEffects
            }
        }

        Behavior on m3warning {
            ColorAnimation {
                duration: root.anim.durations.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.anim.slowEffects
            }
        }
    }

    // The roles the file sets, by their M3 names. Keys may be camelCase
    // or snake_case (matugen writes on_surface), and anything the file
    // leaves out falls back to the default above.
    //
    //   { "primary": "#a8c8ff", "onPrimary": "#07305f", "surface": "#111318", ... }
    property var loaded: ({})

    function load(text: string): void {
        try {
            const roles = {};
            const parsed = JSON.parse(text);
            for (const key in parsed)
                roles[key.replace(/_(\w)/g, (_, c) => c.toUpperCase())] = parsed[key];
            loaded = roles;
        } catch (e) {
            // Mid-write or malformed: keep the colours already up rather
            // than flashing back to the defaults.
            console.warn(`palette: ${colorsPath}: ${e}`);
        }
    }

    FileView {
        id: colorsFile

        path: root.colorsPath

        // Picks up edits in place. A switcher that repoints a symlink
        // somewhere up the path goes unseen by the watch, so it should
        // also call the reload below.
        watchChanges: true
        onFileChanged: reload()

        onLoaded: root.load(text())

        // No file is a normal state -- the defaults apply -- not an error.
        printErrors: false
        onLoadFailed: root.loaded = {}
    }

    //   qs -p ~/morph-shell ipc call palette reload
    IpcHandler {
        target: "palette"

        function reload(): void {
            colorsFile.reload();
        }
    }

    readonly property QtObject font: QtObject {
        readonly property string family: "JetBrains Mono"
        readonly property int small: 13
        readonly property int normal: 15
        readonly property int large: 19

        // Google's icon font, variable on FILL/GRAD/opsz/wght. Every
        // glyph is drawn on the same square, so icons at one size line
        // up with each other whatever they depict.
        readonly property string material: "Material Symbols Rounded"

        // Icon sizes, kept apart from the text sizes: a glyph reads
        // smaller than type set at the same pixel size, so they do not
        // share a scale.
        readonly property QtObject icon: QtObject {
            readonly property int small: 17
            readonly property int normal: 20
            readonly property int large: 28
        }
    }

    // Material 3 Expressive motion. Spatial curves overshoot slightly and
    // settle; effects curves do not. Durations are paired with them.
    readonly property QtObject anim: QtObject {
        readonly property QtObject durations: QtObject {
            readonly property int fastSpatial: 350
            readonly property int defaultSpatial: 500
            readonly property int slowSpatial: 650
            readonly property int fastEffects: 150
            readonly property int defaultEffects: 200
            readonly property int slowEffects: 300
            readonly property int standard: 400
        }

        readonly property var fastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property var defaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property var slowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
        readonly property var fastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
        readonly property var defaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
        readonly property var slowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
        readonly property var standard: [0.2, 0, 0, 1, 1, 1]
        readonly property var emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
    }

    readonly property QtObject bar: QtObject {
        readonly property int height: 34

        // Inset from the screen edges while floating.
        readonly property int margin: 8

        // Space either side of each widget's content. Neighbours touch,
        // so this is also half the gap between them -- and the hover and
        // click target reaches this far past the glyph.
        readonly property int itemPadding: 8

        // Strip at the very top edge that reveals the bar on hover. Runs
        // down to the bar's top edge so the pointer never falls through a
        // dead gap on its way there.
        readonly property int reveal: margin + 1

        // Dwell before revealing, so a cursor sweeping past the screen
        // edge does not flash the bar open, and a grace period before
        // retracting so brushing just outside does not snap it shut.
        readonly property int openDelay: 90
        readonly property int closeDelay: 220
    }

    readonly property QtObject dock: QtObject {
        readonly property int height: 58

        // Inset from the screen edges while floating, as the bar is.
        readonly property int margin: 8

        // Strip at the very bottom edge that reveals the dock on hover,
        // running up to the dock's own edge so the pointer never falls
        // through a dead gap on its way there.
        readonly property int reveal: margin + 1

        readonly property int openDelay: 90
        readonly property int closeDelay: 220

        readonly property int iconSize: 38

        // Which applications sit in the dock, by desktop entry id -- the
        // .desktop file's name without the suffix. Exact ids are matched
        // first and near misses are looked up heuristically, so "code"
        // finds code-url-handler. An id nothing answers to is skipped
        // rather than drawn as a hole.
        //
        // This is content rather than appearance, and belongs in a config
        // of its own once there is more than one thing to put there.
        readonly property var pinned: ["firefox", "kitty", "code", "spotify", "org.gnome.Nautilus", "discord-canary"]

        // What the dock grows into. The width is the panel's; the height
        // is everything above the pinned row, which stays put.
        readonly property int launcherWidth: 520
        readonly property int resultHeight: 48
        readonly property int maxResults: 7

        // Derived rather than picked, so the panel always ends on a whole
        // row. A height chosen by eye leaves a row sliced through the
        // middle at the bottom edge, which reads as the list being cut
        // off rather than as more of it being below.
        //
        // Top padding, the search field, the gap under it, the rows and
        // the gaps between them, and a breath before the pinned icons.
        readonly property int launcherHeight: 16 + resultHeight + 8 + maxResults * resultHeight + (maxResults - 1) * 4 + 8
    }

    readonly property QtObject osd: QtObject {
        // How long the volume OSD stays up after the level last moved.
        readonly property int timeout: 1500

        // Distance from the bottom edge. Clears the dock, revealed or
        // not, so the two never sit on top of each other.
        readonly property int margin: dock.margin + dock.height + 12
    }

    readonly property QtObject media: QtObject {
        // The players the media panel offers to start when nothing is
        // playing, by desktop entry id, as for the dock's pinned apps.
        readonly property var launchers: ["spotify"]
    }

    // Token scale, matching caelestia's: 4, 8, 12, 16, 20, 28, 32, 48.
    readonly property QtObject rounding: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
        readonly property int extraLargeIncreased: 32
        readonly property int extraExtraLarge: 48
    }

    readonly property QtObject padding: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
        readonly property int extraLargeIncreased: 32
        readonly property int extraExtraLarge: 48
    }

    readonly property QtObject spacing: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 28
        readonly property int extraLargeIncreased: 32
        readonly property int extraExtraLarge: 48
    }

    readonly property QtObject border: QtObject {
        readonly property int thickness: 10
        readonly property int rounding: 25
        readonly property int smoothing: 20
    }

    // Global multiplier on every shape's deformation, as theirs is.
    readonly property real deformScale: 1
}
