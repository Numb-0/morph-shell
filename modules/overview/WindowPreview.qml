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
    readonly property bool hovered: area.containsMouse

    // 0 to 1 as its workspace pops in, and the point it grows from: the
    // middle of its cell, in its own coordinates, so it rides in with
    // the cell rather than growing on its own.
    property real appear: 1
    property point appearOrigin: Qt.point(width / 2, height / 2)

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

    scale: dragging ? 1.06 : hovered ? 1.04 : 1
    opacity: (dragging ? 0.9 : 1) * Math.min(1, appear)
    z: dragging ? 2 : hovered ? 1.5 : 1

    transform: Scale {
        origin.x: root.appearOrigin.x
        origin.y: root.appearOrigin.y
        xScale: 0.82 + 0.18 * root.appear
        yScale: xScale
    }

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

    // The window's title, along the bottom while the pointer is on it.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.padding.small

        visible: opacity > 0 && root.height > title.implicitHeight * 3
        opacity: root.hovered && !root.dragging ? 1 : 0

        width: Math.min(root.width - Appearance.padding.small * 2, title.implicitWidth + Appearance.padding.medium * 2)
        height: title.implicitHeight + Appearance.padding.extraSmall * 2
        radius: height / 2
        color: Appearance.palette.m3inverseSurface

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        StyledText {
            id: title

            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - Appearance.padding.medium * 2)

            text: root.toplevel?.title ?? ""
            elide: Text.ElideRight
            color: Appearance.palette.m3inverseOnSurface
        }
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
