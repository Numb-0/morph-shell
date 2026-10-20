pragma Singleton

import QtQuick
import Quickshell

// The shell's design tokens: type, motion, and the rounding, padding and
// spacing scales every module draws with. What each module does with
// them -- its sizes, delays and behaviour -- is in Config; the colours
// are in Colours.
Singleton {
    id: root

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
