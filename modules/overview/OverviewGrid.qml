pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// One screen's overview: the workspaces in use, as a grid of small
// copies of the screen, with every window drawn where it sits in its
// workspace, and one empty workspace past them to go to or drop a window
// into.
//
// Each cell is this screen in miniature. A window is placed by where it
// sits on its own monitor, as a share of that monitor, so one from a
// monitor of another size or shape still lands where it belongs.
MouseArea {
    id: root

    required property ShellScreen screen
    required property bool shown

    // Asked to close, and then to do something once it has: switching
    // has to wait until the overview lets go of the keyboard, since
    // Hyprland hands it back to the window that had it and follows that
    // window to its workspace.
    signal dismissed(var after)

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    // The workspace this screen shows. From hyprctl first, since the
    // monitor's own activeWorkspace does not always fill in.
    readonly property int activeId: monitorInfo(screen.name)?.activeWorkspace?.id ?? monitor?.activeWorkspace?.id ?? 1

    // The workspaces in use, the one on screen among them even when it
    // is empty, then the first free one.
    readonly property var used: {
        const out = [...WorkspacesState.occupied];
        if (activeId > 0 && !out.includes(activeId))
            out.push(activeId);
        return out.sort((a, b) => a - b);
    }
    readonly property int newId: {
        let id = 1;
        while (used.includes(id))
            id++;
        return id;
    }
    readonly property var ids: [...used, newId]

    readonly property int columns: Math.max(1, Math.min(ids.length, Appearance.overview.columns))
    readonly property int rows: Math.ceil(ids.length / columns)

    // The workspace the keyboard or the pointer is on.
    property int selected: 1

    // While a window is dragged: its address, and the workspace it would
    // drop into.
    property string dragging: ""
    property int dropTarget: -1

    // Room between cells, and around the grid inside its card.
    readonly property real gap: Appearance.spacing.medium
    readonly property real inset: Appearance.padding.large

    // A cell keeps this screen's shape, and is sized for a full grid, so
    // a few workspaces make a small card rather than big cells.
    readonly property int fitColumns: Appearance.overview.columns
    readonly property int fitRows: Math.max(rows, Appearance.overview.rows)
    readonly property real aspect: screen.width / Math.max(1, screen.height)
    readonly property real cellWidth: Math.min((width * Appearance.overview.maxWidth - inset * 2 - gap * (fitColumns - 1)) / fitColumns, (height * Appearance.overview.maxHeight - inset * 2 - gap * (fitRows - 1)) / fitRows * aspect)
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
        return Math.max(0, ids.indexOf(id)) % columns * (cellWidth + gap);
    }

    function cellY(id: int): real {
        return Math.floor(Math.max(0, ids.indexOf(id)) / columns) * (cellHeight + gap);
    }

    // The workspace whose cell is under a point on the board, or -1.
    function cellAt(x: real, y: real): int {
        const col = Math.floor(x / (cellWidth + gap));
        const row = Math.floor(y / (cellHeight + gap));
        if (col < 0 || col >= columns || row < 0)
            return -1;
        if (x - col * (cellWidth + gap) > cellWidth || y - row * (cellHeight + gap) > cellHeight)
            return -1;
        return ids[row * columns + col] ?? -1;
    }

    function goTo(id: int): void {
        const monitor = root.monitor;
        dismissed(() => WorkspacesState.goTo(monitor, id));
    }

    function focusWindow(address: string): void {
        dismissed(() => Hyprland.dispatch(`hl.dsp.focus({ window = "address:${address}" })`));
    }

    function moveWindow(address: string, id: int): void {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${id}", follow = false, window = "address:${address}" })`);
    }

    // The windows in the workspaces shown, as Hyprland's toplevels so
    // each keeps its preview while it moves about. Tiled ones first so
    // floating and fullscreen ones are drawn over them.
    readonly property var windows: Hyprland.toplevels.values.filter(t => {
        const ipc = t.lastIpcObject;
        return ipc?.at && ipc?.size && ipc.mapped && !ipc.hidden && ids.includes(ipc.workspace?.id);
    }).sort((a, b) => (a.lastIpcObject.fullscreen !== 0) - (b.lastIpcObject.fullscreen !== 0) || a.lastIpcObject.floating - b.lastIpcObject.floating)

    Component.onCompleted: selected = activeId

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
                    if (first)
                        root.selected = root.activeId;
                } catch (e) {}
            }
        }
    }

    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    // A click anywhere off the grid closes it.
    onClicked: dismissed(null)

    focus: true
    Keys.onPressed: event => {
        const at = Math.max(0, ids.indexOf(selected));
        const n = ids.length;
        let to = -1;

        switch (event.key) {
        case Qt.Key_Escape:
            dismissed(null);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            goTo(selected);
            break;
        case Qt.Key_Left:
        case Qt.Key_H:
            to = (at + n - 1) % n;
            break;
        case Qt.Key_Right:
        case Qt.Key_L:
            to = (at + 1) % n;
            break;
        case Qt.Key_Up:
        case Qt.Key_K:
            to = at - columns >= 0 ? at - columns : at;
            break;
        case Qt.Key_Down:
        case Qt.Key_J:
            to = Math.min(n - 1, at + columns);
            break;
        default:
            // 1 to 9 and 0 for 10, the workspace itself as the keybinds
            // count, shown here or not.
            if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9)
                goTo(event.key === Qt.Key_0 ? 10 : event.key - Qt.Key_0);
            else
                return;
        }

        if (to >= 0)
            selected = ids[to];
        event.accepted = true;
    }

    // The cells pop in one after another, and their windows with them.
    // One clock for the lot, so a cell and its windows, worked out apart,
    // still move as one.
    readonly property int stagger: 45
    readonly property int popDuration: Appearance.anim.durations.defaultSpatial
    property real entry: 0

    NumberAnimation on entry {
        from: 0
        to: 1
        duration: root.stagger * Math.max(0, root.ids.length - 1) + root.popDuration
    }

    // How far in the cell at this place in the grid is, 0 to 1 with a
    // little overshoot before it settles.
    function appearOf(order: int): real {
        const total = stagger * Math.max(0, ids.length - 1) + popDuration;
        const t = Math.max(0, Math.min(1, (entry * total - Math.max(0, order) * stagger) / popDuration));
        const c = 1.6;
        return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2);
    }

    // Behind the grid: a dim over the screen, which still shows through
    // it. Hyprland can blur what is under it with a layer rule on the
    // morph-shell-overview namespace; without one it is only darkened.
    Rectangle {
        anchors.fill: parent

        color: {
            const c = Appearance.palette.m3scrim;
            return Qt.rgba(c.r, c.g, c.b, 0.4);
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
        border.width: 1
        border.color: Qt.alpha(Appearance.palette.m3outlineVariant, 0.6)

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.92

        Behavior on width {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on height {
            Anim {
                type: Anim.FastSpatial
            }
        }

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
                model: root.ids

                Cell {
                    required property int modelData
                    required property int index

                    wsId: modelData
                    fresh: modelData === root.newId
                    x: root.cellX(wsId)
                    y: root.cellY(wsId)
                    width: root.cellWidth
                    height: root.cellHeight

                    active: wsId === root.activeId
                    target: wsId === root.dropTarget && root.dragging !== ""
                    appear: root.appearOf(index)

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
                    readonly property int wsId: ipc?.workspace?.id ?? root.activeId

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

                    radius: Math.min(Appearance.rounding.small, width / 4, height / 4)

                    appear: root.appearOf(root.ids.indexOf(wsId))
                    appearOrigin: Qt.point(root.cellX(wsId) + root.cellWidth / 2 - x, root.cellY(wsId) + root.cellHeight / 2 - y)

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

            // Each workspace's number on its shape, in the cell's corner and
            // over its windows.
            Repeater {
                model: root.used

                Badge {
                    id: badge

                    required property int modelData
                    required property int index

                    readonly property real appear: root.appearOf(index)

                    wsId: modelData
                    active: wsId === root.activeId
                    selected: wsId === root.selected
                    running: root.shown

                    x: root.cellX(wsId) + Appearance.padding.small
                    y: root.cellY(wsId) + Appearance.padding.small
                    z: 3

                    opacity: Math.min(1, appear)
                    transform: Scale {
                        origin.x: 0
                        origin.y: 0
                        xScale: Math.max(0, badge.appear)
                        yScale: xScale
                    }

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

            // Where the keyboard and the pointer are, ringing the cell just
            // outside its edge. Its edges move apart: the one leading the
            // way gets there first and the trailing one catches up, so it
            // stretches across the gap rather than sliding.
            Rectangle {
                id: ring

                readonly property real reach: 4

                readonly property rect goal: Qt.rect(root.cellX(root.selected) - reach, root.cellY(root.selected) - reach, root.cellWidth + reach * 2, root.cellHeight + reach * 2)

                property real edgeL: goal.x
                property real edgeT: goal.y
                property real edgeR: goal.x + goal.width
                property real edgeB: goal.y + goal.height

                function follow(): void {
                    const g = goal;
                    const lead = Appearance.anim.durations.fastSpatial;
                    const trail = Math.round(lead * 1.7);
                    for (const [anim, to, ahead] of [[leftAnim, g.x, g.x < edgeL], [rightAnim, g.x + g.width, g.x + g.width > edgeR], [topAnim, g.y, g.y < edgeT], [bottomAnim, g.y + g.height, g.y + g.height > edgeB]]) {
                        anim.stop();
                        anim.to = to;
                        anim.duration = ahead ? lead : trail;
                        anim.start();
                    }
                }

                onGoalChanged: follow()

                x: edgeL
                y: edgeT
                width: edgeR - edgeL
                height: edgeB - edgeT
                z: 4

                visible: root.ids.includes(root.selected) && root.dragging === ""
                opacity: Math.min(1, root.appearOf(0))

                radius: Appearance.rounding.large + reach
                color: "transparent"
                border.width: 2
                border.color: Appearance.palette.m3primary

                Anim {
                    id: leftAnim

                    target: ring
                    property: "edgeL"
                    type: Anim.FastSpatial
                }

                Anim {
                    id: rightAnim

                    target: ring
                    property: "edgeR"
                    type: Anim.FastSpatial
                }

                Anim {
                    id: topAnim

                    target: ring
                    property: "edgeT"
                    type: Anim.FastSpatial
                }

                Anim {
                    id: bottomAnim

                    target: ring
                    property: "edgeB"
                    type: Anim.FastSpatial
                }
            }
        }
    }
}
