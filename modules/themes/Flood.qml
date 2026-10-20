pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// One screen's share of a theme being applied: the chosen drop, grown
// until it covers the screen and then drained back into itself.
//
// The drop is one circle across every screen, in global coordinates, so
// on a screen beside the switcher it arrives from that side a moment
// later, as a wave crossing over, and leaves it first on the way back.
Item {
    id: root

    required property ThemePicker picker
    required property ShellScreen screen

    readonly property ThemePalette tones: picker.tones

    readonly property real centreX: picker.origin.x - screen.x
    readonly property real centreY: picker.origin.y - screen.y
    readonly property real radius: picker.dropRadius + picker.flood * (picker.reach - picker.dropRadius)

    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    visible: picker.flooding

    // The flood's edge: a band of the theme's primary leading the way
    // out and trailing it back in.
    Rectangle {
        x: root.centreX - root.radius
        y: root.centreY - root.radius
        width: root.radius * 2
        height: root.radius * 2
        radius: root.radius

        color: root.tones.m3primary
        scale: root.picker.pop
    }

    // Behind the edge, the body of it, deepening from the primary into
    // its container: still the theme's own colour, rather than a sheet
    // of surface, while chromix works under it.
    Rectangle {
        readonly property real band: Math.min(120, root.radius * 0.3)
        readonly property real r: Math.max(0, root.radius - band)

        x: root.centreX - r
        y: root.centreY - r
        width: r * 2
        height: r * 2
        radius: r

        visible: r > 0
        color: root.mix(root.tones.m3primary, root.tones.m3primaryContainer, root.picker.tint)
        scale: root.picker.pop
    }
}
