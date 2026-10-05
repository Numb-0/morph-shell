pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.components
import qs.config

// One screen's share of the region picker. Hovering outlines what a
// click would take -- the window under the pointer, or the whole
// screen over bare desktop -- and a drag takes a rectangle of its own.
// Everything outside the selection is dimmed.
//
// Coordinates here are the screen's own, in logical pixels. The parent
// turns them into the global ones grim wants.
MouseArea {
    id: root

    required property ShellScreen screen

    // Stops drawing the instant a region is picked, so the capture that
    // follows sees the screen and not the dim.
    property bool hidden: false

    signal picked(real x, real y, real w, real h)
    signal cancelled

    // Past this a press becomes a drag. Less, and a click that wobbled
    // by a pixel would take a sliver instead of the window under it.
    readonly property int dragThreshold: 4

    property real pressX
    property real pressY
    property bool dragging: false

    // The windows showing on this screen, topmost first as near as the
    // IPC can tell: pinned, then fullscreen, then floating, then tiled.
    // Tiled windows never overlap, so their order among themselves does
    // not matter.
    readonly property var windows: {
        if (wsId === undefined)
            return [];

        return Hyprland.toplevels.values.map(t => t.lastIpcObject).filter(ipc => ipc?.at && ipc?.size && ipc.mapped && !ipc.hidden && (ipc.workspace?.id === wsId || ipc.pinned)).sort((a, b) => (b.pinned - a.pinned) || ((b.fullscreen !== 0) - (a.fullscreen !== 0)) || (b.floating - a.floating)).map(ipc => clip(ipc.at[0] - screen.x, ipc.at[1] - screen.y, ipc.size[0], ipc.size[1]));
    }

    // Cut to the screen: a window hanging off the edge is only captured
    // as far as this screen shows it.
    function clip(x: real, y: real, w: real, h: real): rect {
        const l = Math.max(0, x);
        const t = Math.max(0, y);
        const r = Math.min(width, x + w);
        const b = Math.min(height, y + h);
        return Qt.rect(l, t, Math.max(0, r - l), Math.max(0, b - t));
    }

    function windowAt(x: real, y: real): rect {
        for (const w of windows)
            if (x >= w.x && y >= w.y && x < w.x + w.width && y < w.y + w.height)
                return w;
        return Qt.rect(0, 0, width, height);
    }

    // Where the pointer is. Starts off screen until the compositor says
    // otherwise, so a screen the pointer is not on shows no outline.
    property real pointerX: -1
    property real pointerY: -1
    readonly property bool pointerHere: pointerX >= 0 && pointerY >= 0 && pointerX < width && pointerY < height

    readonly property rect target: {
        if (dragging)
            return Qt.rect(Math.min(pressX, pointerX), Math.min(pressY, pointerY), Math.abs(pointerX - pressX), Math.abs(pointerY - pressY));
        if (!pointerHere)
            return Qt.rect(width / 2, height / 2, 0, 0);
        return windowAt(pointerX, pointerY);
    }

    // The drawn selection, gliding between windows as the pointer moves
    // over them but pinned to the pointer while dragging.
    property real selX: target.x
    property real selY: target.y
    property real selW: target.width
    property real selH: target.height

    Behavior on selX {
        enabled: !root.dragging

        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on selY {
        enabled: !root.dragging

        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on selW {
        enabled: !root.dragging

        Anim {
            type: Anim.FastSpatial
        }
    }

    Behavior on selH {
        enabled: !root.dragging

        Anim {
            type: Anim.FastSpatial
        }
    }

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.CrossCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onPositionChanged: event => {
        pointerX = event.x;
        pointerY = event.y;
        if (pressed && !dragging && Math.hypot(event.x - pressX, event.y - pressY) > dragThreshold)
            dragging = true;
    }

    onPressed: event => {
        if (event.button === Qt.RightButton) {
            cancelled();
            return;
        }
        pressX = event.x;
        pressY = event.y;
    }

    onReleased: event => {
        if (event.button !== Qt.LeftButton)
            return;

        // Taken from the target, not from the drawn selection, which may
        // still be gliding towards it.
        const r = dragging ? target : windowAt(event.x, event.y);
        dragging = false;
        if (r.width >= 1 && r.height >= 1)
            picked(r.x, r.y, r.width, r.height);
    }

    focus: true
    Keys.onEscapePressed: cancelled()

    // The workspace this screen is showing, the special one when it is
    // open over the rest, and the screen's scale. Read from hyprctl
    // rather than from the monitor's activeWorkspace and lastIpcObject,
    // which never fill in on some Hyprland versions and left every click
    // taking the whole screen.
    property var wsId
    property real monitorScale: 1

    Process {
        running: true
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const mon = JSON.parse(text).find(m => m.name === root.screen.name);
                    if (!mon)
                        return;
                    root.wsId = mon.specialWorkspace?.name ? mon.specialWorkspace.id : mon.activeWorkspace?.id;
                    root.monitorScale = mon.scale ?? 1;
                } catch (e) {}
            }
        }
    }

    // The pointer's position before it has moved, so the outline is
    // there from the first frame rather than waiting on a wiggle.
    Process {
        running: true
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const pos = JSON.parse(text);
                    if (root.pointerX < 0) {
                        root.pointerX = pos.x - root.screen.x;
                        root.pointerY = pos.y - root.screen.y;
                    }
                } catch (e) {}
            }
        }
    }

    Item {
        anchors.fill: parent

        visible: !root.hidden

        opacity: 0
        Component.onCompleted: opacity = 1

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        // The dim: a hollow rectangle around the selection whose border
        // is wide enough to reach every edge of the screen from anywhere
        // on it.
        Rectangle {
            readonly property real reach: Math.max(root.width, root.height)

            x: root.selX - reach
            y: root.selY - reach
            width: root.selW + reach * 2
            height: root.selH + reach * 2

            color: "transparent"
            border.width: reach
            border.color: {
                const c = Appearance.palette.m3scrim;
                return Qt.rgba(c.r, c.g, c.b, 0.45);
            }
        }

        // The outline, just outside the selection so it is never
        // captured along with it.
        Rectangle {
            readonly property int thickness: 2

            visible: root.selW > 0 && root.selH > 0

            x: root.selX - thickness
            y: root.selY - thickness
            width: root.selW + thickness * 2
            height: root.selH + thickness * 2

            color: "transparent"
            border.width: thickness
            border.color: Appearance.palette.m3primary
        }

        // The size the image will come out at, in real pixels. Sits
        // under the selection, or inside it along the bottom when the
        // selection reaches the screen's lower edge.
        Rectangle {
            id: size

            visible: root.selW > 0 && root.selH > 0

            readonly property real below: root.selY + root.selH + Appearance.spacing.small

            x: Math.max(0, Math.min(root.width - width, root.selX + (root.selW - width) / 2))
            y: below + height <= root.height ? below : root.selY + root.selH - height - Appearance.spacing.small

            implicitWidth: label.implicitWidth + Appearance.padding.medium * 2
            implicitHeight: label.implicitHeight + Appearance.padding.extraSmall * 2

            radius: height / 2
            color: Appearance.palette.m3primaryContainer

            StyledText {
                id: label

                anchors.centerIn: parent

                readonly property real factor: root.monitorScale

                text: `${Math.round(root.target.width * factor)} × ${Math.round(root.target.height * factor)}`
                color: Appearance.palette.m3onPrimaryContainer
            }
        }
    }
}
