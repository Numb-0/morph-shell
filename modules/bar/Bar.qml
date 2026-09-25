import QtQuick
import Quickshell
import Morph.Blobs
import qs.components
import qs.config
import qs.modules.bar.components

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        // Toggled by clicking the clock, as caelestia's BlobPopup does.
        property bool clockOpen: false

        readonly property int barHeight: Appearance.bar.height

        screen: modelData
        color: "transparent"

        // Taller than the bar so panels have somewhere to grow into; only
        // the bar itself is reserved from the compositor.
        implicitHeight: 420
        exclusiveZone: barHeight

        anchors {
            top: true
            left: true
            right: true
        }

        // Input is limited to the bar and whatever panel is open;
        // everything else clicks through to the window underneath.
        mask: Region {
            item: surface

            Region {
                item: clockPopup.maskItem
            }
        }

        // Every blob on this screen shares one group, so the bar surface
        // and anything growing out of it render as a single shape.
        BlobGroup {
            id: group

            color: Appearance.palette.surface

            // The panel grows out of the bar rather than floating beside
            // it, so blend hard and let corners fill -- the same choice
            // caelestia makes for its frame and panels.
            smoothing: Appearance.border.smoothing

            // Behavior on color {
            //     CAnim {}
            // }
        }

        // Panels come first so the bar surface below occludes them and
        // they read as sliding out from underneath it.
        ClockPopup {
            id: clockPopup

            group: group
            anchor: clock
            anchorBottom: win.barHeight
            open: win.clockOpen
        }

        BlobRect {
            id: surface

            anchors.left: parent.left
            anchors.right: parent.right

            // Pushed up by its own radius so the top corners round
            // off-screen and the bar stays flush with the screen edge.
            y: -radius
            height: win.barHeight + radius

            group: group

            // Square: this is a full-width bar flush to both screen
            // edges, not caelestia's screen-surrounding frame, so their
            // border.rounding of 25 would curve almost the bar's whole
            // height at each end.
            radius: 0
        }

        // Bar widgets last, on top of the surface.
        Clock {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: (win.barHeight - height) / 2

            onClicked: win.clockOpen = !win.clockOpen
        }
    }
}
