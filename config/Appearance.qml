pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property QtObject palette: QtObject {
        readonly property color background: "#1e1e2e"
        readonly property color surface: "#313244"
        readonly property color text: "#cdd6f4"
        readonly property color subtext: "#bac2de"
        readonly property color primary: "#89b4fa"

        // Borders and the off state of controls: the unchecked switch,
        // an unfocused field.
        readonly property color outline: "#6c7086"

        // States. Warning and error carry the battery as it drains;
        // success calls out charging.
        readonly property color success: "#a6e3a1"
        readonly property color warning: "#f9e2af"
        readonly property color error: "#f38ba8"
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
