import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.modules.bar.components.workspaces
import qs.services

// Bar widget: Hyprland's workspaces, drawn in one of the styles under
// workspaces/ (Appearance.bar.workspaces.style). What is true of the
// workspaces -- which exist, how many windows each holds -- is shared by
// every bar and lives in WorkspacesState; this side adds only which one
// this screen shows, and the input. A style only draws it. A click goes to the
// slot under the pointer and the wheel steps through workspaces in use.
Item {
    id: root

    required property ShellScreen screen

    readonly property bool hovered: hover.hovered

    // The workspace this screen shows, and where a click or a scroll
    // opens one.
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1

    readonly property var windows: WorkspacesState.windows
    readonly property var urgent: WorkspacesState.urgent

    readonly property int count: Math.max(Appearance.bar.workspaces.shown, activeId, WorkspacesState.occupied[WorkspacesState.occupied.length - 1] ?? 1)

    // Each style picks how much room a workspace takes.
    readonly property real slot: style.item?.slotWidth ?? 20
    readonly property real padding: Appearance.bar.itemPadding

    // Continuous animations only run while anyone can see them.
    readonly property bool running: opacity > 0 && visible

    function windowsOn(id: int): int {
        return WorkspacesState.windowsOn(id);
    }

    function centerOf(id: int): real {
        return padding + (id - 0.5) * slot;
    }

    implicitWidth: count * slot + padding * 2
    implicitHeight: Appearance.font.icon.normal + Appearance.padding.small * 2

    Behavior on implicitWidth {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: point => {
            const id = Math.floor((point.position.x - root.padding) / root.slot) + 1;
            if (id >= 1 && id <= root.count)
                WorkspacesState.goTo(root.monitor, id);
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => WorkspacesState.step(root.monitor, event.angleDelta.y > 0 ? -1 : 1)
    }

    Loader {
        id: style

        anchors.fill: parent

        sourceComponent: {
            switch (Appearance.bar.workspaces.style) {
            case "constellation":
                return constellation;
            case "fluid":
                return fluid;
            default:
                return drop;
            }
        }
    }

    Component {
        id: drop

        Drop {
            ws: root
        }
    }

    Component {
        id: fluid

        Fluid {
            ws: root
        }
    }

    Component {
        id: constellation

        Constellation {
            ws: root
        }
    }
}
