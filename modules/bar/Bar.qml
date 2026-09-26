import QtQuick
import Quickshell
import Quickshell.Wayland
import Morph.Blobs
import qs.components
import qs.config
import qs.modules.bar.components
import qs.services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        // Which panel is open, if any. One at a time: they share a blob
        // group, so two open at once would blend into each other.
        property string openPanel: ""

        readonly property bool clockOpen: openPanel === "clock"
        readonly property bool mediaOpen: openPanel === "media"
        readonly property bool volumeOpen: openPanel === "volume"
        readonly property bool batteryOpen: openPanel === "battery"
        readonly property bool brightnessOpen: openPanel === "brightness"
        readonly property bool networkOpen: openPanel === "network"

        function toggle(panel: string): void {
            openPanel = openPanel === panel ? "" : panel;
        }

        readonly property int barHeight: Appearance.bar.height
        readonly property int barMargin: Appearance.bar.margin

        // Anything hoverable that sits inside the hit area has to be
        // OR'd in here. A child HoverHandler can take the hover for
        // itself, leaving the outer one false, which would retract the
        // bar the moment you point at one of its own widgets. Add new bar
        // widgets to this list.
        readonly property bool pointerInside: revealHover.hovered || clock.hovered || clockPopup.hovered || media.hovered || mediaPopup.hovered || volume.hovered || volumePopup.hovered || brightness.hovered || brightnessPopup.hovered || battery.hovered || batteryPopup.hovered || network.hovered || networkPopup.hovered

        // Latched rather than bound straight to the pointer, so a cursor
        // crossing the screen edge on its way somewhere else does not
        // flash the bar open and shut.
        property bool revealed: false

        readonly property bool shown: revealed || openPanel !== ""

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

        // The keyboard only while the network panel is asking for a
        // password, and then outright, so the field takes typing the
        // moment it appears. The rest of the time the bar never holds
        // it. Guarded, as the dock's is, because the attached object
        // exists only on a layer-shell compositor.
        Component.onCompleted: if (this.WlrLayershell !== null)
            this.WlrLayershell.keyboardFocus = Qt.binding(() => win.networkOpen && Net.passwordNetwork !== null ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None)

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

            Region {
                item: mediaPopup.maskItem
            }

            Region {
                item: volumePopup.maskItem
            }

            Region {
                item: batteryPopup.maskItem
            }

            Region {
                item: brightnessPopup.maskItem
            }

            Region {
                item: networkPopup.maskItem
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

        MediaPopup {
            id: mediaPopup

            group: group
            anchor: media
            anchorBottom: surface.y + surface.height
            open: win.mediaOpen
        }

        VolumePopup {
            id: volumePopup

            group: group
            anchor: volume
            anchorBottom: surface.y + surface.height
            open: win.volumeOpen
        }

        BrightnessPopup {
            id: brightnessPopup

            group: group
            anchor: brightness
            anchorBottom: surface.y + surface.height

            // Never reachable without a backlight, since the widget that
            // opens it is not drawn either.
            open: win.brightnessOpen && Backlight.available
        }

        NetworkPopup {
            id: networkPopup

            group: group
            anchor: network
            anchorBottom: surface.y + surface.height
            open: win.networkOpen
        }

        BatteryPopup {
            id: batteryPopup

            group: group
            anchor: battery
            anchorBottom: surface.y + surface.height

            // Never reachable without a battery, since the widget that
            // opens it is not drawn either.
            open: win.batteryOpen && Power.available
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

            onClicked: win.toggle("clock")
        }

        Media {
            id: media

            anchors.right: clock.left
            anchors.rightMargin: Appearance.spacing.large

            y: surface.y + (surface.height - height) / 2

            opacity: win.reveal

            onClicked: win.toggle("media")
        }

        // The status widgets sit at the far end of the bar, inside the
        // surface's own margin: battery, volume, backlight, network,
        // reading outward from the edge.
        Battery {
            id: battery

            anchors.right: parent.right
            anchors.rightMargin: win.barMargin + Appearance.padding.small

            y: surface.y + (surface.height - height) / 2

            // A desktop has nothing to say here, and UPower's display
            // device would otherwise sit in the bar reading 0%.
            visible: Power.available

            opacity: win.reveal

            onClicked: win.toggle("battery")
        }

        Volume {
            id: volume

            // Falls back to the bar's end on a machine with no battery,
            // rather than hanging off a widget that is not there.
            anchors.right: battery.visible ? battery.left : parent.right
            anchors.rightMargin: battery.visible ? 0 : win.barMargin + Appearance.padding.small

            y: surface.y + (surface.height - height) / 2

            opacity: win.reveal

            onClicked: win.toggle("volume")
        }

        Brightness {
            id: brightness

            anchors.right: volume.left

            y: surface.y + (surface.height - height) / 2

            // A machine whose panel has no software backlight -- a
            // desktop, a monitor driven over DDC -- has nothing to show
            // here.
            visible: Backlight.available

            opacity: win.reveal

            onClicked: win.toggle("brightness")
        }

        Network {
            id: network

            // Hangs off whichever of its neighbours is drawn: the
            // backlight is missing on a desktop.
            anchors.right: brightness.visible ? brightness.left : volume.left

            y: surface.y + (surface.height - height) / 2

            opacity: win.reveal

            onClicked: win.toggle("network")
        }
    }
}
