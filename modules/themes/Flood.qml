pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.config

// One screen's share of a theme being applied: the screen held still as
// it was, then wiped away in a circle that grows from the tile Apply was
// pressed on, the re-themed desktop showing through it.
//
// The circle is one circle across every screen, in global coordinates,
// so on a screen beside the card it arrives from that side a moment
// later, as a wave crossing over.
Item {
    id: root

    required property ThemePicker picker
    required property ShellScreen screen

    readonly property real centreX: picker.origin.x - screen.x
    readonly property real centreY: picker.origin.y - screen.y
    readonly property real radius: picker.reveal * picker.reach

    Loader {
        anchors.fill: parent

        active: root.picker.frozen

        sourceComponent: Item {
            // What has been wiped away so far.
            Item {
                id: hole

                anchors.fill: parent

                visible: false
                layer.enabled: true

                Rectangle {
                    x: root.centreX - root.radius
                    y: root.centreY - root.radius
                    width: root.radius * 2
                    height: root.radius * 2
                    radius: root.radius

                    color: "white"
                }
            }

            // Captured as it loads, once the card has gone, so the still
            // is the desktop as it was before the switch. Drawn through
            // its own layer with the hole cut out of it: a ScreencopyView
            // hidden and handed to an effect as a source draws nothing.
            ScreencopyView {
                id: still

                anchors.fill: parent

                captureSource: root.screen
                live: false
                visible: hasContent

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: hole
                    maskInverted: true
                }

                onHasContentChanged: {
                    if (hasContent)
                        root.picker.captured();
                }
            }

            // The wavefront: a soft band of the new primary with a crisp
            // edge inside it, thinning out as the wave spreads. Drawn in
            // the shell's own palette, which is the new one by the time
            // the circle grows.
            Repeater {
                model: [
                    {
                        width: 28,
                        alpha: 0.22
                    },
                    {
                        width: 3,
                        alpha: 0.9
                    }
                ]

                Rectangle {
                    required property var modelData

                    readonly property real r: root.radius + modelData.width / 2

                    x: root.centreX - r
                    y: root.centreY - r
                    width: r * 2
                    height: r * 2
                    radius: r

                    visible: root.picker.revealing && root.radius > 0

                    color: "transparent"
                    border.width: modelData.width
                    border.color: Colours.palette.m3primary
                    opacity: modelData.alpha * (1 - root.picker.reveal)
                }
            }
        }
    }
}
