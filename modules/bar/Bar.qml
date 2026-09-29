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
        readonly property bool bluetoothOpen: openPanel === "bluetooth"
        readonly property bool sessionOpen: openPanel === "session"
        readonly property bool notificationsOpen: openPanel === "notifications"

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
        readonly property bool pointerInside: revealHover.hovered || clock.hovered || clockPopup.hovered || media.hovered || mediaPopup.hovered || profile.hovered || volume.hovered || volumePopup.hovered || brightness.hovered || brightnessPopup.hovered || battery.hovered || batteryPopup.hovered || network.hovered || networkPopup.hovered || bluetooth.hovered || bluetoothPopup.hovered || notifications.hovered || notificationsPopup.hovered || session.hovered || sessionPopup.hovered

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
        //
        // The panels are drawn inside this surface, so it runs the full
        // height of the screen: a fixed height clipped the bottom off the
        // taller ones. The mask keeps the empty part clicking through.
        // Sized once rather than to the open panel, since a layer surface
        // resize waits on the compositor and would stall the animation.
        implicitHeight: modelData.height
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

            Region {
                item: bluetoothPopup.maskItem
            }

            Region {
                item: sessionPopup.maskItem
            }

            Region {
                item: notificationsPopup.maskItem
            }

            Region {
                item: dismissArea
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

        // Closes the open panel, and the bar with it, on a click anywhere
        // else. While a panel is open it spans the whole surface and is
        // part of the mask, so the rest of the screen stops clicking
        // through; it sits below everything else, so the bar and the
        // panel still get their own clicks first. The click that closes
        // is swallowed rather than passed on to the window underneath.
        MouseArea {
            id: dismissArea

            width: win.openPanel !== "" ? win.width : 0
            height: win.openPanel !== "" ? win.height : 0

            acceptedButtons: Qt.AllButtons
            onPressed: mouse => {
                // Empty space on the bar itself is not outside it.
                if (mouse.y < hitArea.height)
                    return;

                openTimer.stop();
                closeTimer.stop();
                win.revealed = false;
                win.openPanel = "";
            }
        }

        // Every blob on this screen shares one group, so the bar and
        // anything growing out of it render as a single shape.
        BlobGroup {
            id: group

            color: Appearance.palette.m3surfaceContainer
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

        BluetoothPopup {
            id: bluetoothPopup

            group: group
            anchor: bluetooth
            anchorBottom: surface.y + surface.height

            // Never reachable without an adapter, since the widget that
            // opens it is not drawn either.
            open: win.bluetoothOpen && Bt.available
        }

        NotificationsPopup {
            id: notificationsPopup

            group: group
            anchor: notifications
            anchorBottom: surface.y + surface.height
            open: win.notificationsOpen
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

        SessionPopup {
            id: sessionPopup

            group: group
            anchor: session
            anchorBottom: surface.y + surface.height
            open: win.sessionOpen

            onFinished: win.openPanel = ""
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
        Logo {
            id: logo

            anchors.left: parent.left
            anchors.leftMargin: win.barMargin + Appearance.padding.small

            y: surface.y + (surface.height - height) / 2

            opacity: win.reveal
        }

        Clock {
            id: clock

            anchors.horizontalCenter: parent.horizontalCenter
            y: surface.y + (surface.height - height) / 2

            opacity: win.reveal

            onClicked: win.toggle("clock")
        }

        Media {
            id: media

            anchors.left: logo.right
            anchors.leftMargin: Appearance.spacing.normal

            y: surface.y + (surface.height - height) / 2

            opacity: win.reveal

            onClicked: win.toggle("media")
        }

        Profile {
            id: profile

            anchors.left: media.right

            y: surface.y + (surface.height - height) / 2

            // A machine without power-profiles-daemon has nothing to
            // switch, so the widget is not drawn at all.
            visible: Profiles.available

            opacity: win.reveal
        }

        // The status widgets sit at the far end of the bar, inside the
        // surface's own margin: session, battery, volume, backlight,
        // network, Bluetooth, notifications, reading outward from the edge.
        Session {
            id: session

            anchors.right: parent.right
            anchors.rightMargin: win.barMargin + Appearance.padding.small

            y: surface.y + (surface.height - height) / 2

            active: win.sessionOpen
            opacity: win.reveal

            onClicked: win.toggle("session")
        }

        Battery {
            id: battery

            anchors.right: session.left

            y: surface.y + (surface.height - height) / 2

            // A desktop has nothing to say here, and UPower's display
            // device would otherwise sit in the bar reading 0%.
            visible: Power.available

            opacity: win.reveal

            onClicked: win.toggle("battery")
        }

        Volume {
            id: volume

            // Falls back to the session button on a machine with no
            // battery, rather than hanging off a widget that is not there.
            anchors.right: battery.visible ? battery.left : session.left

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

        Bluetooth {
            id: bluetooth

            anchors.right: network.left

            y: surface.y + (surface.height - height) / 2

            // A machine without an adapter, or without bluetoothd
            // running, has nothing to show here.
            visible: Bt.available

            opacity: win.reveal

            onClicked: win.toggle("bluetooth")
        }

        Notifications {
            id: notifications

            anchors.right: bluetooth.visible ? bluetooth.left : network.left

            y: surface.y + (surface.height - height) / 2

            active: win.notificationsOpen
            opacity: win.reveal

            onClicked: win.toggle("notifications")
        }
    }
}
