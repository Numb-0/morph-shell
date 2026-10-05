import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Morph.Blobs
import qs.components
import qs.config
import qs.modules.dock.components
import qs.services

// The dock, and the panels it turns into: the launcher, and the
// clipboard history it leads to through ":cliphist".
//
// One shape does every job: closed it is a pill of pinned icons at the
// bottom edge, and opening a panel grows that same pill upwards into
// it, with the icons staying exactly where they were. Nothing appears
// or disappears -- the dock changes form, and going from one panel
// straight to the other only swaps what is inside.
Scope {
    id: root

    // One panel for the session rather than one per screen: two open at
    // once would each be holding the keyboard. Which one is open --
    // "launcher" or "clipboard" -- and the name of the screen it is open
    // on, or "" for both when the dock is closed.
    property string panel: ""
    property string panelScreen: ""

    function open(name: string, screen: string): void {
        panel = name;
        panelScreen = screen;
    }

    // Only puts away the panel it names, so a stray `launcher close`
    // from a keybind leaves the clipboard be.
    function close(name: string): void {
        if (name !== "" && name !== panel)
            return;
        panel = "";
        panelScreen = "";
    }

    // The same panel on the same screen closes; anything else opens, so
    // the clipboard's key pressed over the launcher turns one into the
    // other.
    function toggle(name: string, screen: string): void {
        if (panel === name && panelScreen === screen)
            close(name);
        else
            open(name, screen);
    }

    // Where a key opens it: the focused monitor on Hyprland, and the
    // first screen anywhere else, where there is no focus to ask about.
    readonly property bool onHyprland: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== null

    readonly property string focusedScreen: Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? ""

    // So a key can open it. The compositor side is one line, e.g. in
    // hyprland.conf:
    //
    //   bind = SUPER, Space, exec, qs -p ~/morph-shell ipc call launcher toggle
    IpcHandler {
        target: "launcher"

        // From a key, the launcher opens on the focused screen.
        function toggle(): void {
            root.toggle("launcher", root.focusedScreen);
        }

        function open(): void {
            root.open("launcher", root.focusedScreen);
        }

        function close(): void {
            root.close("launcher");
        }
    }

    //   bind = SUPER, V, exec, qs -p ~/morph-shell ipc call clipboard toggle
    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            if (Clipboard.available)
                root.toggle("clipboard", root.focusedScreen);
        }

        function open(): void {
            if (Clipboard.available)
                root.open("clipboard", root.focusedScreen);
        }

        function close(): void {
            root.close("clipboard");
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            readonly property int dockMargin: Appearance.dock.margin
            readonly property int dockHeight: Appearance.dock.height

            readonly property bool panelOpen: root.panelScreen === modelData.name
            readonly property bool launcherOpen: panelOpen && root.panel === "launcher"
            readonly property bool clipboardOpen: panelOpen && root.panel === "clipboard"

            // How many pinned icons the pointer is on. A count rather
            // than a flag because the icons come out of a Repeater and
            // cannot be named one by one -- but the reason they have to
            // be counted at all is the bar's: a child handler takes the
            // hover for itself, leaving the hit area's false, which
            // would retract the dock the moment you point at one of its
            // own icons.
            property int hoveredApps: 0

            // Everything hoverable that sits inside the hit area is OR'd
            // in here. The panels' own insides are not: while one is
            // open the dock is held out anyway.
            readonly property bool pointerInside: revealHover.hovered || launcherButton.hovered || pin.hovered || hoveredApps > 0

            // Latched rather than bound straight to the pointer, as the
            // bar is, so a cursor crossing the screen edge on its way
            // somewhere else does not flash the dock open and shut.
            property bool revealed: false

            // Pinned, the dock stays up whatever the pointer does.
            readonly property bool shown: revealed || panelOpen || DockState.pinned

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

            // A panel wants the keyboard the moment it opens: it is
            // opened by a key as often as by a click. On Hyprland the
            // focus grab hands it over, so the dock only has to be willing
            // to take it: taking it outright would itself clear the grab.
            // Anywhere else, on-demand focus only arrives with a click, so
            // it is taken outright. Guarded because the attached object
            // exists only on a layer-shell compositor.
            Component.onCompleted: if (this.WlrLayershell !== null)
                this.WlrLayershell.keyboardFocus = Qt.binding(() => !win.panelOpen ? WlrKeyboardFocus.None : root.onHyprland ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)

            // On Hyprland, a click anywhere outside the dock, on any
            // monitor, puts the panel away too.
            HyprlandFocusGrab {
                windows: [win]
                active: win.panelOpen && root.onHyprland

                onCleared: root.close("")
            }

            // Input is limited to the hit area; everything else clicks
            // through. It is a sliver at the screen edge until the
            // pointer is in it, and the dock's whole extent after that --
            // including, while a panel is open, the panel.
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
                // panel away. Handlers on top do not keep a tap from
                // reaching this one too, so it checks where the tap
                // landed: one on a row or a button inside the shape is
                // theirs alone.
                TapHandler {
                    enabled: win.panelOpen

                    onTapped: eventPoint => {
                        if (!surface.contains(hitArea.mapToItem(surface, eventPoint.position)))
                            root.close("");
                    }
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
            // place, and grown upward when a panel is open -- the
            // icons keep their place at the bottom of it either way.
            BlobRect {
                id: surface

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom

                // At rest the dock floats a margin above the edge; at
                // nothing, its whole height below it.
                anchors.bottomMargin: (win.dockMargin + height) * win.reveal - height

                implicitWidth: win.panelOpen ? Appearance.dock.launcherWidth : row.implicitWidth + Appearance.padding.large * 2
                implicitHeight: win.dockHeight + (win.panelOpen ? Appearance.dock.launcherHeight : 0)

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

            // Clipped to the shape, so the search fields and the lists
            // cannot spill out of it while it is still growing. Both
            // panels sit in it, one on top of the other, and each fades
            // in and out with its own `active`.
            Item {
                x: surface.x
                y: surface.y
                width: surface.width
                height: Math.max(0, surface.height - win.dockHeight)

                clip: true

                opacity: win.panelOpen ? 1 : 0
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

                    enabled: win.launcherOpen
                    active: win.launcherOpen

                    onDismissed: root.close("launcher")

                    // ":cliphist" and the like: the dock turns from one
                    // panel into the other where it stands.
                    onPanelRequested: panel => root.open(panel, win.modelData.name)
                }

                ClipboardPanel {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.large
                    anchors.bottomMargin: Appearance.spacing.small

                    // Only the open one takes the pointer, so the rows
                    // of the other, fading out on top or underneath,
                    // never catch a hover or a tap meant for it.
                    enabled: win.clipboardOpen

                    active: win.clipboardOpen

                    onDismissed: root.close("clipboard")
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

                DockButton {
                    id: launcherButton

                    icon: "apps"
                    active: win.launcherOpen

                    onTapped: root.toggle("launcher", win.modelData.name)
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
