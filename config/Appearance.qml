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
    }

    readonly property QtObject font: QtObject {
        readonly property string family: "JetBrains Mono"
        readonly property int small: 13
        readonly property int normal: 15
        readonly property int large: 19
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
