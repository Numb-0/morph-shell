import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Morph.Blobs
import qs.components
import qs.config
import qs.modules.dock.components
import qs.services

// The dock, and the launcher it turns into.
//
// One shape does both jobs: closed it is a pill of pinned icons at the
// bottom edge, and opening the launcher grows that same pill upwards
// into a panel, with the icons staying exactly where they were. Nothing
// appears or disappears -- the dock changes form.
Scope {
    id: root

    // One launcher for the session rather than one per screen: two open
    // at once would each be holding the keyboard.
    property bool launcherOpen: false

    // So a key can open it. The compositor side is one line, e.g. in
    // hyprland.conf:
    //
    //   bind = SUPER, Space, exec, qs -p ~/morph-shell ipc call launcher toggle
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.launcherOpen = !root.launcherOpen;
        }

        function open(): void {
            root.launcherOpen = true;
        }

        function close(): void {
            root.launcherOpen = false;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            readonly property int dockMargin: Appearance.dock.margin
            readonly property int dockHeight: Appearance.dock.height

            readonly property bool launcherOpen: root.launcherOpen

            // How many pinned icons the pointer is on. A count rather
            // than a flag because the icons come out of a Repeater and
            // cannot be named one by one -- but the reason they have to
            // be counted at all is the bar's: a child handler takes the
            // hover for itself, leaving the hit area's false, which
            // would retract the dock the moment you point at one of its
            // own icons.
            property int hoveredApps: 0

            // Everything hoverable that sits inside the hit area is OR'd
            // in here. The launcher's own insides are not: while it is
            // open the dock is held out anyway.
            readonly property bool pointerInside: revealHover.hovered || buttonHover.hovered || pin.hovered || hoveredApps > 0

            // Latched rather than bound straight to the pointer, as the
            // bar is, so a cursor crossing the screen edge on its way
            // somewhere else does not flash the dock open and shut.
            property bool revealed: false

            // Pinned, the dock stays up whatever the pointer does.
            readonly property bool shown: revealed || launcherOpen || DockState.pinned

            property real reveal: shown ? 1 : 0

            Behavior on reveal {
                Anim {
                    type: Anim.Emphasized
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

                interval: Appearance.dock.openDelay
                onTriggered: win.revealed = true
            }

            Timer {
                id: closeTimer

                interval: Appearance.dock.closeDelay
                onTriggered: win.revealed = false
            }

            screen: modelData
            color: "transparent"

            // Floats over everything and reserves nothing, so windows lay
            // out as if the dock were not there -- unless it is pinned,
            // when it keeps its own strip of the screen and windows tile
            // above it rather than under it.
            implicitHeight: dockMargin + dockHeight + Appearance.dock.launcherHeight + 60
            exclusiveZone: DockState.pinned ? dockMargin + dockHeight : 0

            anchors {
                bottom: true
                left: true
                right: true
            }

            // The launcher wants the keyboard outright: it is opened by a
            // key as often as by a click, and on-demand focus only
            // arrives with a click. Guarded because the attached object
            // exists only on a layer-shell compositor.
            Component.onCompleted: if (this.WlrLayershell !== null)
                this.WlrLayershell.keyboardFocus = Qt.binding(() => win.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None)

            // Input is limited to the hit area; everything else clicks
            // through. It is a sliver at the screen edge until the
            // pointer is in it, and the dock's whole extent after that --
            // including, while the launcher is open, the panel.
            mask: Region {
                item: hitArea
            }

            // Only ever grows under a pointer already inside and shrinks
            // away from one already outside, so the geometry change can
            // never flip the hover that caused it.
            Item {
                id: hitArea

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right

                height: win.pointerInside || win.shown ? win.dockMargin + surface.height : Appearance.dock.reveal

                HoverHandler {
                    id: revealHover
                }

                // A click in the hit area but outside the shape puts the
                // launcher away. Sits under the shape, so the icons and
                // the results get the tap first.
                TapHandler {
                    enabled: win.launcherOpen

                    onTapped: root.launcherOpen = false
                }
            }

            // Every blob on this screen's dock shares one group. The bar
            // has its own: they are at opposite edges and must never
            // reach for each other.
            BlobGroup {
                id: group

                color: Appearance.palette.m3surfaceContainer
                smoothing: Appearance.border.smoothing
            }

            // The shape. Parked below the screen edge when hidden, so it
            // slides up into its floating position rather than fading in
            // place, and grown upward when the launcher is open -- the
            // icons keep their place at the bottom of it either way.
            BlobRect {
                id: surface

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom

                // At rest the dock floats a margin above the edge; at
                // nothing, its whole height below it.
                anchors.bottomMargin: (win.dockMargin + height) * win.reveal - height

                implicitWidth: win.launcherOpen ? Appearance.dock.launcherWidth : row.implicitWidth + Appearance.padding.large * 2
                implicitHeight: win.dockHeight + (win.launcherOpen ? Appearance.dock.launcherHeight : 0)

                group: group
                radius: Appearance.rounding.extraLarge

                // The morph itself. Rides the emphasized curve rather than
                // a spatial one, so the shape settles without overshooting
                // and wobbling back.
                Behavior on implicitWidth {
                    Anim {
                        type: Anim.Emphasized
                    }
                }

                Behavior on implicitHeight {
                    Anim {
                        type: Anim.Emphasized
                    }
                }
            }

            // Clipped to the shape, so the search field and the list
            // cannot spill out of it while it is still growing.
            Item {
                x: surface.x
                y: surface.y
                width: surface.width
                height: Math.max(0, surface.height - win.dockHeight)

                clip: true

                opacity: win.launcherOpen ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                Launcher {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large

                    // Stops short of the pinned row rather than running
                    // into it.
                    anchors.bottomMargin: Appearance.spacing.small

                    active: win.launcherOpen

                    onDismissed: root.launcherOpen = false
                }
            }

            // The pinned row, centred in the bottom band of the shape
            // whatever the shape is currently doing.
            Row {
                id: row

                x: surface.x + (surface.width - width) / 2
                y: surface.y + surface.height - win.dockHeight / 2 - height / 2

                spacing: Appearance.spacing.small
                opacity: win.reveal

                // Opens and closes the launcher -- the same thing the
                // keybind does.
                Item {
                    id: launcherButton

                    implicitWidth: Appearance.dock.iconSize + Appearance.padding.small * 2
                    implicitHeight: Appearance.dock.iconSize + Appearance.padding.small * 2

                    HoverHandler {
                        id: buttonHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.launcherOpen = !root.launcherOpen
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent

                        icon: "apps"
                        size: Appearance.font.icon.large
                        color: win.launcherOpen || buttonHover.hovered ? Appearance.palette.m3primary : Appearance.palette.m3onSurface

                        // Fills while the launcher is open, so the button
                        // shows the state it put the dock in.
                        fill: win.launcherOpen ? 1 : 0
                    }
                }

                // Divides the button from the applications it opens.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter

                    implicitWidth: 1
                    implicitHeight: Appearance.dock.iconSize * 0.6

                    color: Appearance.palette.m3onSurfaceVariant
                    opacity: 0.25
                }

                Repeater {
                    // An id nothing answers to is dropped rather than
                    // drawn as a gap, so a pin for something that is not
                    // installed costs nothing.
                    //
                    // Reads Apps.all first so the binding depends on it:
                    // byId is a plain call that notifies nothing, and at
                    // startup the entries are not indexed yet, so without
                    // this every pin resolves to null once and the row
                    // stays empty for good.
                    model: {
                        Apps.all;
                        return Appearance.dock.pinned.map(id => Apps.byId(id)).filter(entry => entry !== null);
                    }

                    DockApp {
                        required property var modelData

                        entry: modelData

                        onHoveredChanged: win.hoveredApps += hovered ? 1 : -1
                    }
                }

                // Divides the applications from the pin, as the launcher
                // button is divided from them.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter

                    implicitWidth: 1
                    implicitHeight: Appearance.dock.iconSize * 0.6

                    color: Appearance.palette.m3onSurfaceVariant
                    opacity: 0.25
                }

                // Holds the dock up, as the bar's pin holds the bar down.
                Pin {
                    id: pin

                    anchors.verticalCenter: parent.verticalCenter

                    pinned: DockState.pinned
                    size: Appearance.font.icon.large

                    onToggled: DockState.togglePinned()
                }
            }
        }
    }
}
