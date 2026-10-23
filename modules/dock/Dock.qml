import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Morph.Blobs
import qs.components
import qs.config
import qs.modules.dock.components
import qs.services.launcher
import qs.states

// The dock, and the panels it turns into: the launcher, the clipboard
// history and the emoji picker it leads to through ":cliphist" and
// ":emoji", and the chooser between the windows of a pinned app that
// has more than one open.
//
// One shape does every job: closed it is a pill of pinned icons at the
// bottom edge, and opening a panel grows that same pill upwards into
// it, with the icons staying exactly where they were. Nothing appears
// or disappears -- the dock changes form, and going from one panel
// straight to the other only swaps what is inside.
//
// The pins are arranged in the row itself. An icon dragged along it
// takes its place where it is let go, and one dragged up out of the
// dock is unpinned. An app pinned from the launcher opens a gap in the
// row for it, which the pointer or the arrows move, and a click or
// Enter drops it there.
Scope {
    id: root

    // One panel for the session rather than one per screen: two open at
    // once would each be holding the keyboard. Which one is open --
    // "launcher", "clipboard" or "emoji" -- and the name of the screen it is open
    // on, or "" for both when the dock is closed.
    property string panel: ""
    property string panelScreen: ""

    // The app whose windows the chooser lays out. Left set when it
    // closes, so its cards have something to fade out with.
    property var chooserEntry: null

    // A click on an app's icon opens its windows, and a second click on
    // the same icon puts them away again; another app's swaps them over.
    function choose(entry: var, screen: string): void {
        if (panel === "windows" && panelScreen === screen && chooserEntry === entry) {
            close("windows");
            return;
        }
        chooserEntry = entry;
        open("windows", screen);
    }

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

    //   bind = SUPER, Period, exec, qs -p ~/morph-shell ipc call emoji toggle
    IpcHandler {
        target: "emoji"

        function toggle(): void {
            root.toggle("emoji", root.focusedScreen);
        }

        function open(): void {
            root.open("emoji", root.focusedScreen);
        }

        function close(): void {
            root.close("emoji");
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            readonly property int dockMargin: Config.dock.margin
            readonly property int dockHeight: Config.dock.height

            readonly property bool panelOpen: root.panelScreen === modelData.name
            readonly property bool launcherOpen: panelOpen && root.panel === "launcher"
            readonly property bool clipboardOpen: panelOpen && root.panel === "clipboard"
            readonly property bool emojiOpen: panelOpen && root.panel === "emoji"
            readonly property bool windowsOpen: panelOpen && root.panel === "windows"

            // The chooser grows the dock only as far as its cards need,
            // where the search panels share one fixed height.
            // The search panels' size once the shape is fully open.
            readonly property int searchWidth: Config.dock.launcherWidth - Appearance.padding.large * 2
            readonly property int searchHeight: Config.dock.launcherHeight - Appearance.padding.large - Appearance.spacing.small

            readonly property int panelHeight: windowsOpen ? chooser.implicitHeight + Appearance.padding.large : Config.dock.launcherHeight

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

            // The app being given a place in the row, whether it was
            // picked up out of the row or pinned from the launcher, and
            // which gap it would land in -- -1 while a dragged one is
            // up out of the dock, where letting go unpins it.
            property var placing: null
            property bool dragging: false
            property int placeIndex: -1

            // Where the pointer is carrying a dragged one, in the row.
            property point dragPoint

            // Placing from the launcher, which has the row take the
            // keys and the clicks until it is done.
            readonly property bool choosingPlace: placing !== null && !dragging

            // What the row draws: the pins, less one being dragged, and
            // the gap among them.
            readonly property var rowApps: {
                const apps = Apps.pinned.filter(entry => entry !== placing);
                if (placing === null || placeIndex < 0)
                    return apps;
                return [...apps.slice(0, placeIndex), gap, ...apps.slice(placeIndex)];
            }

            // Which gap a point along the row is over, out of so many.
            // Every slot is as wide as any other and the row is as long
            // with the gap as it was before, so this never moves under
            // the pointer as the gap does.
            function slotAt(x: real, count: int): int {
                return Math.max(0, Math.min(count, slotUnder(x)));
            }

            // Unclamped: below 0 is left of the apps, and as many as
            // there are or more is right of them.
            function slotUnder(x: real): int {
                const step = launcherButton.width + row.spacing;
                const start = launcherButton.width + row.spacing + divider.width + row.spacing;
                return Math.floor((x - start + row.spacing / 2) / step);
            }

            function beginPlacing(entry: var): void {
                placing = entry;
                dragging = false;
                placeIndex = Apps.pinned.length;
                placer.forceActiveFocus();
            }

            function finishPlacing(drop: bool): void {
                if (placing === null)
                    return;

                if (drop && placeIndex >= 0)
                    Apps.pin(placing, placeIndex);
                else if (drop && dragging)
                    Apps.unpin(placing);

                const fromLauncher = !dragging;
                placing = null;
                dragging = false;
                placeIndex = -1;

                if (fromLauncher && launcherOpen)
                    launcher.grabFocus();
            }

            // Pressed on a pin and moved: it comes up off the row and
            // follows the pointer, and the others close up around a gap
            // where it would land.
            function beginDrag(at: point): void {
                const index = slotUnder(at.x);
                const entry = Apps.pinned[index];
                if (index < 0 || !entry)
                    return;

                placing = entry;
                dragging = true;
                placeIndex = index;
                dragPoint = at;
            }

            // Up past the top of the row by as much again, it is out.
            function dragTo(at: point): void {
                dragPoint = at;
                placeIndex = at.y < -row.height ? -1 : slotAt(at.x, Apps.pinned.length - 1);
            }

            // So a gap is never left open in the row of a launcher that
            // was put away halfway through.
            onLauncherOpenChanged: if (!launcherOpen && choosingPlace)
                finishPlacing(false)

            // The gap's identity in the row, which the row's model needs
            // to tell from the apps: one object for good, so moving the
            // gap moves it rather than making it anew.
            QtObject {
                id: gap
            }

            // Latched rather than bound straight to the pointer, as the
            // bar is, so a cursor crossing the screen edge on its way
            // somewhere else does not flash the dock open and shut.
            property bool revealed: false

            // Pinned, the dock stays up whatever the pointer does.
            // Held up too while a pin is being placed, or the pointer
            // carrying one off the top would put the dock away under it.
            readonly property bool shown: revealed || panelOpen || DockState.pinned || placing !== null

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

                interval: Config.dock.openDelay
                onTriggered: win.revealed = true
            }

            Timer {
                id: closeTimer

                interval: Config.dock.closeDelay
                onTriggered: win.revealed = false
            }

            screen: modelData
            color: "transparent"

            // Floats over everything and reserves nothing, so windows lay
            // out as if the dock were not there -- unless it is pinned,
            // when it keeps its own strip of the screen and windows tile
            // above it rather than under it.
            implicitHeight: dockMargin + dockHeight + Config.dock.launcherHeight + 60
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

                // The whole window while a pin is dragged, so the pointer
                // carrying it out above the dock is still followed.
                height: win.dragging ? win.height : win.pointerInside || win.shown ? win.dockMargin + surface.height : Config.dock.reveal

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

                color: Colours.palette.m3surfaceContainer
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

                implicitWidth: win.panelOpen ? Config.dock.launcherWidth : row.implicitWidth + Appearance.padding.large * 2
                implicitHeight: win.dockHeight + (win.panelOpen ? win.panelHeight : 0)

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
            //
            // The open one is raised over the rest. Hover goes to the
            // topmost of them that handles it and no further, and the
            // closed ones still do -- faded and disabled, they would
            // keep the pointer from the rows of one underneath.
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
                    id: launcher

                    // At their open size from the start, rather than
                    // filling the shape as it grows: the shape reveals
                    // them, and nothing inside lays itself out afresh on
                    // every frame of the morph. Stops short of the pinned
                    // row rather than running into it.
                    anchors.top: parent.top
                    anchors.topMargin: Appearance.padding.large
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: win.searchWidth
                    height: win.searchHeight

                    enabled: win.launcherOpen
                    active: win.launcherOpen
                    z: win.launcherOpen ? 1 : 0

                    onDismissed: root.close("launcher")

                    // ":cliphist" and the like: the dock turns from one
                    // panel into the other where it stands.
                    onPanelRequested: panel => root.open(panel, win.modelData.name)

                    placing: win.choosingPlace ? win.placing : null
                    onPlaceRequested: entry => win.beginPlacing(entry)
                }

                ClipboardPanel {
                    anchors.top: parent.top
                    anchors.topMargin: Appearance.padding.large
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: win.searchWidth
                    height: win.searchHeight

                    // Only the open one takes the pointer, so the rows
                    // of the other, fading out on top or underneath,
                    // never catch a hover or a tap meant for it.
                    enabled: win.clipboardOpen

                    active: win.clipboardOpen
                    z: win.clipboardOpen ? 1 : 0

                    onDismissed: root.close("clipboard")
                }

                EmojiPanel {
                    anchors.top: parent.top
                    anchors.topMargin: Appearance.padding.large
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: win.searchWidth
                    height: win.searchHeight

                    enabled: win.emojiOpen
                    active: win.emojiOpen
                    z: win.emojiOpen ? 1 : 0

                    onDismissed: root.close("emoji")
                }

                WindowChooser {
                    id: chooser

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Appearance.padding.large

                    enabled: win.windowsOpen
                    active: win.windowsOpen
                    z: win.windowsOpen ? 1 : 0
                    entry: root.chooserEntry

                    onDismissed: root.close("windows")
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

                // The others part around the gap as it moves, and close
                // up behind it, rather than jumping across.
                add: Transition {
                    Anim {
                        property: "scale"
                        from: 0
                        to: 1
                        type: Anim.FastSpatial
                    }
                }

                move: Transition {
                    Anim {
                        property: "x"
                        type: Anim.Emphasized
                    }
                    // Brings back one whose own coming in was cut short.
                    Anim {
                        property: "scale"
                        to: 1
                        type: Anim.FastSpatial
                    }
                }

                // Picks a pin up. Taps on the icons are theirs, as a drag
                // takes the pointer from them only once it has moved.
                DragHandler {
                    target: null
                    enabled: !win.choosingPlace

                    onActiveChanged: {
                        if (active)
                            win.beginDrag(centroid.pressPosition);
                        else if (win.dragging)
                            win.finishPlacing(true);
                    }

                    onCentroidChanged: if (active && win.dragging)
                        win.dragTo(centroid.position)
                }

                // Placing from the launcher, the gap follows the pointer
                // along the row, and a click drops the app in it.
                HoverHandler {
                    enabled: win.choosingPlace

                    onPointChanged: if (hovered)
                        win.placeIndex = win.slotAt(point.position.x, Apps.pinned.length)
                }

                TapHandler {
                    enabled: win.choosingPlace

                    onTapped: win.finishPlacing(true)
                }

                DockButton {
                    id: launcherButton

                    icon: "apps"
                    active: win.launcherOpen
                    enabled: !win.choosingPlace

                    onTapped: root.toggle("launcher", win.modelData.name)
                }

                // Divides the button from the applications it opens.
                Rectangle {
                    id: divider

                    anchors.verticalCenter: parent.verticalCenter

                    implicitWidth: 1
                    implicitHeight: Config.dock.iconSize * 0.6

                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.25
                }

                Repeater {
                    model: ScriptModel {
                        values: win.rowApps
                    }

                    // An app, or the gap one is being placed in.
                    Item {
                        id: slot

                        required property var modelData

                        readonly property bool isGap: modelData === gap

                        implicitWidth: Config.dock.iconSize + Appearance.padding.small * 2
                        implicitHeight: Config.dock.iconSize + Appearance.padding.small * 2

                        // Counted in and out by hand, so an icon taken
                        // out of the row from under the pointer -- picked
                        // up, or unpinned -- does not leave the dock
                        // counting it as pointed at for good.
                        readonly property bool appHovered: !isGap && (app.item?.hovered ?? false)
                        property bool counted: false

                        function count(hovered: bool): void {
                            if (hovered !== counted) {
                                win.hoveredApps += hovered ? 1 : -1;
                                counted = hovered;
                            }
                        }

                        onAppHoveredChanged: count(appHovered)
                        Component.onDestruction: count(false)

                        Loader {
                            id: app

                            anchors.fill: parent

                            active: !slot.isGap
                            enabled: !win.choosingPlace

                            sourceComponent: DockApp {
                                entry: slot.modelData
                                chosen: win.windowsOpen && root.chooserEntry === slot.modelData

                                onChooseRequested: root.choose(slot.modelData, win.modelData.name)

                                // Going straight to an app with one window
                                // puts away the chooser that was showing
                                // another's.
                                onActivated: root.close("windows")
                            }
                        }

                        // The gap: a hollow where the app would land, with
                        // the app in it when it came from the launcher.
                        // One dragged is under the pointer instead.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Appearance.padding.extraSmall

                            visible: slot.isGap
                            radius: Appearance.rounding.large
                            color: "transparent"
                            border.width: 2
                            border.color: Colours.palette.m3primary
                            opacity: 0.6

                            IconImage {
                                anchors.centerIn: parent

                                visible: !win.dragging
                                implicitSize: Config.dock.iconSize * 0.8
                                source: Quickshell.iconPath(win.placing?.icon ?? "", "application-x-executable")
                            }
                        }
                    }
                }

                // Divides the applications from the pin, as the launcher
                // button is divided from them.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter

                    implicitWidth: 1
                    implicitHeight: Config.dock.iconSize * 0.6

                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.25
                }

                // Holds the dock up, as the bar's pin holds the bar down.
                Pin {
                    id: pin

                    anchors.verticalCenter: parent.verticalCenter

                    pinned: DockState.pinned
                    size: Appearance.font.icon.large
                    enabled: !win.choosingPlace

                    onToggled: DockState.togglePinned()
                }
            }

            // Placing from the launcher, the keys move the gap and drop
            // the app or give up, then hand the keyboard back to the
            // search.
            Item {
                id: placer

                Keys.onLeftPressed: win.placeIndex = Math.max(0, win.placeIndex - 1)
                Keys.onRightPressed: win.placeIndex = Math.min(Apps.pinned.length, win.placeIndex + 1)
                Keys.onReturnPressed: win.finishPlacing(true)
                Keys.onEnterPressed: win.finishPlacing(true)
                Keys.onSpacePressed: win.finishPlacing(true)
                Keys.onEscapePressed: win.finishPlacing(false)
            }

            // The pin being dragged, under the pointer. Faded and shrunk
            // while it is out above the dock, where letting go of it
            // takes it out.
            IconImage {
                readonly property bool out: win.placeIndex < 0

                x: row.x + win.dragPoint.x - width / 2
                y: row.y + win.dragPoint.y - height / 2

                visible: win.dragging
                implicitSize: Config.dock.iconSize
                source: Quickshell.iconPath(win.placing?.icon ?? "", "application-x-executable")

                scale: out ? 0.8 : 1.18
                opacity: out ? 0.5 : 1

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }
        }
    }
}
