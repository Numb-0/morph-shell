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
        readonly property int barMargin: Appearance.bar.margin

        // Anything hoverable that sits inside the hit area has to be
        // OR'd in here. A child HoverHandler can take the hover for
        // itself, leaving the outer one false, which would retract the
        // bar the moment you point at one of its own widgets. Add new bar
        // widgets to this list.
        readonly property bool pointerInside: revealHover.hovered || clock.hovered || clockPopup.hovered

        // Latched rather than bound straight to the pointer, so a cursor
        // crossing the screen edge on its way somewhere else does not
        // flash the bar open and shut.
        property bool revealed: false

        readonly property bool shown: revealed || clockOpen

        property real reveal: shown ? 1 : 0

        Behavior on reveal {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        onPointerInsideChanged: {
            if (pointerInside) {
                closeTimer.stop();
                openTimer.restart();
            } else {
                openTimer.stop();
                closeTimer.restart();
            }
        }

        Timer {
            id: openTimer

            interval: Appearance.bar.openDelay
            onTriggered: win.revealed = true
        }

        Timer {
            id: closeTimer

            interval: Appearance.bar.closeDelay
            onTriggered: win.revealed = false
        }

        screen: modelData
        color: "transparent"

        // Floats over everything and reserves nothing, so windows lay out
        // as if the bar were not there.
        implicitHeight: 460
        exclusiveZone: 0

        anchors {
            top: true
            left: true
            right: true
        }

        // Input is limited to the hit area and whatever panel is open;
        // everything else clicks through.
        mask: Region {
            item: hitArea

            Region {
                item: clockPopup.maskItem
            }
        }

        // A thin strip at the screen edge, enlarged to the bar's whole
        // resting extent as soon as the pointer is inside it -- before the
        // dwell has elapsed, so moving inward during the wait does not
        // cancel the reveal. It only ever grows under a pointer already
        // inside and shrinks away from one already outside, so the
        // geometry change can never flip the hover that caused it.
        Item {
            id: hitArea

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            height: revealHover.hovered || win.shown ? win.barMargin + win.barHeight : Appearance.bar.reveal

            HoverHandler {
                id: revealHover
            }
        }

        // Every blob on this screen shares one group, so the bar and
        // anything growing out of it render as a single shape.
        BlobGroup {
            id: group

            color: Appearance.palette.surface
            smoothing: Appearance.border.smoothing
        }

        // Panels come first so the bar occludes them and they read as
        // sliding out from underneath it.
        ClockPopup {
            id: clockPopup

            group: group
            anchor: clock
            anchorBottom: surface.y + surface.height
            open: win.clockOpen
        }

        BlobRect {
            id: surface

            // Parked just above the screen when hidden, so it slides down
            // into its floating position rather than fading in place.
            x: win.barMargin
            y: -height + (win.barMargin + height) * win.reveal
            width: win.width - win.barMargin * 2
            height: win.barHeight

            group: group
            radius: Appearance.rounding.large

            // No squash. At this width even the plugin's default 0.0005
            // pinches ~77px off the bar while it slides, which reads as a
            // glitch rather than as weight.
            deformScale: 0
        }

        // Bar widgets last, on top of the surface.
        Clock {
            id: clock

            anchors.horizontalCenter: parent.horizontalCenter
            y: surface.y + (surface.height - height) / 2

            opacity: win.reveal

            onClicked: win.clockOpen = !win.clockOpen
        }
    }
}
