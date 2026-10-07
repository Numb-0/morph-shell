import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// A window in the overview, drawn live from the compositor, with its
// app's icon over it. A click focuses it, a middle click closes it, and
// it can be dragged into another workspace.
ClippingRectangle {
    id: root

    required property HyprlandToplevel toplevel

    readonly property bool dragging: area.drag.active

    signal entered
    signal picked
    signal closeRequested

    // While dragged: the point being dragged, in the parent's
    // coordinates, so the grid can tell which cell it is over.
    signal dragMoved(real cx, real cy)
    signal dragEnded

    color: Appearance.palette.m3surfaceContainerHigh
    border.width: 1
    border.color: area.containsMouse ? Appearance.palette.m3primary : Appearance.palette.m3outlineVariant

    scale: dragging ? 1.04 : 1
    opacity: dragging ? 0.9 : 1

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    // Drawn while the overview is up only; capture stops with it.
    ScreencopyView {
        id: view

        anchors.fill: parent

        captureSource: root.toplevel?.wayland ?? null
        live: true
    }

    IconImage {
        readonly property real size: Math.min(root.width, root.height) * (view.hasContent ? 0.28 : 0.42)

        anchors.centerIn: parent

        implicitSize: Math.max(12, Math.min(48, size))
        source: {
            const cls = root.toplevel?.lastIpcObject?.class ?? "";
            return Quickshell.iconPath(Apps.byId(cls)?.icon ?? cls, "application-x-executable");
        }
        asynchronous: true
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        drag.target: pressedButtons & Qt.LeftButton ? root : null
        drag.threshold: 6

        // Whether this press turned into a drag. Kept apart from
        // drag.active, which is already over by the time the release is
        // heard.
        property bool moved: false

        onEntered: root.entered()

        onPressed: moved = false

        onPositionChanged: event => {
            if (!drag.active)
                return;
            moved = true;
            root.dragMoved(root.x + event.x, root.y + event.y);
        }

        onReleased: event => {
            if (event.button === Qt.LeftButton && moved)
                root.dragEnded();
        }

        onClicked: event => {
            if (moved)
                return;
            if (event.button === Qt.MiddleButton)
                root.closeRequested();
            else
                root.picked();
        }
    }
}
