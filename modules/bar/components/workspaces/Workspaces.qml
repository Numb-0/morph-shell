import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.states

// Bar widget: the workspaces, drawn in one of the styles under
// workspaces/ (Config.bar.workspaces.style). What is true of the
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
    readonly property string output: screen?.name ?? ""

    readonly property int activeId: WorkspacesState.activeOn(output)

    readonly property var windows: WorkspacesState.windowsOn(output)
    readonly property var urgent: WorkspacesState.urgentOn(output)
    readonly property var occupied: WorkspacesState.occupiedOn(output)

    readonly property int count: Math.max(Config.bar.workspaces.shown, activeId, occupied[occupied.length - 1] ?? 1)

    // Each style picks how much room a workspace takes.
    readonly property real slot: style.item?.slotWidth ?? 20
    readonly property real padding: Config.bar.itemPadding

    // Continuous animations only run while anyone can see them.
    readonly property bool running: opacity > 0 && visible

    function windowsOn(id: int): int {
        return windows[id] ?? 0;
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
                WorkspacesState.goTo(root.output, id);
        }
    }

    // WheelHandler {
    //     acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    //     onWheel: event => WorkspacesState.step(root.output, event.angleDelta.y > 0 ? -1 : 1)
    // }

    Loader {
        id: style

        anchors.fill: parent

        sourceComponent: {
            switch (Config.bar.workspaces.style) {
            case "constellation":
                return constellation;
            case "fluid":
                return fluid;
            case "shapes":
                return shapes;
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
        id: shapes

        Shapes {
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
