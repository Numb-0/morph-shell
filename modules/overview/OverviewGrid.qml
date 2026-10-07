pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// One screen's overview: the page of workspaces holding the one this
// screen shows, as a grid of small copies of the screen, with every
// window drawn where it sits in its workspace.
//
// Each cell is this screen in miniature. A window is placed by where it
// sits on its own monitor, as a share of that monitor, so one from a
// monitor of another size or shape still lands where it belongs.
MouseArea {
    id: root

    required property ShellScreen screen
    required property bool shown

    // Asked to close: something was picked, or the overview cancelled.
    signal dismissed

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    readonly property int rows: Appearance.overview.rows
    readonly property int columns: Appearance.overview.columns
    readonly property int perPage: rows * columns

    // The workspace this screen shows. From hyprctl first, since the
    // monitor's own activeWorkspace does not always fill in.
    readonly property int activeId: monitorInfo(screen.name)?.activeWorkspace?.id ?? monitor?.activeWorkspace?.id ?? 1

    // The page is fixed on opening, so keys and the pointer stay on the
    // grid they started on even as the active workspace changes under
    // them.
    property int page: 0
    readonly property int firstId: page * perPage + 1

    // The workspace the keyboard or the pointer is on.
    property int selected: 1

    // While a window is dragged: its address, and the workspace it would
    // drop into.
    property string dragging: ""
    property int dropTarget: -1

    // Room between cells, and around the grid inside its card.
    readonly property real gap: Appearance.spacing.medium
    readonly property real inset: Appearance.padding.large

    // A cell keeps this screen's shape, and is as big as both limits
    // allow.
    readonly property real aspect: screen.width / Math.max(1, screen.height)
    readonly property real cellWidth: Math.min((width * Appearance.overview.maxWidth - inset * 2 - gap * (columns - 1)) / columns, (height * Appearance.overview.maxHeight - inset * 2 - gap * (rows - 1)) / rows * aspect)
    readonly property real cellHeight: cellWidth / aspect

    // Hyprland's monitors, for where each window's monitor sits and how
    // big it is.
    property var monitors: []

    function monitorInfo(name: string): var {
        return monitors.find(m => m.name === name) ?? null;
    }

    // A monitor's logical bounds: hyprctl gives the position in logical
    // pixels already, but the size in real ones and before rotation.
    function bounds(id: int): rect {
        const m = monitors.find(m => m.id === id);
        if (!m)
            return Qt.rect(screen.x, screen.y, screen.width, screen.height);
        const turned = m.transform % 2 === 1;
        const w = (turned ? m.height : m.width) / m.scale;
        const h = (turned ? m.width : m.height) / m.scale;
        return Qt.rect(m.x, m.y, w, h);
    }

    function cellX(id: int): real {
        return (id - firstId) % columns * (cellWidth + gap);
    }

    function cellY(id: int): real {
        return Math.floor((id - firstId) / columns) * (cellHeight + gap);
    }

    // The workspace whose cell is under a point on the board, or -1.
    function cellAt(x: real, y: real): int {
        const col = Math.floor(x / (cellWidth + gap));
        const row = Math.floor(y / (cellHeight + gap));
        if (col < 0 || col >= columns || row < 0 || row >= rows)
            return -1;
        if (x - col * (cellWidth + gap) > cellWidth || y - row * (cellHeight + gap) > cellHeight)
            return -1;
        return firstId + row * columns + col;
    }

    function goTo(id: int): void {
        WorkspacesState.goTo(monitor, id);
        dismissed();
    }

    function focusWindow(address: string): void {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${address}" })`);
        dismissed();
    }

    function moveWindow(address: string, id: int): void {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${id}", follow = false, window = "address:${address}" })`);
    }

    // The windows on this page, as Hyprland's toplevels so each keeps its
    // preview while it moves about. Tiled ones first so floating and
    // fullscreen ones are drawn over them.
    readonly property var windows: Hyprland.toplevels.values.filter(t => {
        const ipc = t.lastIpcObject;
        const ws = ipc?.workspace?.id ?? 0;
        return ipc?.at && ipc?.size && ipc.mapped && !ipc.hidden && ws >= firstId && ws < firstId + perPage;
    }).sort((a, b) => (a.lastIpcObject.fullscreen !== 0) - (b.lastIpcObject.fullscreen !== 0) || a.lastIpcObject.floating - b.lastIpcObject.floating)

    Component.onCompleted: {
        page = Math.floor((Math.max(1, activeId) - 1) / perPage);
        selected = activeId;
    }

    // Kept up to date while open, so a window moved or closed from here
    // or elsewhere shows where it went. Events come in bursts; one
    // refresh after the last does for the lot.
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (!event.name.startsWith("activewindow"))
                refresh.restart();
        }
    }

    Timer {
        id: refresh

        interval: 40
        onTriggered: {
            Hyprland.refreshToplevels();
            monitorsQuery.running = true;
        }
    }

    Process {
        id: monitorsQuery

        running: true
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const first = root.monitors.length === 0;
                    root.monitors = JSON.parse(text);
                    if (first) {
                        root.page = Math.floor((Math.max(1, root.activeId) - 1) / root.perPage);
                        root.selected = root.activeId;
                    }
                } catch (e) {}
            }
        }
    }

    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    // A click anywhere off the grid closes it.
    onClicked: dismissed()

    focus: true
    Keys.onPressed: event => {
        const col = (selected - firstId) % columns;
        const row = Math.floor((selected - firstId) / columns);
        let to = -1;

        switch (event.key) {
        case Qt.Key_Escape:
            dismissed();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            goTo(selected);
            break;
        case Qt.Key_Left:
        case Qt.Key_H:
            to = firstId + row * columns + (col + columns - 1) % columns;
            break;
        case Qt.Key_Right:
        case Qt.Key_L:
            to = firstId + row * columns + (col + 1) % columns;
            break;
        case Qt.Key_Up:
        case Qt.Key_K:
            to = firstId + (row + rows - 1) % rows * columns + col;
            break;
        case Qt.Key_Down:
        case Qt.Key_J:
            to = firstId + (row + 1) % rows * columns + col;
            break;
        default:
            // 1 to 9 and 0 for the tenth, as the keybinds count.
            if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                const n = event.key === Qt.Key_0 ? 10 : event.key - Qt.Key_0;
                if (n <= perPage)
                    goTo(firstId + n - 1);
            } else {
                return;
            }
        }

        if (to >= 0)
            selected = to;
        event.accepted = true;
    }

    // The dim over everything.
    Rectangle {
        anchors.fill: parent

        color: {
            const c = Appearance.palette.m3scrim;
            return Qt.rgba(c.r, c.g, c.b, 0.5);
        }

        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    // The card the grid sits on.
    Rectangle {
        id: card

        anchors.centerIn: parent

        width: board.width + root.inset * 2
        height: board.height + root.inset * 2

        radius: Appearance.rounding.extraLarge
        color: Appearance.palette.m3surfaceContainer

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.92

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }

        // Swallows clicks between the cells, which would otherwise fall
        // through to the dim and close the grid.
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: board

            x: root.inset
            y: root.inset
            width: root.columns * root.cellWidth + (root.columns - 1) * root.gap
            height: root.rows * root.cellHeight + (root.rows - 1) * root.gap

            Repeater {
                model: root.perPage

                Cell {
                    required property int index

                    wsId: root.firstId + index
                    x: root.cellX(wsId)
                    y: root.cellY(wsId)
                    width: root.cellWidth
                    height: root.cellHeight

                    active: wsId === root.activeId
                    target: wsId === root.dropTarget && root.dragging !== ""

                    onEntered: root.selected = wsId
                    onPicked: root.goTo(wsId)
                }
            }

            // The windows, over the cells, on one layer so one dragged out
            // of its cell is drawn over the rest of the grid.
            Repeater {
                model: root.windows

                WindowPreview {
                    id: preview

                    required property HyprlandToplevel modelData

                    toplevel: modelData

                    readonly property var ipc: modelData.lastIpcObject
                    readonly property rect mon: root.bounds(ipc?.monitor ?? -1)
                    readonly property int wsId: ipc?.workspace?.id ?? root.firstId

                    // Where it sits, as a share of its monitor, laid on
                    // its workspace's cell. Cut to the monitor, so a
                    // window hanging off the edge stays inside its cell.
                    readonly property real fromX: Math.max(0, (ipc?.at[0] - mon.x) / mon.width)
                    readonly property real fromY: Math.max(0, (ipc?.at[1] - mon.y) / mon.height)
                    readonly property real toX: Math.min(1, (ipc?.at[0] + ipc?.size[0] - mon.x) / mon.width)
                    readonly property real toY: Math.min(1, (ipc?.at[1] + ipc?.size[1] - mon.y) / mon.height)

                    readonly property real homeX: root.cellX(wsId) + fromX * root.cellWidth
                    readonly property real homeY: root.cellY(wsId) + fromY * root.cellHeight

                    x: homeX
                    y: homeY
                    width: Math.max(1, (toX - fromX) * root.cellWidth)
                    height: Math.max(1, (toY - fromY) * root.cellHeight)
                    z: dragging ? 2 : 1

                    radius: Math.min(Appearance.rounding.small, width / 4, height / 4)

                    Behavior on x {
                        enabled: !preview.dragging

                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    Behavior on y {
                        enabled: !preview.dragging

                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    onEntered: root.selected = wsId

                    onDragMoved: (cx, cy) => {
                        root.dragging = ipc?.address ?? "";
                        root.dropTarget = root.cellAt(cx, cy);
                    }

                    // Dropped: into another workspace it moves there; back
                    // into its own, or off the grid, it glides home. The
                    // bindings come back either way, so it follows wherever
                    // Hyprland puts it next.
                    onDragEnded: {
                        const to = root.dropTarget;
                        const address = ipc?.address ?? "";
                        root.dragging = "";
                        root.dropTarget = -1;
                        preview.x = Qt.binding(() => preview.homeX);
                        preview.y = Qt.binding(() => preview.homeY);
                        if (to > 0 && to !== wsId && address !== "")
                            root.moveWindow(address, to);
                    }

                    onPicked: root.focusWindow(ipc?.address ?? "")
                    onCloseRequested: modelData.wayland?.close()
                }
            }

            // Where the keyboard and the pointer are, gliding from cell to
            // cell. Just outside the cell, so it rings it rather than
            // covering its edge.
            Rectangle {
                readonly property real reach: 4

                x: root.cellX(root.selected) - reach
                y: root.cellY(root.selected) - reach
                width: root.cellWidth + reach * 2
                height: root.cellHeight + reach * 2
                z: 3

                visible: root.selected >= root.firstId && root.selected < root.firstId + root.perPage && root.dragging === ""

                radius: Appearance.rounding.large + reach
                color: "transparent"
                border.width: 2
                border.color: Appearance.palette.m3primary

                Behavior on x {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Behavior on y {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }
            }
        }
    }
}
