import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.modules.bar.components.workspaces

// Bar widget: Hyprland's workspaces, drawn in one of the styles under
// workspaces/. This side owns what is true -- which workspaces exist, how
// many windows each holds, which one this screen shows -- and the input;
// a style only draws it. A click goes to the slot under the pointer and
// the wheel steps through workspaces in use.
Item {
    id: root

    required property ShellScreen screen

    readonly property bool hovered: hover.hovered

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1

    // Window count by workspace id, for the named ones only: special
    // workspaces have negative ids and live outside the row.
    readonly property var windows: {
        const out = {};
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0)
                out[ws.id] = ws.toplevels.values.length;
        return out;
    }

    readonly property var urgent: {
        const out = {};
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0 && ws.urgent)
                out[ws.id] = true;
        return out;
    }

    readonly property int count: {
        let n = Math.max(Appearance.bar.workspaces.shown, activeId);
        for (const id in windows)
            if (windows[id] > 0)
                n = Math.max(n, +id);
        return n;
    }

    // Each style picks how much room a workspace takes.
    readonly property real slot: style.item?.slotWidth ?? 20
    readonly property real padding: Appearance.bar.itemPadding

    // Continuous animations only run while anyone can see them.
    readonly property bool running: opacity > 0 && visible

    function windowsOn(id: int): int {
        return windows[id] ?? 0;
    }

    function centerOf(id: int): real {
        return padding + (id - 0.5) * slot;
    }

    function goTo(id: string): void {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = "${id}" })`);
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
                root.goTo(String(id));
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.goTo(event.angleDelta.y > 0 ? "e-1" : "e+1")
    }

    Loader {
        id: style

        anchors.fill: parent

        sourceComponent: {
            switch (Appearance.bar.workspaces.style) {
            case "constellation":
                return constellation;
            case "orbit":
                return orbit;
            default:
                return liquid;
            }
        }
    }

    Component {
        id: liquid

        Liquid {
            ws: root
        }
    }

    Component {
        id: constellation

        Constellation {
            ws: root
        }
    }

    Component {
        id: orbit

        Orbit {
            ws: root
        }
    }
}
