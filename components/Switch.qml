import QtQuick
import qs.config

// A Material 3 switch: an outlined track with a small handle when off,
// a filled track with a large handle carrying a check when on. The
// handle swells further while pressed, as M3's does.
//
// Drawn rather than taken from Controls, for the same reason the
// launcher's field is: a styled control arrives with a theme to undo.
Item {
    id: root

    property bool checked: false

    // Emitted with the state asked for; `checked` is left to whoever
    // owns the value, so a switch bound to something external never
    // disagrees with it.
    signal toggled(checked: bool)

    implicitWidth: 52
    implicitHeight: 32

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        onTapped: root.toggled(!root.checked)
    }

    Rectangle {
        anchors.fill: parent

        radius: height / 2
        color: root.checked ? Appearance.palette.m3primary : Appearance.palette.m3surfaceContainerHighest
        border.width: root.checked ? 0 : 2
        border.color: Appearance.palette.m3outline

        Behavior on color {
            CAnim {}
        }
    }

    Rectangle {
        id: handle

        property real diameter: tap.pressed ? 28 : root.checked ? 24 : 16

        // Centred on one of two fixed points, so the handle grows about
        // its middle rather than from a corner.
        property real centre: root.checked ? root.width - root.height / 2 : root.height / 2

        x: centre - width / 2
        y: (root.height - height) / 2
        width: diameter
        height: diameter

        radius: diameter / 2
        color: root.checked ? Appearance.palette.m3onPrimary : Appearance.palette.m3outline

        Behavior on centre {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on diameter {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on color {
            CAnim {}
        }

        // The state layer: a soft disc around the handle on hover.
        Rectangle {
            anchors.centerIn: parent

            width: 40
            height: 40
            radius: 20

            color: root.checked ? Appearance.palette.m3primary : Appearance.palette.m3onSurface
            opacity: hover.hovered ? 0.12 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }

        // Coloured as the track rather than onPrimaryContainer, as M3
        // has it: a scheme is free to make that role black (content and
        // fidelity schemes do), which vanishes on the dark handle, while
        // primary always stands off onPrimary.
        MaterialSymbol {
            anchors.centerIn: parent

            icon: "check"
            size: Appearance.font.icon.small - 1
            weight: 600
            color: Appearance.palette.m3primary

            opacity: root.checked ? 1 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }
        }
    }
}
